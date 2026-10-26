//
//  AltaPersonaView.swift
//  CruzContigo
//

import SwiftUI

struct AltaPersonaView: View {
    typealias Paso = FamiliarDraft.Paso
    typealias Campo = FamiliarDraft.Campo

    @Environment(FamiliaresStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.reducirMovimiento) private var reducirMovimiento
    @AppStorage(ClavesApp.personaSeleccionada) private var seleccionID = ""

    @State private var draft = FamiliarDraft()
    @State private var paso: Paso = .nombre
    @State private var avanzando = true
    @State private var pasosIntentados: Set<Paso> = []
    @State private var volverARevision = false
    @State private var guardando = false
    @State private var errorGuardado: String?
    @State private var creado: Familiar?
    @State private var confirmarSalida = false
    @State private var intentosFallidos = 0
    @FocusState private var foco: Campo?
    @AccessibilityFocusState private var tituloEnfocado: Bool

    private var errores: [Campo: String] {
        pasosIntentados.contains(paso) ? draft.errores(en: paso) : [:]
    }

    private var nombre: String {
        draft.nombreCorto.isEmpty ? "esta persona" : draft.nombreCorto
    }

    var body: some View {
        Group {
            if let creado {
                AltaExitosaView(persona: creado) { dismiss() }
                    .transition(.opacity)
            } else {
                flujo
            }
        }
        .animation(reducirMovimiento ? nil : .easeInOut(duration: 0.25), value: creado != nil)
        .vibracion(.error, trigger: intentosFallidos)
        .vibracion(.success, trigger: creado != nil)
        .confirmationDialog("¿Salir sin guardar?", isPresented: $confirmarSalida, titleVisibility: .visible) {
            Button("Salir sin guardar", role: .destructive) { dismiss() }
            Button("Seguir editando", role: .cancel) {}
        } message: {
            Text("Se perderán los datos que escribiste.")
        }
        .alert("No se pudo guardar", isPresented: Binding(
            get: { errorGuardado != nil },
            set: { if !$0 { errorGuardado = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(errorGuardado ?? "")
        }
    }

    private var flujo: some View {
        VStack(spacing: 0) {
            encabezado
                .padding(.horizontal, 20)
                .padding(.top, 8)

            ZStack {
                ScrollView {
                    contenidoPaso
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Color(.systemBackground))
                .id(paso)
                .transition(transicion)
            }
            .frame(maxHeight: .infinity)
            .clipped()

            pie
        }
        .onChange(of: paso) {
            enfocarInicio()
        }
        .onAppear {
            enfocarInicio()
        }
    }

    private var transicion: AnyTransition {
        if reducirMovimiento { return .opacity }
        return .asymmetric(
            insertion: .move(edge: avanzando ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: avanzando ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private var encabezado: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    atras()
                } label: {
                    Image(systemName: "chevron.left")
                        .icono(.navegacion)
                        .foregroundColor(.brandRed)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(paso == .nombre ? "Salir" : "Paso anterior")

                Spacer()

                Text(paso == .revision ? "Revisión final" : "Paso \(paso.rawValue + 1) de \(Paso.preguntas.count)")
                    .font(.app(.subheadline).weight(.semibold))
                    .foregroundColor(.textoSuave)

                Spacer()

                Button {
                    salir()
                } label: {
                    Image(systemName: "xmark")
                        .icono(.navegacion)
                        .foregroundColor(.textoSuave)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.rellenoSuave))
                }
                .accessibilityLabel("Cancelar y salir")
            }

            ProgressBarView(progress: Double(paso.rawValue + 1) / Double(Paso.allCases.count))
                .animation(reducirMovimiento ? nil : .easeInOut, value: paso)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var contenidoPaso: some View {
        switch paso {
        case .nombre: pasoNombre
        case .relacion: pasoRelacion
        case .nacimiento: pasoNacimiento
        case .cuidado: pasoCuidado
        case .contacto: pasoContacto
        case .revision: pasoRevision
        }
    }

    private func pregunta(_ titulo: String, ayuda: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo)
                .font(.app(.title).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($tituloEnfocado)
            Text(ayuda)
                .font(.app(.body))
                .foregroundColor(.textoSuave)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    private var pasoNombre: some View {
        VStack(alignment: .leading, spacing: 20) {
            pregunta(
                "¿Cómo se llama la persona que cuidas?",
                ayuda: "Escribe su nombre como aparece en su identificación."
            )

            Button {
                SelectorContactos.presentar { contacto in
                    draft.completar(con: contacto)
                }
            } label: {
                Label("Elegir de mis contactos", systemImage: "person.crop.circle.badge.plus")
                    .font(.app(.headline))
                    .foregroundColor(.brandRed)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.tintaSuave))
            }
            .accessibilityHint("Llena el nombre, teléfono y cumpleaños con los datos de un contacto")

            CampoTexto(
                titulo: "Nombre(s)",
                ejemplo: "Rosa María",
                texto: $draft.nombre,
                error: errores[.nombre],
                foco: $foco,
                campo: .nombre,
                contenido: .givenName,
                siguiente: { foco = .apellidos }
            )

            CampoTexto(
                titulo: "Apellidos",
                ejemplo: "Hernández López",
                texto: $draft.apellidos,
                error: errores[.apellidos],
                foco: $foco,
                campo: .apellidos,
                contenido: .familyName,
                siguiente: { continuar() }
            )
        }
    }

    private var pasoRelacion: some View {
        VStack(alignment: .leading, spacing: 16) {
            pregunta(
                "¿Qué es \(nombre) para ti?",
                ayuda: "Nos ayuda a personalizar los mensajes y recordatorios."
            )

            MensajeError(texto: errores[.parentesco])

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(Parentesco.allCases) { opcion in
                    OpcionGrande(
                        titulo: opcion.titulo,
                        seleccionada: draft.parentesco == opcion,
                        compacta: true
                    ) {
                        draft.parentesco = opcion
                    }
                }
            }
            .vibracion(.selection, trigger: draft.parentesco)
        }
    }

    private var pasoNacimiento: some View {
        VStack(alignment: .leading, spacing: 20) {
            pregunta(
                "¿Cuándo nació \(nombre)?",
                ayuda: "Por ejemplo: 15 de marzo de 1952."
            )

            HStack(alignment: .top, spacing: 12) {
                CampoNumero(titulo: "Día", ejemplo: "15", texto: $draft.dia, maximo: 2, error: errores[.dia] != nil, foco: $foco, campo: .dia)
                    .frame(maxWidth: 90)
                selectorMes
                CampoNumero(titulo: "Año", ejemplo: "1952", texto: $draft.anio, maximo: 4, error: errores[.anio] != nil, foco: $foco, campo: .anio)
                    .frame(maxWidth: 110)
            }

            ForEach([Campo.dia, .mes, .anio], id: \.self) { campo in
                MensajeError(texto: errores[campo])
            }

            if let edad = draft.edad {
                Label("Tiene \(edad) \(edad == 1 ? "año" : "años")", systemImage: "birthday.cake")
                    .font(.app(.headline))
                    .foregroundColor(.brandRed)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.tintaSuave))
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(reducirMovimiento ? nil : .spring(duration: 0.3), value: draft.edad)
        .onChange(of: draft.dia) { _, nuevo in
            if nuevo.count == 2 { foco = nil }
        }
    }

    private var selectorMes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mes")
                .font(.app(.headline))
            Menu {
                Picker("Mes", selection: $draft.mes) {
                    ForEach(1...12, id: \.self) { m in
                        Text(FamiliarDraft.meses[m - 1].capitalized).tag(Optional(m))
                    }
                }
            } label: {
                HStack {
                    Text(draft.mes.map { FamiliarDraft.meses[$0 - 1].capitalized } ?? "Elegir")
                        .foregroundColor(draft.mes == nil ? Color(.placeholderText) : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.app(.footnote))
                        .foregroundColor(.textoSuave)
                }
                .font(.app(.title3))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 56)
                .fieldBorder(errores[.mes] != nil)
            }
            .accessibilityLabel("Mes")
            .accessibilityValue(draft.mes.map { FamiliarDraft.meses[$0 - 1] } ?? "sin elegir")
        }
    }

    private var pasoCuidado: some View {
        VStack(alignment: .leading, spacing: 16) {
            pregunta(
                "¿Qué tipo de cuidado necesita \(nombre)?",
                ayuda: "Elige la opción que más se parezca. Podrás cambiarla después."
            )

            MensajeError(texto: errores[.tipoCuidado])

            VStack(spacing: 12) {
                ForEach(TipoCuidado.allCases) { opcion in
                    OpcionGrande(
                        titulo: opcion.titulo,
                        descripcion: opcion.descripcion,
                        icono: opcion.icono,
                        seleccionada: draft.tipoCuidado == opcion
                    ) {
                        draft.tipoCuidado = opcion
                    }
                }
            }
            .vibracion(.selection, trigger: draft.tipoCuidado)
        }
    }

    private var pasoContacto: some View {
        VStack(alignment: .leading, spacing: 20) {
            pregunta(
                "¿Quieres agregar el teléfono de \(nombre)?",
                ayuda: "Es opcional. Te permitirá llamarle desde la app, incluso en una emergencia."
            )

            CampoTexto(
                titulo: "Teléfono (opcional)",
                ejemplo: "81 1234 5678",
                texto: $draft.telefono,
                error: errores[.telefono],
                foco: $foco,
                campo: .telefono,
                contenido: .telephoneNumber,
                teclado: .phonePad
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("¿Algo que debamos saber? (opcional)")
                    .font(.app(.headline))
                TextField("Ej. Usa bastón, prefiere que le digan Rosy", text: $draft.notas, axis: .vertical)
                    .font(.app(.title3))
                    .lineLimit(3...6)
                    .padding(16)
                    .fieldBorder(false)
                    .focused($foco, equals: .notas)
                    .accessibilityLabel("Notas, opcional")
            }
        }
    }

    private var pasoRevision: some View {
        VStack(alignment: .leading, spacing: 20) {
            pregunta(
                "Revisa los datos de \(nombre)",
                ayuda: "Si algo no está bien, toca «Cambiar»."
            )

            VStack(spacing: 0) {
                FilaRevision(titulo: "Nombre", valor: "\(draft.nombre) \(draft.apellidos)") { ir(a: .nombre) }
                Divider().padding(.leading, 16)
                FilaRevision(titulo: "Relación contigo", valor: draft.parentesco?.titulo ?? "—") { ir(a: .relacion) }
                Divider().padding(.leading, 16)
                FilaRevision(titulo: "Fecha de nacimiento", valor: textoFecha) { ir(a: .nacimiento) }
                Divider().padding(.leading, 16)
                FilaRevision(titulo: "Tipo de cuidado", valor: draft.tipoCuidado?.titulo ?? "—") { ir(a: .cuidado) }
                Divider().padding(.leading, 16)
                FilaRevision(titulo: "Teléfono", valor: draft.telefono.isEmpty ? "Sin teléfono" : formatearTelefono(draft.telefonoDigitos)) { ir(a: .contacto) }
                if !draft.notas.isEmpty {
                    Divider().padding(.leading, 16)
                    FilaRevision(titulo: "Notas", valor: draft.notas) { ir(a: .contacto) }
                }
            }
            .tarjetaBorde()

            HStack(spacing: 8) {
                Image(systemName: "lock.fill").font(.app(.caption))
                Text("Solo tú y las personas que invites podrán ver estos datos.")
                    .font(.app(.footnote))
            }
            .foregroundColor(.textoSuave)
        }
    }

    private var textoFecha: String {
        guard let f = draft.fechaNacimiento else { return "—" }
        let texto = f.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "es_MX")))
        return draft.edad.map { "\(texto) · \($0) años" } ?? texto
    }

    private var pie: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: textoBoton) {
                continuar()
            }
            .disabled(guardando)
            .opacity(guardando ? 0.7 : 1)

            if paso == .contacto && draft.telefono.isEmpty && draft.notas.isEmpty {
                Button("Omitir por ahora") {
                    continuar()
                }
                .font(.app(.headline))
                .foregroundColor(.brandRed)
                .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color(.systemBackground).shadow(color: .black.opacity(0.06), radius: 8, y: -4))
    }

    private var textoBoton: String {
        if guardando { return "Guardando…" }
        if paso == .revision { return "Guardar a \(nombre)" }
        if volverARevision { return "Volver a la revisión" }
        return "Continuar"
    }

    private func continuar() {
        if paso == .revision {
            Task { await guardar() }
            return
        }
        pasosIntentados.insert(paso)
        let erroresPaso = draft.errores(en: paso)
        guard erroresPaso.isEmpty else {
            intentosFallidos += 1
            if let campo = paso.campos.first(where: { erroresPaso[$0] != nil }) {
                if [.nombre, .apellidos, .dia, .anio, .telefono].contains(campo) { foco = campo }
                if let mensaje = erroresPaso[campo] {
                    AccessibilityNotification.Announcement(mensaje).post()
                }
            }
            return
        }
        foco = nil
        avanzando = true
        cambiar {
            if volverARevision {
                volverARevision = false
                paso = .revision
            } else if let siguiente = Paso(rawValue: paso.rawValue + 1) {
                paso = siguiente
            }
        }
    }

    private func atras() {
        guard let anterior = Paso(rawValue: paso.rawValue - 1) else {
            salir()
            return
        }
        foco = nil
        avanzando = false
        volverARevision = false
        cambiar { paso = anterior }
    }

    private func ir(a destino: Paso) {
        avanzando = false
        volverARevision = true
        cambiar { paso = destino }
    }

    private func cambiar(_ accion: () -> Void) {
        if reducirMovimiento {
            accion()
        } else {
            withAnimation(.easeInOut(duration: 0.3), accion)
        }
    }

    private func salir() {
        if draft.tieneDatos { confirmarSalida = true } else { dismiss() }
    }

    private func enfocarInicio() {
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            tituloEnfocado = true
            switch paso {
            case .nombre where draft.nombre.isEmpty: foco = .nombre
            case .nacimiento where draft.dia.isEmpty: foco = .dia
            default: break
            }
        }
    }

    private func guardar() async {
        guard let familiar = draft.construir() else {
            if let primero = Paso.preguntas.first(where: { !draft.errores(en: $0).isEmpty }) {
                pasosIntentados.insert(primero)
                ir(a: primero)
            }
            intentosFallidos += 1
            return
        }
        guardando = true
        defer { guardando = false }
        if let error = await store.agregar(familiar) {
            errorGuardado = error
        } else {
            seleccionID = familiar.id.uuidString
            creado = familiar
        }
    }

    private func formatearTelefono(_ t: String) -> String {
        guard t.count == 10 else { return t }
        return "\(t.prefix(2)) \(t.dropFirst(2).prefix(4)) \(t.suffix(4))"
    }
}

private struct CampoTexto: View {
    let titulo: String
    let ejemplo: String
    @Binding var texto: String
    let error: String?
    var foco: FocusState<FamiliarDraft.Campo?>.Binding
    let campo: FamiliarDraft.Campo
    var contenido: UITextContentType? = nil
    var teclado: UIKeyboardType = .default
    var siguiente: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo)
                .font(.app(.headline))
            TextField("Ej. \(ejemplo)", text: $texto)
                .font(.app(.title3))
                .textContentType(contenido)
                .keyboardType(teclado)
                .autocorrectionDisabled()
                .textInputAutocapitalization(teclado == .default ? .words : .never)
                .submitLabel(siguiente == nil ? .done : .next)
                .onSubmit { siguiente?() }
                .focused(foco, equals: campo)
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .fieldBorder(error != nil)
                .accessibilityLabel(titulo)
                .accessibilityHint(error ?? "")
            MensajeError(texto: error)
        }
    }
}

private struct CampoNumero: View {
    let titulo: String
    let ejemplo: String
    @Binding var texto: String
    let maximo: Int
    let error: Bool
    var foco: FocusState<FamiliarDraft.Campo?>.Binding
    let campo: FamiliarDraft.Campo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo)
                .font(.app(.headline))
            TextField(ejemplo, text: $texto)
                .font(.app(.title3).monospacedDigit())
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .focused(foco, equals: campo)
                .frame(minHeight: 56)
                .fieldBorder(error)
                .onChange(of: texto) { _, nuevo in
                    let limpio = String(nuevo.filter(\.isNumber).prefix(maximo))
                    if limpio != nuevo { texto = limpio }
                }
                .accessibilityLabel(titulo)
        }
    }
}

struct MensajeError: View {
    let texto: String?

    var body: some View {
        if let texto {
            Label(texto, systemImage: "exclamationmark.circle.fill")
                .font(.app(.subheadline).weight(.semibold))
                .foregroundColor(.brandRed)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
        }
    }
}

struct OpcionGrande: View {
    let titulo: String
    var descripcion: String? = nil
    var icono: String? = nil
    let seleccionada: Bool
    var compacta = false
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 14) {
                if let icono {
                    ZStack {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 48, height: 48)
                        Image(systemName: icono)
                            .icono(.mediano)
                            .foregroundColor(seleccionada ? .white : .brandRed)
                    }
                    .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(titulo)
                        .font(.app(.headline))
                    if let descripcion {
                        Text(descripcion)
                            .font(.app(.subheadline))
                            .opacity(0.85)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: seleccionada ? "checkmark.circle.fill" : "circle")
                    .icono(.seleccion)
                    .foregroundColor(seleccionada ? .white : Color.iconoSuave)
                    .accessibilityHidden(true)
            }
            .foregroundColor(seleccionada ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, compacta ? 14 : 16)
            .frame(maxWidth: .infinity, minHeight: compacta ? 60 : 76, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(seleccionada ? Color.rojoSolido : Color.superficie)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(seleccionada ? Color.rojoSolido : Color.borderGray, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(seleccionada ? [.isButton, .isSelected] : .isButton)
    }
}

private struct FilaRevision: View {
    let titulo: String
    let valor: String
    let cambiar: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titulo)
                    .font(.app(.subheadline))
                    .foregroundColor(.textoSuave)
                Text(valor)
                    .font(.app(.body).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Cambiar", action: cambiar)
                .font(.app(.subheadline).weight(.bold))
                .foregroundColor(.brandRed)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Cambiar \(titulo.lowercased())")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }
}

struct AltaExitosaView: View {
    let persona: Familiar
    let terminar: () -> Void

    @Environment(\.reducirMovimiento) private var reducirMovimiento
    @State private var aparecer = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.tintaSuave)
                    .frame(width: 140, height: 140)
                    .scaleEffect(aparecer || reducirMovimiento ? 1 : 0.6)
                FamiliarAvatar(familiar: persona, tamano: 96)
                    .accessibilityIgnoresInvertColors()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white, Color.green)
                    .offset(x: 44, y: 44)
                    .scaleEffect(aparecer || reducirMovimiento ? 1 : 0.1)
            }
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("¡\(persona.nombre) ya está en CruzContigo!")
                    .font(.app(.title).weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Ahora completa su información médica para tenerla a la mano en una emergencia.")
                    .font(.app(.body))
                    .foregroundColor(.textoSuave)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)

            Spacer()

            VStack(spacing: 12) {
                NavigationLink(value: Ruta.modulo(.fichaMedica, familiarID: persona.id)) {
                    Text("Completar información médica")
                        .font(.app(.headline))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.rojoSolido))
                }
                Button("Ir al inicio", action: terminar)
                    .font(.app(.headline))
                    .foregroundColor(.brandRed)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
        }
        .padding(24)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) { aparecer = true }
        }
    }
}
