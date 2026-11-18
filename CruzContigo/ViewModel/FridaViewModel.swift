import Foundation
import Observation

@MainActor
@Observable
final class FridaViewModel {
    struct Mensaje: Identifiable {
        let id = UUID()
        let texto: String
        var delUsuario = false
        var destino: Ruta?

        init(_ texto: String, delUsuario: Bool = false, destino: Ruta? = nil) {
            self.texto = texto
            self.delUsuario = delUsuario
            self.destino = destino
        }
    }

    let familiarSeleccionado: UUID?
    var mensajes = [Mensaje("¡Hola! Soy Frida. Prueba «¿Qué medicamentos toma mi mamá?» o «¿Qué recordatorios tengo hoy?».")]
    var borrador = ""
    private(set) var porResolver: ConsultaFrida?
    private(set) var opciones: [Familiar] = []
    private(set) var consultaActiva: Task<Void, Never>?

    private let medicationService: any MedicationService
    private let recordatoriosService: RecordatoriosService
    private let abrir: (Ruta) -> Void

    init(
        familiarSeleccionado: UUID?,
        medicationService: (any MedicationService)? = nil,
        recordatoriosService: RecordatoriosService? = nil,
        abrir: @escaping (Ruta) -> Void
    ) {
        self.familiarSeleccionado = familiarSeleccionado
        self.medicationService = medicationService ?? MedicationServices.live()
        self.recordatoriosService = recordatoriosService ?? RecordatoriosService()
        self.abrir = abrir
    }

    var textoLimpio: String {
        borrador.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func enviar(usando familiares: FamiliaresStore) {
        let texto = textoLimpio
        guard !texto.isEmpty, consultaActiva == nil else { return }
        borrador = ""
        mensajes.append(Mensaje(texto, delUsuario: true))

        if ConsultaFrida.pideConsejoMedico(texto) {
            mensajes.append(Mensaje("Puedo mostrar los medicamentos registrados. Para indicaciones o cambios de dosis, consulta al equipo de salud."))
            return
        }
        let nueva = ConsultaFrida(texto)
        if ConsultaFrida.pideCambios(texto), nueva?.abrirPantalla != true {
            mensajes.append(Mensaje("Para hacer cambios, pídeme «Abre medicamentos» o «Abre recordatorios» y usa las opciones de esa pantalla."))
            return
        }
        if nueva != nil {
            porResolver = nil
            opciones = []
        }
        guard let consulta = nueva ?? porResolver else {
            mensajes.append(Mensaje("Puedo ayudarte con medicamentos o recordatorios. Prueba «Muéstrame los recordatorios de mañana»."))
            return
        }
        ejecutar { [self] in
            if familiares.estado == .inicial || (familiares.familiares.isEmpty && familiares.estado != .listo) {
                await familiares.cargar()
            }
            try Task.checkCancellation()
            await resolver(consulta, texto: texto, esSeguimiento: nueva == nil, familiares: familiares)
        }
    }

    func resolver(
        _ consulta: ConsultaFrida,
        texto: String,
        esSeguimiento: Bool,
        familiares: FamiliaresStore
    ) async {
        let personas = familiares.familiares
        let coincidencias = ConsultaFrida.coincidencias(texto, familiares: personas)
        let mencionaPersona = esSeguimiento || ConsultaFrida.mencionaFamiliar(texto)

        if coincidencias.count == 1, let persona = coincidencias.first {
            await consultar(consulta, persona: persona, familiares: familiares)
        } else if coincidencias.count > 1 {
            pedirFamiliar(consulta, opciones: coincidencias, mensaje: "¿A cuál de estas personas te refieres?")
        } else if mencionaPersona || consulta.tema == .medicamentos {
            if !mencionaPersona, let persona = personas.first(where: { $0.id == familiarSeleccionado })
                ?? (personas.count == 1 ? personas.first : nil) {
                await consultar(consulta, persona: persona, familiares: familiares)
            } else if case .error(let error) = familiares.estado, personas.isEmpty {
                mensajes.append(Mensaje("No pude cargar a tus familiares. \(error)"))
            } else if personas.isEmpty {
                mensajes.append(Mensaje("Agrega a la persona que cuidas para consultar sus datos.", destino: .agregarFamiliar))
            } else {
                pedirFamiliar(consulta, opciones: personas, mensaje: mencionaPersona
                    ? "No encontré ese nombre. ¿De quién quieres ver la información?"
                    : "¿De quién quieres ver los medicamentos?")
            }
        } else {
            await consultar(consulta, persona: nil, familiares: familiares)
        }
    }

    func pedirFamiliar(_ consulta: ConsultaFrida, opciones: [Familiar], mensaje: String) {
        porResolver = consulta
        self.opciones = opciones
        mensajes.append(Mensaje(mensaje))
    }

    func elegir(_ familiar: Familiar, usando familiares: FamiliaresStore) {
        guard let consulta = porResolver, consultaActiva == nil else { return }
        mensajes.append(Mensaje(familiar.nombreCompleto, delUsuario: true))
        ejecutar { [self] in await consultar(consulta, persona: familiar, familiares: familiares) }
    }

    func ejecutar(_ operacion: @escaping @MainActor () async throws -> Void) {
        consultaActiva = Task {
            defer { consultaActiva = nil }
            do {
                try await operacion()
            } catch {
                guard !Task.isCancelled else { return }
                mensajes.append(Mensaje("No pude cargar la consulta. \(error.localizedDescription)"))
            }
        }
    }

    func consultar(_ consulta: ConsultaFrida, persona: Familiar?, familiares: FamiliaresStore) async {
        porResolver = nil
        opciones = []
        let modulo: Modulo = consulta.tema == .medicamentos ? .medicamentos : .recordatorios
        let destino = Ruta.modulo(modulo, familiarID: persona?.id)
        if consulta.abrirPantalla {
            abrir(destino)
            return
        }
        do {
            let resultado: String
            switch consulta.tema {
            case .medicamentos:
                guard let persona else { return }
                resultado = try await resumenMedicamentos(consulta, persona: persona)
            case .recordatorios:
                resultado = try await resumenRecordatorios(consulta, persona: persona, familiares: familiares)
            }
            try Task.checkCancellation()
            mensajes.append(Mensaje(resultado, destino: destino))
        } catch {
            guard !Task.isCancelled else { return }
            mensajes.append(Mensaje("No pude cargar la consulta. \(error.localizedDescription)", destino: destino))
        }
    }

    func resumenMedicamentos(_ consulta: ConsultaFrida, persona: Familiar) async throws -> String {
        let medicamentos = try await medicationService.fetchMedications(for: persona.id)
        let fechaConsultada = diaConsultado(consulta.periodo).map(MedicationDay.string(from:))
        let visibles = medicamentos.filter { medicamento in
            guard let fecha = fechaConsultada else { return true }
            return medicamento.startDate <= fecha && (medicamento.endDate.map { $0 >= fecha } ?? true)
        }
        let personaTexto = persona.nombreCompleto
        guard !visibles.isEmpty else { return "No encontré medicamentos registrados para \(personaTexto) en esa consulta." }
        return resumen(encabezado: "Medicamentos registrados de \(personaTexto):", filas: visibles.map {
            let detalle = [$0.doseLabel, $0.frequency].compactMap { $0 }.joined(separator: " · ")
            return "\($0.name) — \(detalle)"
        })
    }

    func resumenRecordatorios(
        _ consulta: ConsultaFrida,
        persona: Familiar?,
        familiares: FamiliaresStore
    ) async throws -> String {
        let recordatorios = try await recordatoriosService.listar()
        let dia = diaConsultado(consulta.periodo)
        let ahora = Date.now
        let visibles = recordatorios.filter { recordatorio in
            if let persona, recordatorio.familiarID != persona.id { return false }
            if (consulta.pendientes || consulta.periodo == .proximos) && recordatorio.completado { return false }
            if let dia {
                return Calendar.current.isDate(recordatorio.fecha, inSameDayAs: dia)
            }
            return consulta.periodo != .proximos || recordatorio.fecha >= ahora
        }
        let nombre = persona.map { " de \($0.nombreCompleto)" } ?? ""
        guard !visibles.isEmpty else { return "No encontré recordatorios\(nombre) para esa consulta." }
        let nombres = Dictionary(uniqueKeysWithValues: familiares.familiares.map { ($0.id, $0.nombreCompleto) })
        return resumen(encabezado: "Recordatorios\(nombre):", filas: visibles.map {
            let familiar = persona == nil ? (nombres[$0.familiarID].map { " · \($0)" } ?? "") : ""
            let estado = $0.completado ? " · Completado" : ""
            return "\($0.titulo) — \($0.fechaCorta)\(familiar)\(estado)"
        })
    }

    func diaConsultado(_ periodo: ConsultaFrida.Periodo) -> Date? {
        switch periodo {
        case .hoy: .now
        case .manana: Calendar.current.date(byAdding: .day, value: 1, to: .now)
        default: nil
        }
    }

    func resumen(encabezado: String, filas: [String]) -> String {
        let limite = 5
        let extracto = filas.prefix(limite).map { "• \($0)" }.joined(separator: "\n")
        let restantes = filas.count > limite ? "\nHay \(filas.count - limite) más en esta consulta." : ""
        return "\(encabezado)\n\(extracto)\(restantes)"
    }

    func titulo(de destino: Ruta) -> String {
        switch destino {
        case .agregarFamiliar: "Agregar persona"
        case .modulo(.medicamentos, _): "Abrir Medicamentos"
        default: "Abrir Recordatorios"
        }
    }

    func abrirDestino(_ destino: Ruta) {
        abrir(destino)
    }

    func cancelarConsulta() {
        consultaActiva?.cancel()
    }
}
