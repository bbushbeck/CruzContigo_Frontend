import SwiftUI

struct FridaView: View {
    let familiarSeleccionado: UUID?
    let abrir: (Ruta) -> Void

    @Environment(FamiliaresStore.self) private var familiares
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("rolUsuario") private var rolUsuario = UserRole.cuidador.rawValue
    @FocusState private var escribiendo: Bool
    @State private var dictado = DictadoFrida()
    @State private var borrador = ""
    @State private var mensajes = [Mensaje("¡Hola! Soy Frida. ¿Cómo estuvo tu día? Puedes contarme algo o preguntarme por medicamentos, recordatorios o contactos de emergencia.")]
    @State private var relato: BorradorDiarioFrida?
    @State private var mostrarNota = false
    @State private var contactosDe: Familiar?
    @State private var porResolver: ConsultaFrida?
    @State private var opciones: [Familiar] = []
    @State private var consultaActiva: Task<Void, Never>?

    private enum Destino {
        case pantalla(Ruta)
        case contactos(Familiar)
    }

    private struct Mensaje: Identifiable {
        let id = UUID()
        let texto: String
        var delUsuario = false
        var destino: Destino?

        init(_ texto: String, delUsuario: Bool = false, destino: Destino? = nil) {
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
        .sheet(item: $contactosDe) { persona in
            ContactosEmergenciaView(familiarID: persona.id, nombre: persona.nombre, puedeEditar: false)
        }
        .sheet(isPresented: $mostrarNota) {
            if let relato {
                RevisarNotaFridaView(
                    nota: relato.nota, personas: diariosDisponibles, personaInicial: diarioInicial
                ) { persona in
                    self.relato = nil
                    mensajes.append(Mensaje(
                        "Guardé la nota en el diario de \(persona.nombreCompleto).",
                        destino: .pantalla(.modulo(.diario, familiarID: persona.id))
                    ))
                }
            }
        }
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
                        ProgressView("Preparando la consulta…")
                    } else if relato != nil {
                        accionesDelRelato
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
                    abrirDestino(destino)
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

                TextField("Escribe o dicta un mensaje", text: $borrador, axis: .vertical)
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
                .accessibilityLabel("Enviar mensaje")
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
        let palabras = ConsultaFrida.palabras(texto).joined(separator: " ")
        if ["hola", "buenos dias", "buenas tardes", "buenas noches"].contains(palabras) {
            mensajes.append(Mensaje("Hola. ¿Qué te gustaría contarme hoy?"))
            return
        }
        if relato != nil, ["revisar nota", "guardar nota", "guardar en diario", "guardar en el diario", "quiero guardar la nota"].contains(palabras) {
            prepararRevisionDeNota()
            return
        }
        let esRelato = BorradorDiarioFrida.esRelatoCotidiano(texto)
        let nueva = esRelato ? nil : ConsultaFrida(texto, sugerirContactos: ClasificadorContactosFrida.reconoce)
        if !esRelato, ConsultaFrida.pideCambios(texto), nueva?.abrirPantalla != true {
            mensajes.append(Mensaje("Para hacer cambios, pídeme «Abre medicamentos» o «Abre recordatorios» y usa las opciones de esa pantalla."))
            return
        }
        if nueva != nil {
            porResolver = nil
            opciones = []
        }
        if let consulta = nueva ?? (esRelato ? nil : porResolver) {
            relato?.terminarPreguntas()
            ejecutar {
                if familiares.estado == .inicial || (familiares.familiares.isEmpty && familiares.estado != .listo) {
                    await familiares.cargar()
                }
                try Task.checkCancellation()
                await resolver(consulta, texto: texto, esSeguimiento: nueva == nil)
            }
            return
        }

        porResolver = nil
        opciones = []
        if relato?.pregunta != nil {
            if BorradorDiarioFrida.quiereTerminar(texto) {
                relato?.terminarPreguntas()
                mensajes.append(Mensaje("Está bien. Puedes revisar lo que me contaste si quieres guardarlo."))
            } else if !texto.contains("?") && !texto.contains("¿") {
                seguirRelato(texto)
            } else {
                mensajes.append(Mensaje("Puedes responder la pregunta o tocar «Revisar nota» para guardar lo que ya contaste."))
            }
        } else if relato != nil {
            mensajes.append(Mensaje("Puedes revisar o descartar el borrador antes de empezar otra nota."))
        } else {
            iniciarRelato(texto, esCotidiano: esRelato)
        }
    }

    private var accionesDelRelato: some View {
        ViewThatFits(in: .horizontal) {
            HStack { revisarNota; descartarNota }
            VStack(alignment: .leading) { revisarNota; descartarNota }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var revisarNota: some View {
        Button(action: prepararRevisionDeNota) {
            Label("Revisar nota", systemImage: "note.text")
                .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
    }

    private var descartarNota: some View {
        Button("Descartar borrador") {
            relato = nil
            mensajes.append(Mensaje("Está bien. Podemos hablar de otra cosa."))
        }
        .frame(minHeight: 44)
        .buttonStyle(.bordered)
    }

    private func prepararRevisionDeNota() {
        ejecutar {
            if familiares.familiares.isEmpty { await familiares.cargar() }
            try Task.checkCancellation()
            mostrarNota = true
        }
    }

    private var diariosDisponibles: [Familiar] {
        familiares.familiares.filter { persona in
            persona.puedeEscribirDiario && (persona.accesoVenceEn.map { $0 > .now } ?? true)
        }
    }

    private var diarioInicial: UUID? {
        if rolUsuario == UserRole.recibeCuidados.rawValue {
            let propios = diariosDisponibles.filter { $0.rol == RolAcceso.titular.rawValue }
            return propios.count == 1 ? propios.first?.id : nil
        }
        return diariosDisponibles.first { $0.id == familiarSeleccionado }?.id
            ?? (diariosDisponibles.count == 1 ? diariosDisponibles.first?.id : nil)
    }

    private func iniciarRelato(_ texto: String, esCotidiano: Bool) {
        guard texto.count <= SolicitudNota.largoMaximo else {
            mensajes.append(Mensaje("Cuéntame una parte a la vez. Una nota del diario admite hasta \(SolicitudNota.largoMaximo) caracteres."))
            return
        }
        ejecutar {
            let sugerencia = try? await FridaDiario.sugerir(para: texto, yaPreguntados: [])
            try Task.checkCancellation()
            guard esCotidiano || sugerencia?.esRelato == true else {
                mensajes.append(Mensaje("Puedes contarme algo de tu día, como «Hoy salí a caminar», o pedirme que abra una sección de la app."))
                return
            }

            var borrador = BorradorDiarioFrida(texto: texto)
            let orientacion = sugerencia ?? borrador.sugerenciaLocal()
            borrador.aplicar(orientacion)
            relato = borrador
            mensajes.append(Mensaje("Gracias por contármelo. Si quieres, puedes guardarlo como nota del diario."))
            anunciarPregunta()
        }
    }

    private func seguirRelato(_ texto: String) {
        guard var borrador = relato, borrador.responder(texto) else {
            mensajes.append(Mensaje("Tu respuesta es demasiado larga para la nota. Puedes acortarla o revisar lo que ya contaste."))
            return
        }
        relato = borrador
        guard borrador.conversacion.puedeContinuar else {
            mensajes.append(Mensaje("Ya reuní lo que me contaste. ¿Quieres revisar la nota?"))
            return
        }

        ejecutar {
            let sugerencia = try? await FridaDiario.sugerir(
                para: borrador.nota.texto, yaPreguntados: borrador.conversacion.detallesPreguntados
            )
            try Task.checkCancellation()
            let orientacion = sugerencia ?? borrador.sugerenciaLocal()
            borrador.aplicar(orientacion)
            relato = borrador
            if borrador.pregunta == nil {
                mensajes.append(Mensaje("Ya reuní lo que me contaste. ¿Quieres revisar la nota?"))
            } else {
                anunciarPregunta()
            }
        }
    }

    private func anunciarPregunta() {
        if let pregunta = relato?.pregunta { mensajes.append(Mensaje(pregunta.pregunta)) }
    }

    private func resolver(_ consulta: ConsultaFrida, texto: String, esSeguimiento: Bool) async {
        let personas = familiares.familiares
        let coincidencias = ConsultaFrida.coincidencias(texto, familiares: personas)
        let mencionaPersona = esSeguimiento || ConsultaFrida.mencionaFamiliar(texto)

        if coincidencias.count == 1, let persona = coincidencias.first {
            await consultar(consulta, persona: persona)
        } else if coincidencias.count > 1 {
            pedirFamiliar(consulta, opciones: coincidencias, mensaje: "¿A cuál de estas personas te refieres?")
        } else if mencionaPersona || consulta.requiereFamiliar {
            if !mencionaPersona, let persona = personas.first(where: { $0.id == familiarSeleccionado })
                ?? (personas.count == 1 ? personas.first : nil) {
                await consultar(consulta, persona: persona)
            } else if case .error(let error) = familiares.estado, personas.isEmpty {
                mensajes.append(Mensaje("No pude cargar a tus familiares. \(error)"))
            } else if personas.isEmpty {
                mensajes.append(Mensaje("Agrega a la persona que cuidas para consultar sus datos.", destino: .pantalla(.agregarFamiliar)))
            } else {
                pedirFamiliar(consulta, opciones: personas, mensaje: mencionaPersona
                    ? "No encontré ese nombre. ¿De quién quieres ver la información?"
                    : "¿De quién quieres ver la información?")
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
        let destino: Ruta
        let cargarResumen: () async throws -> String
        switch consulta.tema {
        case .contactosEmergencia:
            guard let persona else { return }
            if persona.esProfesional {
                mensajes.append(Mensaje("Tu tipo de acceso permite consultar la ficha médica de esta persona."))
            } else {
                mensajes.append(Mensaje(
                    "Aquí puedes ver los contactos de emergencia de \(persona.nombreCompleto).",
                    destino: .contactos(persona)
                ))
            }
            return
        case .medicamentos:
            guard let persona else { return }
            destino = .modulo(.medicamentos, familiarID: persona.id)
            cargarResumen = { try await resumenMedicamentos(consulta, persona: persona) }
        case .recordatorios:
            destino = .modulo(.recordatorios, familiarID: persona?.id)
            cargarResumen = { try await resumenRecordatorios(consulta, persona: persona) }
        }

        if consulta.abrirPantalla {
            abrir(destino)
            return
        }
        do {
            let resultado = try await cargarResumen()
            try Task.checkCancellation()
            mensajes.append(Mensaje(resultado, destino: .pantalla(destino)))
        } catch {
            guard !Task.isCancelled else { return }
            mensajes.append(Mensaje("No pude cargar la consulta. \(error.localizedDescription)", destino: .pantalla(destino)))
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

    private func abrirDestino(_ destino: Destino) {
        switch destino {
        case .pantalla(let ruta): abrir(ruta)
        case .contactos(let persona): contactosDe = persona
        }
    }

    private func titulo(de destino: Destino) -> String {
        switch destino {
        case .contactos: "Ver contactos de emergencia"
        case .pantalla(.agregarFamiliar): "Agregar persona"
        case .pantalla(.modulo(.medicamentos, _)): "Abrir Medicamentos"
        case .pantalla(.modulo(.diario, _)): "Abrir diario"
        default: "Abrir Recordatorios"
        }
    }
}
