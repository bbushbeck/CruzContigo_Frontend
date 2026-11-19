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
    @State private var notaParaRevisar: SolicitudNota?
    @State private var personaParaRevisar: UUID?
    @State private var esperaDecisionDeResumen = false
    @State private var escuchaSinApuro = false
    @State private var apoyoActivo: ApoyoFrida?
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
        var apoyo: ApoyoFrida?

        init(_ texto: String, delUsuario: Bool = false, destino: Destino? = nil, apoyo: ApoyoFrida? = nil) {
            self.texto = texto
            self.delUsuario = delUsuario
            self.destino = destino
            self.apoyo = apoyo
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
        .sheet(isPresented: $mostrarNota, onDismiss: { notaParaRevisar = nil }) {
            if let notaParaRevisar, let relato {
                RevisarNotaFridaView(
                    nota: notaParaRevisar, relatoOriginal: relato.fragmentos.resumen(seleccion: nil),
                    personas: diariosDisponibles, personaInicial: personaParaRevisar,
                    alGuardar: confirmarNotaGuardada
                )
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
                    } else if apoyoActivo == nil, relato?.muestraOferta == true {
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

            if let apoyo = mensaje.apoyo {
                opcionesDeApoyo(apoyo)
            }
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

    private func opcionesDeApoyo(_ apoyo: ApoyoFrida) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let telefono = URL(string: "tel:911") {
                Link(destination: telefono) {
                    Label("Llamar al 911 · México", systemImage: "phone.fill")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            if apoyo == .hacerseDano, let telefono = URL(string: "tel:8009112000") {
                Link(destination: telefono) {
                    Label("Línea de la Vida · 800 911 2000", systemImage: "phone")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
            if !familiaresParaApoyo.isEmpty {
                Button(action: mostrarContactosDeApoyo) {
                    Label("Ver contactos de emergencia", systemImage: "person.crop.circle")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var familiaresParaApoyo: [Familiar] {
        familiares.familiares.filter { persona in
            !persona.esProfesional && (persona.accesoVenceEn.map { $0 > .now } ?? true)
        }
    }

    private func mostrarContactosDeApoyo() {
        let disponibles = familiaresParaApoyo
        let puedeElegirTitular = rolUsuario == UserRole.recibeCuidados.rawValue
        let propios = disponibles.filter { $0.rol == RolAcceso.titular.rawValue }
        let preferida = puedeElegirTitular
            ? (propios.count == 1 ? propios.first : nil)
            : disponibles.first { $0.id == familiarSeleccionado }

        if let preferida {
            contactosDe = preferida
        } else if disponibles.count == 1 {
            contactosDe = disponibles.first
        } else if !disponibles.isEmpty, let consulta = ConsultaFrida("Ver contactos de emergencia") {
            pedirFamiliar(consulta, opciones: disponibles, mensaje: "¿De quién quieres ver los contactos?")
        }
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
                .disabled(textoLimpio.isEmpty || dictado.estado != .listo
                          || (consultaActiva != nil && ApoyoFrida.detectar(en: textoLimpio) == nil))
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
        guard !texto.isEmpty else { return }
        let apoyoDetectado = ApoyoFrida.detectar(en: texto)
        guard consultaActiva == nil || apoyoDetectado != nil else { return }
        borrador = ""
        escribiendo = false
        mensajes.append(Mensaje(texto, delUsuario: true))
        let respondiaAOferta = esperaDecisionDeResumen
        esperaDecisionDeResumen = false

        let palabras = ConsultaFrida.palabras(texto).joined(separator: " ")
        if let apoyo = apoyoDetectado {
            consultaActiva?.cancel()
            apoyoActivo = apoyo
            escuchaSinApuro = true
            relato?.descartarOferta()
            porResolver = nil
            opciones = []
            mensajes.append(Mensaje(apoyo.mensaje, apoyo: apoyo))
            return
        }
        if let apoyoActivo {
            if ["estoy a salvo", "ya estoy a salvo", "ya me estan atendiendo", "ya me estan ayudando"].contains(palabras) {
                self.apoyoActivo = nil
                mensajes.append(Mensaje("Gracias por contármelo. Si quieres seguir hablando, te leo."))
            } else if IntencionEscuchaFrida.solicitaContacto(texto) {
                mostrarContactosDeApoyo()
            } else {
                mensajes.append(Mensaje(
                    "Te leo. Si puedes, busca a alguien de confianza que pueda estar contigo.",
                    apoyo: apoyoActivo
                ))
            }
            return
        }
        if let pedido = PedidoDiarioFrida(texto) {
            interpretarMensaje(texto, pedido: pedido)
            return
        }

        if IntencionEscuchaFrida.pideEscucha(texto) || IntencionEscuchaFrida.rechazaContactos(texto) {
            escuchaSinApuro = true
            relato?.descartarOferta()
            porResolver = nil
            opciones = []
            if IntencionEscuchaFrida.soloPideEscucha(texto) {
                mensajes.append(Mensaje("Claro. Tómate tu tiempo, te estoy escuchando."))
            } else {
                interpretarMensaje(texto, soloEscuchar: true)
            }
            return
        }

        if ConsultaFrida.pideConsejoMedico(texto) {
            responderConsejoMedico()
            return
        }
        if ["hola", "buenos dias", "buenas tardes", "buenas noches"].contains(palabras) {
            mensajes.append(Mensaje("Hola. ¿Qué te gustaría contarme hoy?"))
            return
        }
        if relato != nil, respondiaAOferta,
           ["si", "si por favor", "si gracias", "claro", "adelante"].contains(palabras) {
            prepararRevisionDeNota()
            return
        }
        if relato != nil, BorradorDiarioFrida.quiereCerrar(texto) {
            if relato?.ofrecerResumen(alCerrar: true) == true {
                ofrecerResumen()
            } else {
                mensajes.append(Mensaje("Gracias por contármelo."))
            }
            return
        }
        if relato != nil, BorradorDiarioFrida.quiereOmitir(texto) {
            if respondiaAOferta || ["no lo guardes", "no quiero guardarlo"].contains(palabras) {
                relato?.descartarOferta()
            }
            mensajes.append(Mensaje("Está bien. Si quieres seguir contándome, te leo."))
            return
        }
        interpretarMensaje(texto)
    }

    private func interpretarMensaje(
        _ texto: String, soloEscuchar: Bool = false, pedido: PedidoDiarioFrida? = nil
    ) {
        let relatoPrevio = relato
        ejecutar {
            let interpretacion = try? await FridaDiario.interpretar(
                ultimoMensaje: texto, relato: relatoPrevio
            )
            try Task.checkCancellation()

            if let pedido {
                try await atenderPedidoDiario(pedido, orientacion: interpretacion?.orientacion)
                return
            }
            if soloEscuchar {
                registrarRelato(texto, orientacion: interpretacion?.orientacion)
                return
            }
            let esRelatoCotidiano = BorradorDiarioFrida.esRelatoCotidiano(texto)
            if interpretacion?.intencion == .consejoMedico, !esRelatoCotidiano {
                responderConsejoMedico()
                return
            }
            if interpretacion?.autorizaRevision(texto) == true {
                if let relatoPrevio {
                    try await prepararNota(relatoPrevio)
                } else {
                    mensajes.append(Mensaje("Cuéntame qué quieres anotar en el diario."))
                }
                return
            }

            let nueva = InterpretacionFrida.resolverConsulta(
                interpretacion, texto: texto, contandoRelato: relatoPrevio != nil
            )
            let esRelato = esRelatoCotidiano || interpretacion?.intencion == .relato
            if !esRelato, ConsultaFrida.pideCambios(texto), nueva?.abrirPantalla != true {
                mensajes.append(Mensaje("Puedes hacer cambios desde las pantallas de medicamentos y recordatorios."))
                return
            }
            if nueva != nil {
                porResolver = nil
                opciones = []
            }
            let esNombreDeSeguimiento = !esRelatoCotidiano
                && !ConsultaFrida.coincidencias(texto, familiares: opciones).isEmpty
            let consultaPendiente = !esRelato || esNombreDeSeguimiento ? porResolver : nil
            if let consulta = nueva ?? consultaPendiente {
                if familiares.estado == .inicial || (familiares.familiares.isEmpty && familiares.estado != .listo) {
                    await familiares.cargar()
                }
                try Task.checkCancellation()
                await resolver(consulta, texto: texto, esSeguimiento: nueva == nil)
                return
            }

            porResolver = nil
            opciones = []
            if esRelato || (relatoPrevio != nil && !BorradorDiarioFrida.esConsultaExplicita(texto)) {
                registrarRelato(texto, orientacion: interpretacion?.orientacion)
            } else {
                mensajes.append(Mensaje("Puedes contarme algo de tu día o pedirme medicamentos, recordatorios o contactos de emergencia."))
            }
        }
    }

    private func responderConsejoMedico() {
        mensajes.append(Mensaje("Puedo mostrar los medicamentos registrados. Para indicaciones o cambios de dosis, consulta al equipo de salud."))
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
            Label("Revisar resumen", systemImage: "note.text")
                .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
    }

    private var descartarNota: some View {
        Button("Descartar borrador") {
            relato = nil
            escuchaSinApuro = false
            esperaDecisionDeResumen = false
            mensajes.append(Mensaje("Está bien. Podemos hablar de otra cosa."))
        }
        .frame(minHeight: 44)
        .buttonStyle(.bordered)
    }

    private func prepararRevisionDeNota() {
        guard apoyoActivo == nil, let relato else { return }
        ejecutar { try await prepararNota(relato) }
    }

    private func atenderPedidoDiario(_ pedido: PedidoDiarioFrida, orientacion: SugerenciaNotaFrida?) async throws {
        var actualizado = relato
        if let contenido = pedido.contenido {
            guard contenido.count <= SolicitudNota.largoMaximo else {
                mensajes.append(Mensaje("La nota admite hasta \(SolicitudNota.largoMaximo) caracteres."))
                return
            }
            if var previo = actualizado {
                guard previo.agregar(contenido) else {
                    mensajes.append(Mensaje("Ese detalle rebasa el límite de la nota. Puedes revisar el borrador desde aquí."))
                    _ = relato?.ofrecerResumen(alCerrar: true)
                    return
                }
                actualizado = previo
            } else {
                actualizado = BorradorDiarioFrida(texto: contenido)
            }
            if let sugerencia = orientacion ?? actualizado?.sugerenciaLocal(ultimoMensaje: contenido) {
                actualizado?.actualizarCategoria(sugerencia, ultimoMensaje: contenido)
            }
        }
        guard let actualizado else {
            mensajes.append(Mensaje("Cuéntame qué quieres anotar en el diario."))
            return
        }
        porResolver = nil
        opciones = []
        relato = actualizado
        try await prepararNota(actualizado, pedido: pedido)
    }

    private func prepararNota(_ relato: BorradorDiarioFrida, pedido: PedidoDiarioFrida? = nil) async throws {
        if familiares.familiares.isEmpty { await familiares.cargar() }
        try Task.checkCancellation()
        let seleccion = try? await FridaDiario.seleccionarResumen(relato.fragmentos)
        try Task.checkCancellation()
        let nota = relato.notaParaRevision(seleccion: seleccion)
        let destino = pedido.flatMap {
            $0.destinoUnico(
                relato: relato.nota.texto, personas: familiares.familiares, diariosDisponibles: diariosDisponibles,
                recibeCuidados: rolUsuario == UserRole.recibeCuidados.rawValue
            )
        }
        if pedido?.accion == .guardar, let destino, nota.esValida {
            do {
                _ = try await Repositorios.diario().crear(nota, familiarID: destino.id)
                confirmarNotaGuardada(destino)
            } catch {
                guard !Task.isCancelled else { return }
                mensajes.append(Mensaje("No pude guardar la nota. El borrador sigue aquí. \(error.localizedDescription)"))
            }
            return
        }
        personaParaRevisar = destino?.id ?? (pedido?.accion == .guardar ? nil : diarioInicial)
        notaParaRevisar = nota
        mostrarNota = true
    }

    private func confirmarNotaGuardada(_ persona: Familiar) {
        relato = nil
        escuchaSinApuro = apoyoActivo != nil
        esperaDecisionDeResumen = false
        mensajes.append(Mensaje(
            "Guardé la nota en el diario de \(persona.nombreCompleto).",
            destino: .pantalla(.modulo(.diario, familiarID: persona.id))
        ))
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

    private func registrarRelato(_ texto: String, orientacion: SugerenciaNotaFrida?) {
        guard texto.count <= SolicitudNota.largoMaximo else {
            mensajes.append(Mensaje("Cuéntame una parte a la vez. Una nota del diario admite hasta \(SolicitudNota.largoMaximo) caracteres."))
            return
        }
        var actualizado = relato ?? BorradorDiarioFrida(texto: texto)
        if relato != nil, !actualizado.agregar(texto) {
            mensajes.append(Mensaje("Este mensaje es largo para una sola nota. Te leo si quieres seguir platicando."))
            if !escuchaSinApuro { _ = relato?.ofrecerResumen(alCerrar: true) }
            return
        }

        let delModelo = orientacion.flatMap { $0.esRelato ? $0 : nil }
        let sugerencia = delModelo ?? actualizado.sugerenciaLocal(ultimoMensaje: texto)
        actualizado.actualizarCategoria(sugerencia, ultimoMensaje: texto)
        if !escuchaSinApuro, !sugerencia.convieneSeguirEscuchando(texto), actualizado.ofrecerResumen() {
            relato = actualizado
            ofrecerResumen()
            return
        }

        let pregunta = escuchaSinApuro ? nil : actualizado.elegirPregunta(
            sugerencia, ultimoMensaje: texto, sugeridaPorModelo: delModelo != nil
        )
        let respuesta = actualizado.responder(sugerencia, texto: texto, pregunta: pregunta)
        relato = actualizado
        if !respuesta.isEmpty { mensajes.append(Mensaje(respuesta)) }
    }

    private func ofrecerResumen() {
        esperaDecisionDeResumen = true
        mensajes.append(Mensaje("¿Quieres que prepare un resumen de lo que me contaste para tu diario?"))
    }

    private func resolver(_ consulta: ConsultaFrida, texto: String, esSeguimiento: Bool) async {
        let personas = familiares.familiares
        let coincidencias = ConsultaFrida.coincidencias(texto, familiares: personas)
        let mencionaPersona = esSeguimiento || consulta.mencionaPersona || ConsultaFrida.mencionaFamiliar(texto)

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
