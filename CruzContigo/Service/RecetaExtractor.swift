//
//  RecetaExtractor.swift
//  CruzContigo
//
//  Created by Ricardo Gómez on 10/11/26.
//

import FoundationModels
import UIKit

enum RecetaExtractorError: LocalizedError {
    case imagenInvalida
    case modeloNoDisponible

    var errorDescription: String? {
        switch self {
        case .imagenInvalida:
            "No se pudo abrir la fotografía seleccionada."
        case .modeloNoDisponible:
            "Apple Intelligence no está disponible en este dispositivo. Puedes capturar el medicamento manualmente."
        }
    }
}

@available(iOS 27.0, *)
struct RecetaExtractor {
    func extraer(desde imagen: UIImage) async throws -> RecetaExtraida {
        guard case .available = SystemLanguageModel.default.availability else {
            throw RecetaExtractorError.modeloNoDisponible
        }
        guard let cgImage = imagen.cgImage else {
            throw RecetaExtractorError.imagenInvalida
        }

        let session = LanguageModelSession(
            instructions: """
            Extraes información de recetas médicas fotografiadas.

            Reglas:
            - Extrae únicamente información visible en la imagen.
            - No inventes, corrijas ni recomiendes medicamentos o dosis.
            - No calcules tratamientos ni fechas.
            - Si un dato no está claro, devuélvelo como nil.
            - Separa la cantidad de dosis de su unidad.
            - No confundas datos del paciente o del médico con medicamentos.
            """
        )

        let response = try await session.respond(
            generating: RecetaExtraida.self
        ) {
            "Lee esta receta y extrae todos sus medicamentos."
            Attachment(cgImage)
        }

        return response.content
    }
}
