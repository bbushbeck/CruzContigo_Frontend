//
//  MedicamentoTranscrito.swift
//  CruzContigo
//

import Foundation

/// Medicamento leído de una receta, sin importar cómo se transcribió
/// (Apple Intelligence o reconocimiento de texto en el dispositivo).
struct MedicamentoTranscrito: Equatable {
    var nombre: String
    var dosis: String?
    var unidad: String?
    var presentacion: String?
    var frecuencia: String?
    var duracionDias: Int?
    var indicacion: String?
}

/// Cómo se obtuvo la transcripción. Sirve para avisar qué tan confiable es.
enum MetodoTranscripcion: Equatable {
    /// Apple Intelligence leyó la imagen directamente (iOS 27+).
    case appleIntelligenceImagen
    /// Vision reconoció el texto y Apple Intelligence lo organizó (iOS 26+).
    case appleIntelligenceTexto
    /// Vision reconoció el texto y un analizador local lo organizó (cualquier dispositivo).
    case reconocimientoTexto
}

struct RecetaTranscrita: Equatable {
    var medicamentos: [MedicamentoTranscrito]
    var metodo: MetodoTranscripcion
}

extension MedicationDraft {
    /// Llena el formulario con lo que se leyó de la receta. Los campos que la receta
    /// no trae quedan vacíos para no mezclar datos de dos medicamentos.
    mutating func aplicar(_ medicamento: MedicamentoTranscrito) {
        name = Self.recortar(medicamento.nombre, maximo: 120)
        dose = Self.dosisNumerica(medicamento.dosis)
        unit = Self.recortar(medicamento.unidad, maximo: 10)
        presentation = Self.recortar(medicamento.presentacion, maximo: 60)
        frequency = Self.recortar(medicamento.frecuencia, maximo: 60)
        indication = Self.recortar(medicamento.indicacion, maximo: 2000)
        if let dias = medicamento.duracionDias, dias > 0,
           let fin = Calendar.current.date(byAdding: .day, value: dias - 1, to: startDate) {
            // "Por 7 días" empezando hoy termina el sexto día después de hoy (la fecha de fin es inclusiva).
            hasEndDate = true
            endDate = Calendar.current.startOfDay(for: fin)
        } else {
            hasEndDate = false
            endDate = startDate
        }
    }

    private static func recortar(_ texto: String?, maximo: Int) -> String {
        let limpio = (texto ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return String(limpio.prefix(maximo))
    }

    /// El formulario solo acepta números; si la receta dice "500 mg" o "1/2", toma el número.
    private static func dosisNumerica(_ texto: String?) -> String {
        let limpio = (texto ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rango = limpio.range(of: #"[0-9]+([.,][0-9]+)?"#, options: .regularExpression) else {
            return limpio
        }
        return String(limpio[rango])
    }
}
