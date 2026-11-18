import SwiftUI
import PhotosUI

/// Formulario para agregar o editar un tratamiento. La validación vive en `MedicationDraft`.
struct MedicationFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: MedicationFormViewModel

    init(recipientID: UUID, model: MedicationViewModel, editing: Medication? = nil) {
        _viewModel = State(initialValue: MedicationFormViewModel(
            recipientID: recipientID,
            model: model,
            editing: editing
        ))
    }

    var body: some View {
        Form {
            if #available(iOS 27.0, *) {
                Section("Leer receta") {
                    PhotosPicker(selection: $viewModel.recetaSelection, matching: .images) {
                        Label("Seleccionar foto de receta", systemImage: "doc.viewfinder")
                    }
                    .disabled(viewModel.isReadingReceta || viewModel.isSaving)

                    if viewModel.isReadingReceta {
                        ProgressView("Leyendo receta...")
                    }

                    if viewModel.recetaGuardada {
                        Label("Foto guardada en Información médica › Documentos.", systemImage: "checkmark.circle.fill")
                            .font(.app(.footnote))
                            .foregroundStyle(Color.textoSuave)
                    }

                    if let recetaError = viewModel.recetaError {
                        Text(recetaError)
                            .font(.app(.footnote))
                            .foregroundStyle(MedicalStyle.red)
                    }

                    if let recetaExtraida = viewModel.recetaExtraida {
                        if recetaExtraida.medicamentos.isEmpty {
                            Text("No se detectaron medicamentos. Puedes capturarlos manualmente.")
                        } else {
                            Text("Se detectaron varios medicamentos. Elige cuál quieres aplicar al formulario.")
                                .font(.app(.footnote))
                                .foregroundStyle(Color.textoSuave)
                            ForEach(recetaExtraida.medicamentos.indices, id: \.self) { index in
                                let medicamento = recetaExtraida.medicamentos[index]
                                let dosis = [medicamento.dosis, medicamento.unidad]
                                    .compactMap { $0 }
                                    .joined(separator: " ")
                                Button {
                                    viewModel.aplicar(medicamento)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(medicamento.nombre)
                                            .font(.app(.headline))
                                            .foregroundStyle(.primary)
                                        Text(dosis.isEmpty ? "Dosis no detectada" : dosis)
                                            .foregroundStyle(Color.textoSuave)
                                        Text("Usar este medicamento")
                                            .font(.app(.footnote))
                                            .foregroundStyle(MedicalStyle.red)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if viewModel.recetaAplicada {
                        Label("Formulario actualizado. Revisa y completa los datos antes de guardar.",
                              systemImage: "checkmark.circle.fill")
                            .font(.app(.footnote))
                            .foregroundStyle(Color.textoSuave)
                    }
                }
                .onChange(of: viewModel.recetaSelection) { _, item in
                    guard let item else { return }
                    Task { await viewModel.leerReceta(item) }
                }
            }

            Section("Medicamento") {
                TextField("Nombre del medicamento", text: $viewModel.draft.name)
                TextField("Presentación (opcional, ej. tableta)", text: $viewModel.draft.presentation)
                TextField("Dosis numérica (ej. 500 o 0,5)", text: $viewModel.draft.dose)
                    .keyboardType(.decimalPad)
                TextField("Unidad (opcional, ej. mg o ml)", text: $viewModel.draft.unit)
                TextField("Frecuencia (opcional)", text: $viewModel.draft.frequency)
                Text("La dosis debe ser mayor que cero y tener como máximo dos decimales.")
                    .font(.app(.footnote)).foregroundStyle(Color.textoSuave)
            }
            Section("Fechas") {
                DatePicker("Fecha de inicio", selection: $viewModel.draft.startDate, displayedComponents: .date)
                Toggle("Tiene fecha de fin", isOn: $viewModel.draft.hasEndDate)
                if viewModel.draft.hasEndDate {
                    DatePicker("Fecha de fin", selection: $viewModel.draft.endDate,
                               in: Calendar.current.startOfDay(for: viewModel.draft.startDate)..., displayedComponents: .date)
                }
                Text("Los tratamientos cuya fecha de fin ya pasó aparecen en Anteriores.")
                    .font(.app(.footnote)).foregroundStyle(Color.textoSuave)
            }
            Section("Información adicional") {
                TextField("Indicación (opcional)", text: $viewModel.draft.indication, axis: .vertical)
                TextField("Existencias (opcional)", text: $viewModel.draft.stock)
                    .keyboardType(.decimalPad)
                Stepper("Umbral de resurtido: \(viewModel.draft.refillThresholdDays) días",
                        value: $viewModel.draft.refillThresholdDays, in: 0...32767)
            }
            Section {
                Text("Registra únicamente indicaciones confirmadas por un profesional de salud. Esta app no calcula ni recomienda dosis.")
                    .font(.app(.footnote)).foregroundStyle(Color.textoSuave)
            }
        }
        .navigationTitle(viewModel.editing == nil ? "Agregar medicamento" : "Editar medicamento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
                    .disabled(viewModel.isSaving || viewModel.isReadingReceta)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    Task {
                        if await viewModel.guardar() { dismiss() }
                    }
                }
                .disabled(!viewModel.draft.isValid || viewModel.isSaving || viewModel.isReadingReceta)
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving || viewModel.isReadingReceta)
        .alert("No se pudo guardar", isPresented: Binding(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.saveError = nil } }
        )) {
            Button("Aceptar", role: .cancel) { viewModel.saveError = nil }
        } message: { Text(viewModel.saveError ?? "") }
        .tint(MedicalStyle.red)
    }
}
