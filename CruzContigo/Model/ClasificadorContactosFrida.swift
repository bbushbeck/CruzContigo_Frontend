#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// Detecta solicitudes indirectas de contactos con similitud semántica de oraciones en español.
enum ClasificadorContactosFrida {
    private static let contactos = [
        "a quién puedo avisarle si le pasa algo a mi familiar",
        "a quién puedo llamar en caso de emergencia",
        "necesito el teléfono de una persona que pueda ayudar a mi familiar",
        "quiero comunicarme con alguien cercano al familiar si necesita ayuda",
        "muéstrame los números guardados para una emergencia",
    ]

    private static let otrasConsultas = [
        "cómo registro el teléfono de un familiar",
        "quiero llamar a mi familiar para saludar",
        "quiero invitar a alguien a la red de cuidado",
        "tengo una pregunta sobre la salud de mi familiar",
        "qué debo hacer en una emergencia médica",
        "necesito ayuda urgente ahora mismo",
        "quiero agendar una cita con el doctor",
        "qué medicamentos y recordatorios tengo hoy",
        "quiero escribir una nota en el diario",
        "mi familiar está en peligro",
        "mi familiar necesita ayuda"
    ]

    #if canImport(NaturalLanguage)
    private static let modelo = NLEmbedding.sentenceEmbedding(for: .spanish)
    #endif

    static func reconoce(_ texto: String) -> Bool {
        #if canImport(NaturalLanguage)
        guard texto.count <= 256, let modelo, modelo.vector(for: texto) != nil else { return false }
        return reconoce { ejemplo in
            modelo.distance(between: texto, and: ejemplo, distanceType: .cosine)
        }
        #else
        return false
        #endif
    }

    /// Se requiere cercanía con una intención de contactos y separación de las demás.
    /// Las distancias son coseno, donde cero representa mayor similitud.
    static func reconoce(distancia: (String) -> Double) -> Bool {
        guard let cercana = contactos.map(distancia).filter(\.isFinite).min(),
              let otra = otrasConsultas.map(distancia).filter(\.isFinite).min() else {
            return false
        }
        return cercana <= 0.8 && otra - cercana >= 0.08
    }
}
