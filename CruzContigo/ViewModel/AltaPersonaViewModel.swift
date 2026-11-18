import Foundation
import Observation

@MainActor
@Observable
final class AltaPersonaViewModel {
    typealias Paso = FamiliarDraft.Paso
    typealias Campo = FamiliarDraft.Campo

    enum ResultadoContinuar {
        case avanzar
        case guardar
        case error(campo: Campo?, mensaje: String?)
    }

    var draft = FamiliarDraft()
    private(set) var paso: Paso = .nombre
    private(set) var avanzando = true
    private(set) var pasosIntentados: Set<Paso> = []
    private(set) var volverARevision = false
    private(set) var guardando = false
    var errorGuardado: String?
    private(set) var creado: Familiar?
    private(set) var intentosFallidos = 0

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var errores: [Campo: String] {
        pasosIntentados.contains(paso) ? draft.errores(en: paso) : [:]
    }

    var nombre: String {
        draft.nombreCorto.isEmpty ? "esta persona" : draft.nombreCorto
    }

    var textoBoton: String {
        if guardando { return "Guardando…" }
        if paso == .revision { return "Guardar a \(nombre)" }
        if volverARevision { return "Volver a la revisión" }
        return "Continuar"
    }

    var textoFecha: String {
        guard let fecha = draft.fechaNacimiento else { return "—" }
        let texto = fecha.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "es_MX")))
        return draft.edad.map { "\(texto) · \($0) años" } ?? texto
    }

    func continuar(cambiar: ((@escaping () -> Void) -> Void)? = nil) -> ResultadoContinuar {
        if paso == .revision { return .guardar }
        pasosIntentados.insert(paso)
        let erroresPaso = draft.errores(en: paso)
        guard erroresPaso.isEmpty else {
            intentosFallidos += 1
            let campo = paso.campos.first { erroresPaso[$0] != nil }
            let campoEnfocable = campo.flatMap { [.nombre, .apellidos, .dia, .anio, .telefono].contains($0) ? $0 : nil }
            return .error(campo: campoEnfocable, mensaje: campo.flatMap { erroresPaso[$0] })
        }
        let avanzar = {
            self.avanzando = true
            if self.volverARevision {
                self.volverARevision = false
                self.paso = .revision
            } else if let siguiente = Paso(rawValue: self.paso.rawValue + 1) {
                self.paso = siguiente
            }
        }
        if let cambiar { cambiar(avanzar) } else { avanzar() }
        return .avanzar
    }

    func atras(cambiar: ((@escaping () -> Void) -> Void)? = nil) -> Bool {
        guard let anterior = Paso(rawValue: paso.rawValue - 1) else { return true }
        let retroceder = {
            self.avanzando = false
            self.volverARevision = false
            self.paso = anterior
        }
        if let cambiar { cambiar(retroceder) } else { retroceder() }
        return false
    }

    func ir(a destino: Paso) {
        avanzando = false
        volverARevision = true
        paso = destino
    }

    func salir() -> Bool {
        draft.tieneDatos
    }

    func guardar(
        usando store: FamiliaresStore,
        cambiar: ((@escaping () -> Void) -> Void)? = nil
    ) async {
        guard let familiar = draft.construir() else {
            if let primero = Paso.preguntas.first(where: { !draft.errores(en: $0).isEmpty }) {
                pasosIntentados.insert(primero)
                if let cambiar {
                    cambiar { self.ir(a: primero) }
                } else {
                    ir(a: primero)
                }
            }
            intentosFallidos += 1
            return
        }
        guardando = true
        defer { guardando = false }
        if let error = await store.agregar(familiar) {
            errorGuardado = error
        } else {
            defaults.set(familiar.id.uuidString, forKey: ClavesApp.personaSeleccionada)
            creado = familiar
        }
    }

    func enfocarInicio() -> Campo? {
        switch paso {
        case .nombre where draft.nombre.isEmpty: .nombre
        case .nacimiento where draft.dia.isEmpty: .dia
        default: nil
        }
    }

    func formatearTelefono(_ telefono: String) -> String {
        guard telefono.count == 10 else { return telefono }
        return "\(telefono.prefix(2)) \(telefono.dropFirst(2).prefix(4)) \(telefono.suffix(4))"
    }
}
