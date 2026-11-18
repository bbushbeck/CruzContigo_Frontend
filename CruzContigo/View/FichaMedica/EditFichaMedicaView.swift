//
//  EditFichaMedicaView.swift
//  CruzContigo
//
//  Una pregunta por pantalla. Lo esencial para una emergencia va primero
//  y los detalles opcionales al final.
//

import SwiftUI

struct EditFichaMedicaView: View {
    let nombre: String

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditFichaMedicaViewModel
    @State private var confirmarSalida = false

    init(ficha: FichaMedica, nombre: String, onGuardar: @escaping (FichaMedica) async -> String?) {
        self.nombre = nombre
        _viewModel = State(initialValue: EditFichaMedicaViewModel(ficha: ficha, onGuardar: onGuardar))
    }

    private var persona: String { nombre.isEmpty ? "esta persona" : nombre }
    private var tiene: String { nombre.isEmpty ? "Tiene" : nombre + " tiene" }

    var body: some View {
        VStack(spacing: 0) {
            encabezado

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch viewModel.paso {
                    case .sangre: pasoSangre
                    case .alergias: pasoAlergias
                    case .enfermedades: pasoEnfermedades
                    case .detalles: pasoDetalles
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .id(viewModel.paso)

            botones
        }
        .tint(.brandRed)
        .interactiveDismissDisabled(viewModel.guardando || viewModel.hayCambios)
        .confirmationDialog("¿Salir sin guardar?", isPresented: $confirmarSalida, titleVisibility: .visible) {
            Button("Salir sin guardar", role: .destructive) { dismiss() }
            Button("Seguir editando", role: .cancel) {}
        } message: {
            Text("Se perderán los cambios que hizo.")
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

    // MARK: - Encabezado y botones

    private var encabezado: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Cancelar") {
                    if viewModel.hayCambios { confirmarSalida = true } else { dismiss() }
                }
                .foregroundColor(.brandRed)
                .frame(minHeight: 44)
                Spacer()
                Text("Paso \(viewModel.paso.numero) de \(EditFichaMedicaViewModel.Paso.allCases.count)")
                    .font(.app(.headline))
                Spacer()
                // Al editar una ficha existente se puede guardar desde cualquier paso.
                if !viewModel.esNueva {
                    Button("Guardar") { Task { await guardar() } }
                        .font(.app(.body).weight(.bold))
                        .foregroundColor(.brandRed)
                        .frame(minHeight: 44)
                        .disabled(viewModel.guardando)
                } else {
                    Button("Cancelar") {}.hidden()
                }
            }
            ProgressView(value: viewModel.progreso)
                .tint(.brandRed)
                .accessibilityLabel("Avance")
                .accessibilityValue("Paso \(viewModel.paso.numero) de \(EditFichaMedicaViewModel.Paso.allCases.count)")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var botones: some View {
        VStack(spacing: 10) {
            if viewModel.mostrarError, let error = viewModel.errorPaso {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.app(.subheadline).weight(.semibold))
                    .foregroundColor(.brandRed)
            }
            HStack(spacing: 12) {
                if viewModel.paso != .sangre {
                    Button {
                        withAnimation { viewModel.atras() }
                    } label: {
                        Text("Atrás")
                            .font(.app(.headline))
                            .foregroundColor(.brandRed)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.tintaSuave))
                    }
                    .frame(maxWidth: 140)
                }
                if viewModel.esUltimoPaso {
                    PrimaryButton(title: viewModel.guardando ? "Guardando…" : "Guardar ficha") {
                        Task { await guardar() }
                    }
                    .disabled(viewModel.guardando)
                    .opacity(viewModel.guardando ? 0.7 : 1)
                } else {
                    PrimaryButton(title: "Siguiente") {
                        withAnimation { _ = viewModel.siguiente() }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func guardar() async {
        if await viewModel.guardar() { dismiss() }
    }

    // MARK: - Pasos

    private var pasoSangre: some View {
        VStack(alignment: .leading, spacing: 20) {
            Pregunta(
                texto: "¿Cuál es el tipo de sangre de \(persona)?",
                ayuda: "Viene en estudios de laboratorio o en la credencial de donador. Si no lo sabe, elija «No lo sé»."
            )
            ChipSelector(
                opciones: EditFichaMedicaViewModel.tiposSangre,
                seleccion: $viewModel.ficha.tipoSanguineo,
                titulo: \.titulo
            )
        }
    }

    private var pasoAlergias: some View {
        VStack(alignment: .leading, spacing: 20) {
            Pregunta(
                texto: "¿\(tiene) alguna alergia?",
                ayuda: "A medicinas, alimentos u otras cosas."
            )
            SiNoSelector(respuesta: $viewModel.tieneAlergias)

            if viewModel.tieneAlergias == true {
                Text("Toque las que tenga:")
                    .font(.app(.headline))
                ChipsMultiples(
                    opciones: viewModel.opcionesAlergia,
                    seleccionada: viewModel.tieneAlergia,
                    alternar: viewModel.alternarAlergia
                )
                CampoOtra(
                    titulo: "¿Otra alergia?",
                    placeholder: "Escriba el nombre",
                    texto: $viewModel.otraAlergia,
                    agregar: viewModel.agregarOtraAlergia
                )

                if !viewModel.ficha.alergias.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("¿Qué le pasa con cada una?")
                            .font(.app(.headline))
                        ForEach(viewModel.ficha.alergias) { alergia in
                            FilaSeveridad(alergia: alergia) { severidad in
                                viewModel.cambiarSeveridad(de: alergia, a: severidad)
                            }
                        }
                    }
                }
            }
        }
    }

    private var pasoEnfermedades: some View {
        VStack(alignment: .leading, spacing: 20) {
            Pregunta(
                texto: "¿\(tiene) alguna enfermedad?",
                ayuda: "Enfermedades que tiene ahora y requieren cuidado o medicinas."
            )
            SiNoSelector(respuesta: $viewModel.tieneEnfermedades)

            if viewModel.tieneEnfermedades == true {
                Text("Toque las que tenga:")
                    .font(.app(.headline))
                ChipsMultiples(
                    opciones: viewModel.opcionesEnfermedad,
                    seleccionada: viewModel.tieneEnfermedad,
                    alternar: viewModel.alternarEnfermedad
                )
                CampoOtra(
                    titulo: "¿Otra enfermedad?",
                    placeholder: "Escriba el nombre",
                    texto: $viewModel.otraEnfermedad,
                    agregar: viewModel.agregarOtraEnfermedad
                )
            }
        }
    }

    private var pasoDetalles: some View {
        VStack(alignment: .leading, spacing: 24) {
            Pregunta(
                texto: "Más detalles",
                ayuda: "Todo es opcional. Puede dejarlo en blanco y completarlo después."
            )

            FormFieldContainer(titulo: "¿Quién es su doctor?", error: viewModel.errorMedico) {
                TextField("Nombre del doctor o doctora", text: $viewModel.medicoTratante)
                    .textContentType(.name)
                    .padding(16)
                    .fieldBorder(viewModel.errorMedico != nil)
            }

            FormFieldContainer(titulo: "¿Dónde se atiende?", error: viewModel.errorInstitucion) {
                ChipsMultiples(
                    opciones: EditFichaMedicaViewModel.instituciones,
                    seleccionada: { $0 == viewModel.institucionSalud },
                    alternar: { opcion in
                        viewModel.institucionSalud = viewModel.institucionSalud == opcion ? "" : opcion
                    }
                )
                TextField("U otro lugar", text: $viewModel.institucionSalud)
                    .padding(16)
                    .fieldBorder(viewModel.errorInstitucion != nil)
            }

            FormFieldContainer(titulo: "¿Le han operado o ha tenido enfermedades importantes?", error: viewModel.errorAntecedentes) {
                TextField("Ej. Operación de cadera en 2020", text: $viewModel.antecedentes, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(16)
                    .fieldBorder(viewModel.errorAntecedentes != nil)
            }

            FormFieldContainer(titulo: "¿Algo más que deba saber un médico?", error: viewModel.errorObservaciones) {
                TextField("Ej. Usa marcapasos, lentes o una dieta especial", text: $viewModel.observaciones, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(16)
                    .fieldBorder(viewModel.errorObservaciones != nil)
            }
        }
    }
}

// MARK: - Componentes

private struct Pregunta: View {
    let texto: String
    let ayuda: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(texto)
                .font(.app(.title2).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(ayuda)
                .font(.app(.body))
                .foregroundColor(.textoSuave)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Dos botones grandes: contestar «No» es un solo toque.
private struct SiNoSelector: View {
    @Binding var respuesta: Bool?

    var body: some View {
        HStack(spacing: 12) {
            boton("Sí", valor: true)
            boton("No", valor: false)
        }
        .vibracion(.selection, trigger: respuesta)
    }

    private func boton(_ titulo: String, valor: Bool) -> some View {
        let activo = respuesta == valor
        return Button {
            withAnimation { respuesta = valor }
        } label: {
            Text(titulo)
                .font(.app(.title3).weight(.bold))
                .foregroundColor(activo ? .white : .primary)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(RoundedRectangle(cornerRadius: 16).fill(activo ? Color.rojoSolido : Color.superficie))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(activo ? Color.rojoSolido : Color.borderGray, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(activo ? .isSelected : [])
    }
}

/// Chips que se marcan y desmarcan con un toque. Desmarcar es la forma de quitar,
/// así que no hay botones de borrar que se puedan tocar por error.
private struct ChipsMultiples: View {
    let opciones: [String]
    let seleccionada: (String) -> Bool
    let alternar: (String) -> Void

    @Environment(\.dynamicTypeSize) private var tipo

    private var columnas: [GridItem] {
        [GridItem(.adaptive(minimum: tipo.isAccessibilitySize ? 220 : 140), spacing: 8)]
    }

    var body: some View {
        LazyVGrid(columns: columnas, alignment: .leading, spacing: 8) {
            ForEach(opciones, id: \.self) { opcion in
                let activo = seleccionada(opcion)
                Button {
                    alternar(opcion)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: activo ? "checkmark.circle.fill" : "circle")
                            .accessibilityHidden(true)
                        Text(opcion)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .font(.app(.subheadline).weight(.semibold))
                    .foregroundColor(activo ? .white : .primary)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 12).fill(activo ? Color.rojoSolido : Color.superficie))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(activo ? Color.rojoSolido : Color.borderGray, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(activo ? .isSelected : [])
            }
        }
    }
}

private struct CampoOtra: View {
    let titulo: String
    let placeholder: String
    @Binding var texto: String
    let agregar: () -> Void

    private var habilitado: Bool { !texto.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        FormFieldContainer(titulo: titulo) {
            HStack(spacing: 8) {
                TextField(placeholder, text: $texto)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .fieldBorder(false)
                    .onSubmit(agregar)
                Button("Agregar", action: agregar)
                    .font(.app(.subheadline).weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.rojoSolido))
                    .disabled(!habilitado)
                    .opacity(habilitado ? 1 : 0.4)
            }
        }
    }
}

private struct FilaSeveridad: View {
    let alergia: Alergia
    let cambiar: (Severidad) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(alergia.nombre)
                .font(.app(.body).weight(.semibold))
            Picker("Qué le pasa con \(alergia.nombre)", selection: Binding(
                get: { alergia.severidad },
                set: { cambiar($0) }
            )) {
                ForEach(Severidad.allCases) { severidad in
                    Text(severidad.descripcion).tag(severidad)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .padding(14)
        .tarjetaBorde(radio: 14)
    }
}
