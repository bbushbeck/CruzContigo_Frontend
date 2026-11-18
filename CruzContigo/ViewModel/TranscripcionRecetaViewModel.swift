//
//  TranscripcionRecetaViewModel.swift
//  CruzContigo
//

import Foundation
import Combine
import UIKit

/// Estado de la transcripción de una receta dentro del formulario de medicamento.
/// La vista decide qué hacer con el medicamento elegido (llenar su `MedicationDraft`).
@MainActor
final class TranscripcionRecetaViewModel: ObservableObject {
    @Published private(set) var leyendo = false
    @Published private(set) var candidatos: [MedicamentoTranscrito] = []
    @Published private(set) var sinMedicamentos = false
    @Published private(set) var aplicada = false
    @Published private(set) var guardadaEnDocumentos = false
    @Published private(set) var metodo: MetodoTranscripcion?
    @Published var error: String?

    private let transcriptor: any TranscriptorReceta
    private let guardarDocumento: (Data, UUID) throws -> Void

    /// Los valores por defecto se resuelven dentro del init para que corran en el actor principal.
    init(
        transcriptor: (any TranscriptorReceta)? = nil,
        guardarDocumento: ((Data, UUID) throws -> Void)? = nil
    ) {
        self.transcriptor = transcriptor ?? RecetaExtractor()
        self.guardarDocumento = guardarDocumento ?? { datos, familiarID in
            try DocumentosMedicosRepository.guardar(
                datos, titulo: "Receta médica", extensionArchivo: "jpg", tipo: .receta, familiarID: familiarID
            )
        }
    }

    /// Lee la receta. Si encuentra un solo medicamento lo devuelve para aplicarlo de inmediato;
    /// si encuentra varios, quedan en `candidatos` para que la persona elija.
    func transcribir(_ imagen: UIImage, familiarID: UUID) async -> MedicamentoTranscrito? {
        reiniciar()
        leyendo = true
        defer { leyendo = false }

        // Una copia de la receta queda en Información médica › Documentos.
        // Si no se puede guardar, la transcripción sigue adelante.
        if let datos = imagen.jpegData(compressionQuality: 0.85) {
            guardadaEnDocumentos = (try? guardarDocumento(datos, familiarID)) != nil
        }

        do {
            let receta = try await transcriptor.transcribir(imagen)
            metodo = receta.metodo
            switch receta.medicamentos.count {
            case 0:
                sinMedicamentos = true
                return nil
            case 1:
                aplicada = true
                return receta.medicamentos[0]
            default:
                candidatos = receta.medicamentos
                return nil
            }
        } catch {
            self.error = "No se pudo leer la receta: \(error.localizedDescription)"
            return nil
        }
    }

    /// Marca el candidato elegido como aplicado y lo devuelve.
    func elegir(_ medicamento: MedicamentoTranscrito) -> MedicamentoTranscrito {
        candidatos = []
        aplicada = true
        return medicamento
    }

    func reportar(_ mensaje: String) {
        reiniciar()
        error = mensaje
    }

    private func reiniciar() {
        error = nil
        candidatos = []
        sinMedicamentos = false
        aplicada = false
        guardadaEnDocumentos = false
        metodo = nil
    }
}
