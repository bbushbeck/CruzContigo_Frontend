import Foundation

struct SugerenciaNotaFrida: Equatable {
    enum Detalle: String {
        case hora, duracion, lugar, observacion

        var pregunta: String {
            switch self {
            case .hora: "¿Quieres agregar a qué hora pasó?"
            case .duracion: "¿Cuánto duró?"
            case .lugar: "¿Dónde fue?"
            case .observacion: "¿Qué otro detalle te gustaría anotar?"
            }
        }
    }

    let esRelato: Bool
    let categoria: CategoriaNota?
    let detalle: Detalle?

    init(categoria: String, detalle: String, yaPreguntados: Set<Detalle>, esRelato: Bool = true) {
        self.esRelato = esRelato
        self.categoria = CategoriaNota(rawValue: categoria)
        self.detalle = Detalle(rawValue: detalle).flatMap { yaPreguntados.contains($0) ? nil : $0 }
    }

    var tieneContenido: Bool { categoria != nil || detalle != nil }
}

struct ConversacionNotaFrida {
    struct Turno: Identifiable {
        let detalle: SugerenciaNotaFrida.Detalle
        let respuesta: String

        var id: SugerenciaNotaFrida.Detalle { detalle }
    }

    private(set) var turnos: [Turno] = []
    var detallesPreguntados: Set<SugerenciaNotaFrida.Detalle> { Set(turnos.map(\.detalle)) }
    var puedeContinuar: Bool { turnos.count < 2 }

    func notaConRespuesta(_ respuesta: String, en nota: String) -> String? {
        let limpia = respuesta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpia.isEmpty else { return nil }
        let resultado = nota + "\n" + limpia
        return resultado.count <= SolicitudNota.largoMaximo ? resultado : nil
    }

    mutating func agregar(
        _ respuesta: String, a detalle: SugerenciaNotaFrida.Detalle, en nota: String
    ) -> String? {
        guard puedeContinuar, !detallesPreguntados.contains(detalle),
              let actualizada = notaConRespuesta(respuesta, en: nota) else { return nil }
        turnos.append(Turno(detalle: detalle, respuesta: respuesta.trimmingCharacters(in: .whitespacesAndNewlines)))
        return actualizada
    }
}

struct BorradorDiarioFrida {
    private(set) var nota: SolicitudNota
    private(set) var pregunta: SugerenciaNotaFrida.Detalle?
    private(set) var conversacion = ConversacionNotaFrida()

    init(texto: String, fecha: Date = .now) {
        nota = SolicitudNota(categoria: .otro, texto: texto, fecha: fecha)
    }

    mutating func aplicar(_ sugerencia: SugerenciaNotaFrida?) {
        if let categoria = sugerencia?.categoria { nota.categoria = categoria }
        pregunta = conversacion.puedeContinuar ? sugerencia?.detalle : nil
    }

    mutating func responder(_ texto: String) -> Bool {
        guard let pregunta,
              let actualizado = conversacion.agregar(texto, a: pregunta, en: nota.texto) else { return false }
        nota.texto = actualizado
        self.pregunta = nil
        return true
    }

    mutating func terminarPreguntas() {
        pregunta = nil
    }

    func sugerenciaLocal() -> SugerenciaNotaFrida {
        let palabras = Set(ConsultaFrida.palabras(nota.texto))
        let paseo = !palabras.isDisjoint(with: ["caminar", "camine", "camino", "caminamos", "paseo", "pasear", "paseamos"])
        let anteriores = conversacion.detallesPreguntados
        let opciones: [SugerenciaNotaFrida.Detalle] = paseo ? [.duracion, .lugar] : [.observacion]
        let siguiente = opciones.first { !anteriores.contains($0) }
        return SugerenciaNotaFrida(categoria: "", detalle: siguiente?.rawValue ?? "", yaPreguntados: anteriores)
    }

    // Los relatos habituales se pueden preparar incluso cuando el modelo no está disponible.
    static func esRelatoCotidiano(_ texto: String) -> Bool {
        guard !texto.contains("?") && !texto.contains("¿") else { return false }
        let palabras = ConsultaFrida.palabras(texto)
        var comienzo = palabras[...]
        if comienzo.first == "hoy" || comienzo.first == "ayer" { comienzo = comienzo.dropFirst() }
        if comienzo.first == "mi", comienzo.count > 2 { comienzo = comienzo.dropFirst(2) }
        if comienzo.starts(with: ["me", "senti"]) || comienzo.starts(with: ["me", "siento"]) {
            return comienzo.count > 2
        }
        let verbos: Set<String> = [
            "sali", "salimos", "salio", "camine", "caminamos", "camino",
            "fui", "fuimos", "fue", "dormi", "durmio", "comi", "comio",
            "desayune", "desayuno", "visite", "platique", "descanse", "descanso",
            "estuve", "estaba", "estuvo", "jugue", "jugamos", "tome", "pasamos"
        ]
        return comienzo.count > 1 && comienzo.first.map(verbos.contains) == true
    }

    static func quiereTerminar(_ texto: String) -> Bool {
        let frase = ConsultaFrida.palabras(texto).joined(separator: " ")
        return ["no", "no gracias", "gracias", "prefiero no decirlo", "eso es todo",
                "eso fue todo", "solo queria contarte", "no quiero decirlo", "no se", "no recuerdo",
                "no me acuerdo"].contains(frase)
    }
}
