import SwiftUI
import PhotosUI
import UIKit

/// Formulario para agregar o editar un tratamiento. La validación vive en `MedicationDraft`.
struct MedicationFormView: View {
    let recipientID: UUID
    @ObservedObject var model: MedicationViewModel
    var editing: Medication?
    @Environment(\.dismiss) private var dismiss

    @State private var draft: MedicationDraft
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var recetaSelection: PhotosPickerItem?
    @State private var recetaExtraida: RecetaExtraida?
    @State private var isReadingReceta = false
    @State private var recetaError: String?
    @State private var recetaAplicada = false
    @State private var recetaGuardada = false

    init(recipientID: UUID, model: MedicationViewModel, editing: Medication? = nil) {
        self.recipientID = recipientID
        self.model = model
        self.editing = editing
        _draft = State(initialValue: editing.map(MedicationDraft.init(medication:)) ?? MedicationDraft())
    }

    var body: some View {
        Form {
            if #available(iOS 27.0, *) {
                Section("Leer receta") {
                    PhotosPicker(selection: $recetaSelection, matching: .images) {
                        Label("Seleccionar foto de receta", systemImage: "doc.viewfinder")
                    }
                    .disabled(isReadingReceta || isSaving)

                    if isReadingReceta {
                        ProgressView("Leyendo receta...")
                    }

                    if recetaGuardada {
                        Label("Foto guardada en Información médica › Documentos.", systemImage: "checkmark.circle.fill")
                            .font(.app(.footnote))
                            .foregroundStyle(Color.textoSuave)
                    }

                    if let recetaError {
                        Text(recetaError)
                            .font(.app(.footnote))
                            .foregroundStyle(MedicalStyle.red)
                    }

                    if let recetaExtraida {
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
                                    aplicar(medicamento)
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

                    if recetaAplicada {
                        Label("Formulario actualizado. Revisa y completa los datos antes de guardar.",
                              systemImage: "checkmark.circle.fill")
                            .font(.app(.footnote))
                            .foregroundStyle(Color.textoSuave)
                    }
                }
                .onChange(of: recetaSelection) { _, item in
                    guard let item else { return }
                    Task { await leerReceta(item) }
                }
            }

            Section("Medicamento") {
                TextField("Nombre del medicamento", text: $draft.name)
                TextField("Presentación (opcional, ej. tableta)", text: $draft.presentation)
                TextField("Dosis numérica (ej. 500 o 0,5)", text: $draft.dose)
                    .keyboardType(.decimalPad)
                TextField("Unidad (opcional, ej. mg o ml)", text: $draft.unit)
                TextField("Frecuencia (opcional)", text: $draft.frequency)
                Text("La dosis debe ser mayor que cero y tener como máximo dos decimales.")
                    .font(.app(.footnote)).foregroundStyle(Color.textoSuave)
            }
            Section("Fechas") {
                DatePicker("Fecha de inicio", selection: $draft.startDate, displayedComponents: .date)
                Toggle("Tiene fecha de fin", isOn: $draft.hasEndDate)
                if draft.hasEndDate {
                    DatePicker("Fecha de fin", selection: $draft.endDate,
                               in: Calendar.current.startOfDay(for: draft.startDate)..., displayedComponents: .date)
                }
                Text("Los tratamientos cuya fecha de fin ya pasó aparecen en Anteriores.")
                    .font(.app(.footnote)).foregroundStyle(Color.textoSuave)
            }
            Section("Información adicional") {
                TextField("Indicación (opcional)", text: $draft.indication, axis: .vertical)
                TextField("Existencias (opcional)", text: $draft.stock)
                    .keyboardType(.decimalPad)
                Stepper("Umbral de resurtido: \(draft.refillThresholdDays) días",
                        value: $draft.refillThresholdDays, in: 0...32767)
            }
            Section {
                Text("Registra únicamente indicaciones confirmadas por un profesional de salud. Esta app no calcula ni recomienda dosis.")
                    .font(.app(.footnote)).foregroundStyle(Color.textoSuave)
            }
        }
        .navigationTitle(editing == nil ? "Agregar medicamento" : "Editar medicamento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
                    .disabled(isSaving || isReadingReceta)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    let medication = draft.medication(id: editing?.id ?? UUID(), recipientID: recipientID)
                    isSaving = true
                    Task {
                        let error = await model.save(medication, updating: editing != nil)
                        isSaving = false
                        if let error {
                            saveError = error
                        } else {
                            dismiss()
                        }
                    }
                }
                .disabled(!draft.isValid || isSaving || isReadingReceta)
            }
        }
        .interactiveDismissDisabled(isSaving || isReadingReceta)
        .alert("No se pudo guardar", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Aceptar", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }
        .tint(MedicalStyle.red)
    }

    @available(iOS 27.0, *)
    private func leerReceta(_ item: PhotosPickerItem) async {
        isReadingReceta = true
        recetaError = nil
        recetaExtraida = nil
        recetaAplicada = false
        recetaGuardada = false
        defer {
            isReadingReceta = false
            recetaSelection = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let imagen = UIImage(data: data) else {
                throw RecetaExtractorError.imagenInvalida
            }
            guard let archivo = imagen.jpegData(compressionQuality: 0.9) else {
                throw RecetaExtractorError.imagenInvalida
            }
            try DocumentosMedicosRepository.guardar(
                archivo,
                titulo: "Receta médica",
                extensionArchivo: "jpg",
                tipo: .receta,
                familiarID: recipientID
            )
            recetaGuardada = true
            let receta = try await RecetaExtractor().extraer(desde: imagen)
            if receta.medicamentos.count == 1, let medicamento = receta.medicamentos.first {
                aplicar(medicamento)
            } else {
                recetaExtraida = receta
            }
        } catch {
            recetaError = "No se pudo leer la receta: \(error.localizedDescription)"
        }
    }

    private func aplicar(_ medicamento: MedicamentoExtraido) {
        draft.aplicar(medicamento)
        recetaExtraida = nil
        recetaAplicada = true
    }
}
