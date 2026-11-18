//
//  RecetaExtractor.swift
//  CruzContigo
//
//  Created by Ricardo Gómez on 10/11/26.
//

import FoundationModels
import UIKit
import Vision

enum RecetaExtractorError: LocalizedError {
    case imagenInvalida
    case sinTexto

    var errorDescription: String? {
        switch self {
        case .imagenInvalida:
            "No se pudo abrir la fotografía seleccionada."
        case .sinTexto:
            "No se encontró texto en la imagen. Intenta con una foto más nítida y bien iluminada."
        }
    }
}

/// Transcribe una receta médica a medicamentos. Es un protocolo para poder probar el ViewModel.
protocol TranscriptorReceta {
    func transcribir(_ imagen: UIImage) async throws -> RecetaTranscrita
}

/// Transcriptor del sistema. Funciona desde iOS 26 y usa lo mejor que tenga el dispositivo:
/// 1. iOS 27 con Apple Intelligence: el modelo lee la imagen directamente.
/// 2. iOS 26 con Apple Intelligence: Vision reconoce el texto y el modelo lo organiza.
/// 3. Sin Apple Intelligence: Vision reconoce el texto y `RecetaTextoParser` lo organiza.
struct RecetaExtractor: TranscriptorReceta {
    func transcribir(_ imagen: UIImage) async throws -> RecetaTranscrita {
        guard let cgImage = imagen.preparadaParaLectura().cgImage else {
            throw RecetaExtractorError.imagenInvalida
        }
        let modeloDisponible = SystemLanguageModel.default.isAvailable

        if modeloDisponible, #available(iOS 27.0, *),
           let receta = try? await Self.extraerConModelo(imagen: cgImage),
           !receta.medicamentos.isEmpty {
            return RecetaTranscrita(medicamentos: receta.medicamentos.map(\.transcrito), metodo: .appleIntelligenceImagen)
        }

        let lineas = try await Self.reconocerTexto(en: cgImage)
        guard !lineas.isEmpty else { throw RecetaExtractorError.sinTexto }

        if modeloDisponible,
           let receta = try? await Self.extraerConModelo(texto: lineas.joined(separator: "\n")),
           !receta.medicamentos.isEmpty {
            return RecetaTranscrita(medicamentos: receta.medicamentos.map(\.transcrito), metodo: .appleIntelligenceTexto)
        }

        return RecetaTranscrita(medicamentos: RecetaTextoParser.medicamentos(en: lineas), metodo: .reconocimientoTexto)
    }

    // MARK: - Vision (iOS 18+)

    /// Reconoce el texto de la imagen, línea por línea y en orden de lectura.
    static func reconocerTexto(en imagen: CGImage) async throws -> [String] {
        var solicitud = RecognizeTextRequest()
        solicitud.recognitionLevel = .accurate
        solicitud.usesLanguageCorrection = true
        solicitud.recognitionLanguages = [
            Locale.Language(identifier: "es-MX"),
            Locale.Language(identifier: "es-ES"),
            Locale.Language(identifier: "en-US"),
        ]
        let observaciones = try await solicitud.perform(on: imagen)
        return observaciones.compactMap { $0.topCandidates(1).first?.string }
    }

    // MARK: - Foundation Models

    private static let instrucciones = """
        Extraes información de recetas médicas.

        Reglas:
        - Extrae únicamente información escrita en la receta.
        - No inventes, corrijas ni recomiendes medicamentos o dosis.
        - No calcules tratamientos ni fechas.
        - Si un dato no está claro, devuélvelo como nil.
        - Separa la cantidad de dosis de su unidad.
        - No confundas datos del paciente o del médico con medicamentos.
        """

    /// iOS 27+: el modelo recibe la imagen.
    @available(iOS 27.0, *)
    private static func extraerConModelo(imagen: CGImage) async throws -> RecetaExtraida {
        let session = LanguageModelSession(instructions: instrucciones)
        let response = try await session.respond(generating: RecetaExtraida.self) {
            "Lee esta receta y extrae todos sus medicamentos."
            Attachment(imagen)
        }
        return response.content
    }

    /// iOS 26+: el modelo recibe el texto que reconoció Vision.
    private static func extraerConModelo(texto: String) async throws -> RecetaExtraida {
        let session = LanguageModelSession(instructions: instrucciones)
        let response = try await session.respond(
            to: """
            Este es el texto reconocido en la foto de una receta médica, línea por línea. \
            Puede tener errores de reconocimiento. Extrae todos sus medicamentos.

            \(texto)
            """,
            generating: RecetaExtraida.self
        )
        return response.content
    }
}

private extension UIImage {
    /// Corrige la orientación de las fotos de cámara y limita el tamaño para leerlas más rápido.
    func preparadaParaLectura(ladoMaximo: CGFloat = 2400) -> UIImage {
        let escala = min(1, ladoMaximo / max(size.width, size.height))
        guard imageOrientation != .up || escala < 1 else { return self }
        let destino = CGSize(width: size.width * escala, height: size.height * escala)
        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        return UIGraphicsImageRenderer(size: destino, format: formato).image { _ in
            draw(in: CGRect(origin: .zero, size: destino))
        }
    }
}
