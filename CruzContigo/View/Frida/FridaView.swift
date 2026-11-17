import SwiftUI

struct FridaView: View {
    let familiarSeleccionado: UUID?
    let abrir: (Ruta) -> Void

    @Environment(FamiliaresStore.self) private var familiares
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var escribiendo: Bool
    @State private var dictado = DictadoFrida()
    @State private var borrador = ""
    @State private var mensajes = [Mensaje("¡Hola! Soy Frida. Prueba «¿Qué medicamentos toma mi mamá?» o «¿Qué recordatorios tengo hoy?».")]
    @State private var porResolver: ConsultaFrida?
    @State private var opciones: [Familiar] = []
    @State private var consultaActiva: Task<Void, Never>?

    private struct Mensaje: Identifiable {
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

    var body: some View {
        NavigationStack {
            conversacion
                .safeAreaInset(edge: .bottom) { entrada }
                .navigationTitle("Frida")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { dismiss() }
                    }
                }
        }
        .tint(.brandRed)
        .onChange(of: dictado.transcripcion) { _, texto in
            if !texto.isEmpty { borrador = texto }
        }
        .onChange(of: scenePhase) { _, fase in
            if fase == .background { dictado.cancelar() }
        }
        .onDisappear {
            dictado.cancelar()
            consultaActiva?.cancel()
        }
    }

    private var conversacion: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(mensajes) { mensaje in
                        burbuja(mensaje)
                    }
                    ForEach(opciones) { familiar in
                        Button(familiar.nombreCompleto) {
                            elegir(familiar)
                        }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                    }
                    if consultaActiva != nil {
                        ProgressView("Consultando la API…")
                    }
                    Color.clear.frame(height: 1).id("fin").accessibilityHidden(true)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: mensajes.count) { _, _ in
                scroll.scrollTo("fin", anchor: .bottom)
            }
        }
    }

    private func burbuja(_ mensaje: Mensaje) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if !mensaje.delUsuario {
                    Image("FridaAvatar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)
                }
                Text(mensaje.delUsuario ? "Tú" : "Frida")
                    .font(.app(.caption).weight(.semibold))
                    .foregroundStyle(mensaje.delUsuario ? Color.textoSuave : Color.brandRed)
            }
            Text(mensaje.texto)
                .font(.app(.body))
                .textSelection(.enabled)

            if let destino = mensaje.destino {
                Button {
                    abrir(destino)
                } label: {
                    Label(titulo(de: destino), systemImage: "arrow.right")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(mensaje.delUsuario ? Color.rellenoSuave : Color.tintaSuave, in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: mensaje.delUsuario ? .trailing : .leading)
    }

    private var entrada: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let mensaje = dictado.mensaje {
                Text(mensaje).font(.app(.footnote)).foregroundStyle(.secondary)
            } else if dictado.estado == .escuchando {
                Text("Escuchando… Toca el micrófono para terminar.")
                    .font(.app(.footnote)).foregroundStyle(Color.brandRed)
            } else if dictado.estado == .terminando {
                Text("Terminando el dictado…").font(.app(.footnote)).foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    if dictado.estado == .escuchando {
                        dictado.terminar()
                    } else {
                        escribiendo = false
                        Task { await dictado.iniciar() }
                    }
                } label: {
                    Image(systemName: dictado.estado == .escuchando ? "stop.circle.fill" : "mic.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(dictado.estado == .escuchando ? "Terminar dictado" : "Dictar consulta")
                .disabled(consultaActiva != nil || dictado.estado == .permisos || dictado.estado == .terminando)

                TextField("Escribe o dicta tu consulta", text: $borrador, axis: .vertical)
                    .font(.app(.body))
                    .lineLimit(1...4)
                    .focused($escribiendo)
                    .disabled(dictado.estado != .listo)
                    .padding(10)
                    .background(Color.rellenoSuave, in: RoundedRectangle(cornerRadius: 12))

                Button(action: enviar) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Enviar consulta")
                .disabled(textoLimpio.isEmpty || consultaActiva != nil || dictado.estado != .listo)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private var textoLimpio: String {
        borrador.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func enviar() {
        let texto = textoLimpio
        guard !texto.isEmpty, consultaActiva == nil else { return }
        borrador = ""
        escribiendo = false
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
        ejecutar {
            if familiares.estado == .inicial || (familiares.familiares.isEmpty && familiares.estado != .listo) {
                await familiares.cargar()
            }
            try Task.checkCancellation()
            await resolver(consulta, texto: texto, esSeguimiento: nueva == nil)
        }
    }

    private func resolver(_ consulta: ConsultaFrida, texto: String, esSeguimiento: Bool) async {
        let personas = familiares.familiares
        let coincidencias = ConsultaFrida.coincidencias(texto, familiares: personas)
        let mencionaPersona = esSeguimiento || ConsultaFrida.mencionaFamiliar(texto)

        if coincidencias.count == 1, let persona = coincidencias.first {
            await consultar(consulta, persona: persona)
        } else if coincidencias.count > 1 {
            pedirFamiliar(consulta, opciones: coincidencias, mensaje: "¿A cuál de estas personas te refieres?")
        } else if mencionaPersona || consulta.tema == .medicamentos {
            if !mencionaPersona, let persona = personas.first(where: { $0.id == familiarSeleccionado })
                ?? (personas.count == 1 ? personas.first : nil) {
                await consultar(consulta, persona: persona)
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
            await consultar(consulta, persona: nil)
        }
    }

    private func pedirFamiliar(_ consulta: ConsultaFrida, opciones: [Familiar], mensaje: String) {
        porResolver = consulta
        self.opciones = opciones
        mensajes.append(Mensaje(mensaje))
    }

    private func elegir(_ familiar: Familiar) {
        guard let consulta = porResolver, consultaActiva == nil else { return }
        mensajes.append(Mensaje(familiar.nombreCompleto, delUsuario: true))
        ejecutar { await consultar(consulta, persona: familiar) }
    }

    private func ejecutar(_ operacion: @escaping @MainActor () async throws -> Void) {
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

    private func consultar(_ consulta: ConsultaFrida, persona: Familiar?) async {
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
                resultado = try await resumenRecordatorios(consulta, persona: persona)
            }
            try Task.checkCancellation()
            mensajes.append(Mensaje(resultado, destino: destino))
        } catch {
            guard !Task.isCancelled else { return }
            mensajes.append(Mensaje("No pude cargar la consulta. \(error.localizedDescription)", destino: destino))
        }
    }

    private func resumenMedicamentos(_ consulta: ConsultaFrida, persona: Familiar) async throws -> String {
        let medicamentos = try await MedicationServices.live().fetchMedications(for: persona.id)
        let fechaConsultada = diaConsultado(consulta.periodo).map(MedicationDay.string(from:))
        let visibles = medicamentos.filter { medicamento in
            guard let fecha = fechaConsultada else { return true }
            return medicamento.startDate <= fecha && (medicamento.endDate.map { $0 >= fecha } ?? true)
        }
        let personaTexto = persona.nombreCompleto
        guard !visibles.isEmpty else { return "No encontré medicamentos registrados para \(personaTexto) en esa consulta." }
        return resumen("Medicamentos registrados de \(personaTexto):", filas: visibles.map {
            let detalle = [$0.doseLabel, $0.frequency].compactMap { $0 }.joined(separator: " · ")
            return "\($0.name) — \(detalle)"
        })
    }

    private func resumenRecordatorios(_ consulta: ConsultaFrida, persona: Familiar?) async throws -> String {
        let recordatorios = try await RecordatoriosService().listar()
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
        return resumen("Recordatorios\(nombre):", filas: visibles.map {
            let familiar = persona == nil ? (nombres[$0.familiarID].map { " · \($0)" } ?? "") : ""
            let estado = $0.completado ? " · Completado" : ""
            return "\($0.titulo) — \($0.fechaCorta)\(familiar)\(estado)"
        })
    }

    private func diaConsultado(_ periodo: ConsultaFrida.Periodo) -> Date? {
        switch periodo {
        case .hoy: .now
        case .manana: Calendar.current.date(byAdding: .day, value: 1, to: .now)
        default: nil
        }
    }

    private func resumen(_ encabezado: String, filas: [String]) -> String {
        let limite = 5
        let extracto = filas.prefix(limite).map { "• \($0)" }.joined(separator: "\n")
        let restantes = filas.count > limite ? "\nHay \(filas.count - limite) más en esta consulta." : ""
        return "\(encabezado)\n\(extracto)\(restantes)"
    }

    private func titulo(de destino: Ruta) -> String {
        switch destino {
        case .agregarFamiliar: "Agregar persona"
        case .modulo(.medicamentos, _): "Abrir Medicamentos"
        default: "Abrir Recordatorios"
        }
    }
}
