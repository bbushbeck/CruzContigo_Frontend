// ClasificadorRecordatorios.swift
// CruzContigo — HU-06: sugerencia de categoría por similitud semántica.
// Utiliza el modelo de embeddings de oraciones de Apple NaturalLanguage.
// El resultado es orientativo y siempre puede corregirlo el cuidador.

import Foundation
import NaturalLanguage

enum CategoriaRecordatorio: String, Codable, CaseIterable, Identifiable {
    case medicamento
    case citaMedica
    case actividadDeCuidado
    case general

    var id: Self { self }

    var nombre: String {
        switch self {
        case .medicamento: "Medicamento"
        case .citaMedica: "Cita médica"
        case .actividadDeCuidado: "Actividad de cuidado"
        case .general: "General"
        }
    }
}

struct ResultadoClasificacion {
    enum Estado {
        case clasificado
        case sinTexto
        case modeloNoDisponible
        case pocoClaro
    }

    let categoria: CategoriaRecordatorio
    let estado: Estado
    let distancia: Double?

    var mensaje: String {
        switch estado {
        case .clasificado:
            return "Categoría sugerida: \(categoria.nombre). Puedes cambiarla."
        case .sinTexto:
            return "Escribe primero el nombre del recordatorio."
        case .modeloNoDisponible:
            return "El modelo de lenguaje no está disponible en este dispositivo. Elige una categoría manualmente."
        case .pocoClaro:
            return "No se encontró una categoría clara. Selecciona una manualmente."
        }
    }
}

struct ClasificadorRecordatorios {
    // Ejemplos de referencia, no un árbol de reglas ni una lista de palabras clave.
    // NLEmbedding compara el significado de oraciones mediante un modelo entrenado.
    private static let ejemplos: [(CategoriaRecordatorio, String)] = [
        (.medicamento, "Dar la medicina recetada por el doctor"),
        (.medicamento, "Administrar las pastillas a mi familiar"),
        (.medicamento, "Tomar el tratamiento diario a la hora indicada"),
        (.medicamento, "Recordar la dosis del medicamento de la noche"),

        (.citaMedica, "Llevar a mi familiar a consulta con el doctor"),
        (.citaMedica, "Ir a la cita médica en el hospital"),
        (.citaMedica, "Acudir a revisión con el especialista"),
        (.citaMedica, "Asistir a la consulta de cardiología"),

        (.actividadDeCuidado, "Ayudar a mi familiar a desayunar"),
        (.actividadDeCuidado, "Acompañar a la persona a bañarse"),
        (.actividadDeCuidado, "Preparar la comida de la persona que cuido"),
        (.actividadDeCuidado, "Apoyar a mi familiar para caminar"),

        (.general, "Comprar artículos de limpieza"),
        (.general, "Llamar a un amigo por teléfono"),
        (.general, "Revisar documentos personales"),
        (.general, "Organizar una reunión familiar")
    ]

    static func clasificar(_ titulo: String) -> ResultadoClasificacion {
        let texto = titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty else {
            return .init(categoria: .general, estado: .sinTexto, distancia: nil)
        }

        // API de ML local de Apple. Si no hay modelo de español, no se simula IA.
        guard let modelo = NLEmbedding.sentenceEmbedding(for: .spanish),
              modelo.vector(for: texto) != nil else {
            return .init(categoria: .general, estado: .modeloNoDisponible, distancia: nil)
        }

        var mejorCategoria: CategoriaRecordatorio = .general
        var menorDistancia = Double.infinity

        for (categoria, ejemplo) in ejemplos {
            let distancia = modelo.distance(between: texto, and: ejemplo, distanceType: .cosine)
            if distancia.isFinite && distancia < menorDistancia {
                menorDistancia = distancia
                mejorCategoria = categoria
            }
        }

        guard menorDistancia.isFinite else {
            return .init(categoria: .general, estado: .pocoClaro, distancia: nil)
        }

        // Umbral conservador inicial; calibrarlo con pruebas del equipo.
        if menorDistancia > 0.75 {
            return .init(categoria: .general, estado: .pocoClaro, distancia: menorDistancia)
        }

        return .init(categoria: mejorCategoria, estado: .clasificado, distancia: menorDistancia)
    }
}
