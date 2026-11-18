//
//  EditFichaMedicaView.swift
//  CruzContigo
//

import SwiftUI

struct EditFichaMedicaView: View {
    let nombre: String

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditFichaMedicaViewModel

    init(ficha: FichaMedica, nombre: String, onGuardar: @escaping (FichaMedica) async -> String?) {
        self.nombre = nombre
        _viewModel = State(initialValue: EditFichaMedicaViewModel(ficha: ficha, onGuardar: onGuardar))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancelar") { dismiss() }
                    .foregroundColor(.brandRed)
                Spacer()
                Text("Ficha médica").font(.app(.headline))
                Spacer()
                Button("Cancelar") {}.hidden()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(nombre.isEmpty ? "Datos médicos" : "Datos médicos de \(nombre)")
                            .font(.app(.title).weight(.bold))
                        Text("Usa datos ficticios durante las pruebas.")
                            .font(.app(.footnote))
                            .foregroundColor(.textoSuave)
                    }

                    FormFieldContainer(
                        titulo: "Tipo sanguíneo",
                        obligatorio: true,
                        error: viewModel.intentoGuardar && viewModel.ficha.tipoSanguineo == nil ? "Selecciona una opción." : nil
                    ) {
                        ChipSelector(
                            opciones: TipoSanguineo.allCases,
                            seleccion: $viewModel.ficha.tipoSanguineo,
                            titulo: \.titulo
                        )
                    }

                    seccionAlergias
                    seccionEnfermedades

                    FormFieldContainer(titulo: "Antecedentes (opcional)") {
                        TextField("Antecedentes familiares o médicos", text: $viewModel.antecedentes, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(16)
                            .fieldBorder(false)
                    }

                    FormFieldContainer(titulo: "Médico tratante (opcional)") {
                        TextField("Nombre del médico", text: $viewModel.medicoTratante)
                            .padding(16)
                            .fieldBorder(false)
                    }

                    FormFieldContainer(titulo: "Institución de salud (opcional)") {
                        TextField("Ej. IMSS, ISSSTE", text: $viewModel.institucionSalud)
                            .padding(16)
                            .fieldBorder(false)
                    }

                    FormFieldContainer(titulo: "Observaciones (opcional)") {
                        TextField("Ej. Marcapasos, usa lentes, dieta baja en sodio", text: $viewModel.observaciones, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(16)
                            .fieldBorder(false)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 10) {
                if viewModel.intentoGuardar, let primerError = viewModel.fichaFinal.errores.first {
                    Text(primerError)
                        .font(.app(.footnote))
                        .foregroundColor(.brandRed)
                }
                PrimaryButton(title: viewModel.guardando ? "Guardando…" : "Guardar ficha") {
                    Task {
                        if await viewModel.guardar() {
                            dismiss()
                        }
                    }
                }
                .disabled(viewModel.guardando)
                .opacity(viewModel.guardando ? 0.7 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .tint(.brandRed)
        .interactiveDismissDisabled(viewModel.guardando)
        .alert("No se pudo guardar", isPresented: Binding(
            get: { viewModel.errorGuardado != nil },
            set: { if !$0 { viewModel.errorGuardado = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(viewModel.errorGuardado ?? "")
        }
    }

    private var seccionAlergias: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alergias").font(.app(.title3)).fontWeight(.bold)

            ForEach(viewModel.ficha.alergias) { alergia in
                FilaEditable(texto: alergia.nombre) {
                    SeveridadChip(severidad: alergia.severidad)
                } eliminar: {
                    viewModel.eliminarAlergia(alergia)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Ej. Penicilina", text: $viewModel.nuevaAlergia)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .fieldBorder(false)
                        .onSubmit(viewModel.agregarAlergia)
                    BotonAgregar(habilitado: viewModel.puedeAgregarAlergia, accion: viewModel.agregarAlergia)
                }
                ChipSelector(opciones: Severidad.allCases, seleccion: $viewModel.nuevaSeveridad, titulo: \.titulo)
            }
        }
    }

    private var seccionEnfermedades: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Enfermedades").font(.app(.title3)).fontWeight(.bold)

            ForEach(viewModel.ficha.enfermedades) { enfermedad in
                FilaEditable(texto: enfermedad.nombre) {
                    EmptyView()
                } eliminar: {
                    viewModel.eliminarEnfermedad(enfermedad)
                }
            }

            HStack(spacing: 8) {
                TextField("Ej. Diabetes tipo 2", text: $viewModel.nuevaEnfermedad)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .fieldBorder(false)
                    .onSubmit(viewModel.agregarEnfermedad)
                BotonAgregar(habilitado: viewModel.puedeAgregarEnfermedad, accion: viewModel.agregarEnfermedad)
            }
        }
    }
}

private struct FilaEditable<Accesorio: View>: View {
    let texto: String
    @ViewBuilder let accesorio: Accesorio
    let eliminar: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(texto)
            Spacer()
            accesorio
            Button(action: eliminar) {
                Image(systemName: "minus.circle.fill")
                    .icono(.seleccion)
                    .foregroundColor(Color.iconoSuave)
            }
            .accessibilityLabel("Eliminar \(texto)")
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.tintaSuave))
    }
}

private struct BotonAgregar: View {
    let habilitado: Bool
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Image(systemName: "plus")
                .icono(.navegacion)
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.rojoSolido))
        }
        .disabled(!habilitado)
        .opacity(habilitado ? 1 : 0.4)
        .accessibilityLabel("Agregar")
    }
}
