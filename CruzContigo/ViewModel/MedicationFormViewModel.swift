import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class MedicationFormViewModel {
    let recipientID: UUID
    let editing: Medication?
    var draft: MedicationDraft
    var isSaving = false
    var saveError: String?
    var recetaSelection: PhotosPickerItem?
    var recetaExtraida: RecetaExtraida?
    var isReadingReceta = false
    var recetaError: String?
    var recetaAplicada = false
    var recetaGuardada = false

    private let model: MedicationViewModel

    init(recipientID: UUID, model: MedicationViewModel, editing: Medication? = nil) {
        self.recipientID = recipientID
        self.model = model
        self.editing = editing
        draft = editing.map(MedicationDraft.init(medication:)) ?? MedicationDraft()
    }

    func guardar() async -> Bool {
        guard draft.isValid, !isSaving, !isReadingReceta else { return false }
        let medication = draft.medication(id: editing?.id ?? UUID(), recipientID: recipientID)
        isSaving = true
        defer { isSaving = false }
        let error = await model.save(medication, updating: editing != nil)
        saveError = error
        return error == nil
    }

    @available(iOS 27.0, *)
    func leerReceta(_ item: PhotosPickerItem) async {
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

    func aplicar(_ medicamento: MedicamentoExtraido) {
        draft.aplicar(medicamento)
        recetaExtraida = nil
        recetaAplicada = true
    }
}
