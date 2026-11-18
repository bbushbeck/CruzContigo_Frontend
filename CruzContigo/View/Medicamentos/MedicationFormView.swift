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
    @StateObject private var receta = TranscripcionRecetaViewModel()
    @State private var mostrandoOpcionesReceta = false
    @State private var mostrandoFotos = false
    @State private var fotoReceta: PhotosPickerItem?
    @State private var fuenteCaptura: FuenteCapturaReceta?

    init(recipientID: UUID, model: MedicationViewModel, editing: Medication? = nil) {
        self.recipientID = recipientID
        self.model = model
        self.editing = editing
        _draft = State(initialValue: editing.map(MedicationDraft.init(medication:)) ?? MedicationDraft())
    }

    var body: some View {
        Form {
            seccionReceta

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
                    .disabled(isSaving || receta.leyendo)
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
                .disabled(!draft.isValid || isSaving || receta.leyendo)
            }
        }
        .interactiveDismissDisabled(isSaving || receta.leyendo)
        .confirmationDialog("Transcribir receta", isPresented: $mostrandoOpcionesReceta, titleVisibility: .visible) {
            if FuenteCapturaReceta.escaner.disponible {
                Button("Escanear receta") { fuenteCaptura = .escaner }
            }
            if FuenteCapturaReceta.camara.disponible {
                Button("Tomar foto") { fuenteCaptura = .camara }
            }
            Button("Elegir de Fotos") { mostrandoFotos = true }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se leerán los medicamentos de la receta para llenar el formulario.")
        }
        .photosPicker(isPresented: $mostrandoFotos, selection: $fotoReceta, matching: .images)
        .onChange(of: fotoReceta) { _, item in
            guard let item else { return }
            fotoReceta = nil
            Task { await leerFoto(item) }
        }
        .fullScreenCover(item: $fuenteCaptura) { fuente in
            CapturaRecetaView(fuente: fuente) { imagen in
                fuenteCaptura = nil
                if let imagen { Task { await transcribir(imagen) } }
            }
            .ignoresSafeArea()
        }
        .alert("No se pudo guardar", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Aceptar", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }
        .tint(MedicalStyle.red)
    }

    // MARK: - Receta

    private var seccionReceta: some View {
        Section {
            Button {
                mostrandoOpcionesReceta = true
            } label: {
                Label("Transcribir receta", systemImage: "doc.text.viewfinder")
                    .font(.app(.headline))
            }
            .disabled(receta.leyendo || isSaving)
            .accessibilityIdentifier("transcribirRecetaButton")
            .accessibilityHint("Escanea, toma una foto o elige una imagen de la receta para llenar el formulario")

            if receta.leyendo {
                ProgressView("Leyendo receta...")
            }

            if receta.guardadaEnDocumentos {
                Label("Foto guardada en Información médica › Documentos.", systemImage: "checkmark.circle.fill")
                    .font(.app(.footnote))
                    .foregroundStyle(Color.textoSuave)
            }

            if let error = receta.error {
                Text(error)
                    .font(.app(.footnote))
                    .foregroundStyle(MedicalStyle.red)
            }

            if receta.sinMedicamentos {
                Text("No se detectaron medicamentos. Puedes capturarlos manualmente.")
                    .font(.app(.footnote))
            }

            if !receta.candidatos.isEmpty {
                Text("Se detectaron varios medicamentos. Elige cuál quieres aplicar al formulario.")
                    .font(.app(.footnote))
                    .foregroundStyle(Color.textoSuave)
                ForEach(receta.candidatos.indices, id: \.self) { index in
                    candidato(receta.candidatos[index])
                }
            }

            if receta.aplicada {
                Label(mensajeAplicada, systemImage: "checkmark.circle.fill")
                    .font(.app(.footnote))
                    .foregroundStyle(Color.textoSuave)
            }
        } header: {
            Text("Receta médica")
        } footer: {
            Text("La receta se transcribe en el dispositivo. Revisa cada dato contra la receta antes de guardar.")
        }
    }

    private var mensajeAplicada: String {
        switch receta.metodo {
        case .reconocimientoTexto:
            "Formulario actualizado con el texto reconocido. Verifica cada dato con la receta y completa lo que falte."
        default:
            "Formulario actualizado. Revisa y completa los datos antes de guardar."
        }
    }

    private func candidato(_ medicamento: MedicamentoTranscrito) -> some View {
        let dosis = [medicamento.dosis, medicamento.unidad].compactMap { $0 }.joined(separator: " ")
        return Button {
            draft.aplicar(receta.elegir(medicamento))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(medicamento.nombre)
                    .font(.app(.headline))
                    .foregroundStyle(.primary)
                Text(dosis.isEmpty ? "Dosis no detectada" : dosis)
                    .foregroundStyle(Color.textoSuave)
                if let frecuencia = medicamento.frecuencia {
                    Text(frecuencia)
                        .foregroundStyle(Color.textoSuave)
                }
                Text("Usar este medicamento")
                    .font(.app(.footnote))
                    .foregroundStyle(MedicalStyle.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func leerFoto(_ item: PhotosPickerItem) async {
        guard let datos = try? await item.loadTransferable(type: Data.self),
              let imagen = UIImage(data: datos) else {
            receta.reportar(RecetaExtractorError.imagenInvalida.localizedDescription)
            return
        }
        await transcribir(imagen)
    }

    private func transcribir(_ imagen: UIImage) async {
        if let medicamento = await receta.transcribir(imagen, familiarID: recipientID) {
            draft.aplicar(medicamento)
        }
    }
}
