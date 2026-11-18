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

    @State private var viewModel = AltaPersonaViewModel()
    @State private var confirmarSalida = false
    @FocusState private var foco: Campo?
    @AccessibilityFocusState private var tituloEnfocado: Bool

    var body: some View {
        Group {
            if let creado = viewModel.creado {
                AltaExitosaView(persona: creado) { dismiss() }
                    .transition(.opacity)
            } else {
                flujo
            }
        }
        .animation(reducirMovimiento ? nil : .easeInOut(duration: 0.25), value: viewModel.creado != nil)
        .vibracion(.error, trigger: viewModel.intentosFallidos)
        .vibracion(.success, trigger: viewModel.creado != nil)
        .confirmationDialog("¿Salir sin guardar?", isPresented: $confirmarSalida, titleVisibility: .visible) {
            Button("Salir sin guardar", role: .destructive) { dismiss() }
            Button("Seguir editando", role: .cancel) {}
        } message: {
            Text("Se perderán los datos que escribiste.")
        }
        .alert("No se pudo guardar", isPresented: Binding(
            get: { viewModel.errorGuardado != nil },
            set: { if !$0 { viewModel.errorGuardado = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(viewModel.errorGuardado ?? "")
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
                .id(viewModel.paso)
                .transition(transicion)
            }
            .frame(maxHeight: .infinity)
            .clipped()

            pie
        }
        .onChange(of: viewModel.paso) {
            enfocarInicio()
        }
        .onAppear {
            enfocarInicio()
        }
    }

    private var transicion: AnyTransition {
        if reducirMovimiento { return .opacity }
        return .asymmetric(
            insertion: .move(edge: viewModel.avanzando ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: viewModel.avanzando ? .leading : .trailing).combined(with: .opacity)
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
                .accessibilityLabel(viewModel.paso == .nombre ? "Salir" : "Paso anterior")

                Spacer()

                Text(viewModel.paso == .revision ? "Revisión final" : "Paso \(viewModel.paso.rawValue + 1) de \(Paso.preguntas.count)")
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

            ProgressBarView(progress: Double(viewModel.paso.rawValue + 1) / Double(Paso.allCases.count))
                .animation(reducirMovimiento ? nil : .easeInOut, value: viewModel.paso)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var contenidoPaso: some View {
        switch viewModel.paso {
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
                    viewModel.draft.completar(con: contacto)
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
                texto: $viewModel.draft.nombre,
                error: viewModel.errores[.nombre],
                foco: $foco,
                campo: .nombre,
                contenido: .givenName,
                siguiente: { foco = .apellidos }
            )

            CampoTexto(
                titulo: "Apellidos",
                ejemplo: "Hernández López",
                texto: $viewModel.draft.apellidos,
                error: viewModel.errores[.apellidos],
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
                "¿Qué es \(viewModel.nombre) para ti?",
                ayuda: "Nos ayuda a personalizar los mensajes y recordatorios."
            )

            MensajeError(texto: viewModel.errores[.parentesco])

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(Parentesco.allCases) { opcion in
                    OpcionGrande(
                        titulo: opcion.titulo,
                        seleccionada: viewModel.draft.parentesco == opcion,
                        compacta: true
                    ) {
                        viewModel.draft.parentesco = opcion
                    }
                }
            }
            .vibracion(.selection, trigger: viewModel.draft.parentesco)
        }
    }

    private var pasoNacimiento: some View {
        VStack(alignment: .leading, spacing: 20) {
            pregunta(
                "¿Cuándo nació \(viewModel.nombre)?",
                ayuda: "Por ejemplo: 15 de marzo de 1952."
            )

            HStack(alignment: .top, spacing: 12) {
                CampoNumero(titulo: "Día", ejemplo: "15", texto: $viewModel.draft.dia, maximo: 2, error: viewModel.errores[.dia] != nil, foco: $foco, campo: .dia)
                    .frame(maxWidth: 90)
                selectorMes
                CampoNumero(titulo: "Año", ejemplo: "1952", texto: $viewModel.draft.anio, maximo: 4, error: viewModel.errores[.anio] != nil, foco: $foco, campo: .anio)
                    .frame(maxWidth: 110)
            }

            ForEach([Campo.dia, .mes, .anio], id: \.self) { campo in
                MensajeError(texto: viewModel.errores[campo])
            }

            if let edad = viewModel.draft.edad {
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
        .animation(reducirMovimiento ? nil : .spring(duration: 0.3), value: viewModel.draft.edad)
        .onChange(of: viewModel.draft.dia) { _, nuevo in
            if nuevo.count == 2 { foco = nil }
        }
    }

    private var selectorMes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mes")
                .font(.app(.headline))
            Menu {
                Picker("Mes", selection: $viewModel.draft.mes) {
                    ForEach(1...12, id: \.self) { m in
                        Text(FamiliarDraft.meses[m - 1].capitalized).tag(Optional(m))
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.draft.mes.map { FamiliarDraft.meses[$0 - 1].capitalized } ?? "Elegir")
                        .foregroundColor(viewModel.draft.mes == nil ? Color(.placeholderText) : .primary)
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
                .fieldBorder(viewModel.errores[.mes] != nil)
            }
            .accessibilityLabel("Mes")
            .accessibilityValue(viewModel.draft.mes.map { FamiliarDraft.meses[$0 - 1] } ?? "sin elegir")
        }
    }

    private var pasoCuidado: some View {
        VStack(alignment: .leading, spacing: 16) {
            pregunta(
                "¿Qué tipo de cuidado necesita \(viewModel.nombre)?",
                ayuda: "Elige la opción que más se parezca. Podrás cambiarla después."
            )

            MensajeError(texto: viewModel.errores[.tipoCuidado])

            VStack(spacing: 12) {
                ForEach(TipoCuidado.allCases) { opcion in
                    OpcionGrande(
                        titulo: opcion.titulo,
                        descripcion: opcion.descripcion,
                        icono: opcion.icono,
                        seleccionada: viewModel.draft.tipoCuidado == opcion
                    ) {
                        viewModel.draft.tipoCuidado = opcion
                    }
                }
            }
            .vibracion(.selection, trigger: viewModel.draft.tipoCuidado)
        }
    }

    private var pasoContacto: some View {
        VStack(alignment: .leading, spacing: 20) {
            pregunta(
                "¿Quieres agregar el teléfono de \(viewModel.nombre)?",
                ayuda: "Es opcional. Te permitirá llamarle desde la app, incluso en una emergencia."
            )

            CampoTexto(
                titulo: "Teléfono (opcional)",
                ejemplo: "81 1234 5678",
                texto: $viewModel.draft.telefono,
                error: viewModel.errores[.telefono],
                foco: $foco,
                campo: .telefono,
                contenido: .telephoneNumber,
                teclado: .phonePad
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("¿Algo que debamos saber? (opcional)")
                    .font(.app(.headline))
                TextField("Ej. Usa bastón, prefiere que le digan Rosy", text: $viewModel.draft.notas, axis: .vertical)
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
                "Revisa los datos de \(viewModel.nombre)",
                ayuda: "Si algo no está bien, toca «Cambiar»."
            )

            VStack(spacing: 0) {
                FilaRevision(titulo: "Nombre", valor: "\(viewModel.draft.nombre) \(viewModel.draft.apellidos)") { ir(a: .nombre) }
                Divider().padding(.leading, 16)
                FilaRevision(titulo: "Relación contigo", valor: viewModel.draft.parentesco?.titulo ?? "—") { ir(a: .relacion) }
                Divider().padding(.leading, 16)
                FilaRevision(titulo: "Fecha de nacimiento", valor: viewModel.textoFecha) { ir(a: .nacimiento) }
                Divider().padding(.leading, 16)
                FilaRevision(titulo: "Tipo de cuidado", valor: viewModel.draft.tipoCuidado?.titulo ?? "—") { ir(a: .cuidado) }
                Divider().padding(.leading, 16)
                FilaRevision(titulo: "Teléfono", valor: viewModel.draft.telefono.isEmpty ? "Sin teléfono" : viewModel.formatearTelefono(viewModel.draft.telefonoDigitos)) { ir(a: .contacto) }
                if !viewModel.draft.notas.isEmpty {
                    Divider().padding(.leading, 16)
                    FilaRevision(titulo: "Notas", valor: viewModel.draft.notas) { ir(a: .contacto) }
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

    private var pie: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: viewModel.textoBoton) {
                continuar()
            }
            .disabled(viewModel.guardando)
            .opacity(viewModel.guardando ? 0.7 : 1)

            if viewModel.paso == .contacto && viewModel.draft.telefono.isEmpty && viewModel.draft.notas.isEmpty {
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

    private func continuar() {
        switch viewModel.continuar(cambiar: cambiar) {
        case .avanzar:
            foco = nil
        case .guardar:
            Task { await viewModel.guardar(usando: store, cambiar: cambiar) }
        case .error(let campo, let mensaje):
            if let campo { foco = campo }
            if let mensaje { AccessibilityNotification.Announcement(mensaje).post() }
        }
    }

    private func atras() {
        if viewModel.atras(cambiar: cambiar) {
            salir()
        } else {
            foco = nil
        }
    }

    private func ir(a destino: Paso) {
        cambiar { viewModel.ir(a: destino) }
    }

    private func cambiar(_ accion: @escaping () -> Void) {
        if reducirMovimiento {
            accion()
        } else {
            withAnimation(.easeInOut(duration: 0.3), accion)
        }
    }

    private func salir() {
        if viewModel.salir() { confirmarSalida = true } else { dismiss() }
    }

    private func enfocarInicio() {
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            tituloEnfocado = true
            if let campo = viewModel.enfocarInicio() { foco = campo }
        }
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
