import Foundation

struct SugerenciaNotaFrida: Equatable {
    enum Detalle: String {
        case hora, duracion, lugar, quePaso, comoSeSintio, queAyudo

        var pregunta: String {
            switch self {
            case .hora: "¿A qué hora pasó?"
            case .duracion: "¿Cuánto duró?"
            case .lugar: "¿Dónde fue?"
            case .quePaso: "¿Qué pasó?"
            case .comoSeSintio: "¿Cómo te sentiste en ese momento?"
            case .queAyudo: "¿Hubo algo que te ayudó ese día?"
            }
        }
    }

    enum Tono: String {
        case dificil, alegre, neutral

        var respuesta: String {
            switch self {
            case .dificil: "Suena a que fue un día pesado."
            case .alegre: "Qué gusto que hayas tenido ese momento."
            case .neutral: "Te leo."
            }
        }
    }

    let esRelato: Bool
    let categoria: CategoriaNota?
    let detalle: Detalle?
    let tono: Tono

    init(categoria: String, detalle: String, tono: String, yaPreguntados: Set<Detalle>, esRelato: Bool = true) {
        self.esRelato = esRelato
        self.categoria = CategoriaNota(rawValue: categoria)
        self.detalle = Detalle(rawValue: detalle).flatMap { yaPreguntados.contains($0) ? nil : $0 }
        self.tono = Tono(rawValue: tono) ?? .neutral
    }
}

struct BorradorDiarioFrida {
    private(set) var nota: SolicitudNota
    private(set) var intervenciones = 1
    private(set) var detallesPreguntados: Set<SugerenciaNotaFrida.Detalle> = []
    private(set) var muestraOferta = false
    private var ofrecioResumen = false

    init(texto: String, fecha: Date = .now) {
        nota = SolicitudNota(categoria: .otro, texto: texto, fecha: fecha)
    }

    mutating func agregar(_ texto: String) -> Bool {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return false }
        let actualizado = nota.texto + "\n" + limpio
        guard actualizado.count <= SolicitudNota.largoMaximo else { return false }
        nota.texto = actualizado
        intervenciones += 1
        return true
    }

    mutating func elegirPregunta(_ sugerencia: SugerenciaNotaFrida) -> SugerenciaNotaFrida.Detalle? {
        if let categoria = sugerencia.categoria { nota.categoria = categoria }
        guard let detalle = sugerencia.detalle, detallesPreguntados.insert(detalle).inserted else { return nil }
        return detalle
    }

    mutating func ofrecerResumen(alCerrar: Bool = false) -> Bool {
        guard !ofrecioResumen, alCerrar || intervenciones >= 3 else { return false }
        ofrecioResumen = true
        muestraOferta = true
        return true
    }

    mutating func descartarOferta() {
        muestraOferta = false
    }

    func notaParaRevision(resumen: String?) -> SolicitudNota {
        var propuesta = nota
        let limpio = resumen?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !limpio.isEmpty, limpio.count <= SolicitudNota.largoMaximo {
            propuesta.texto = limpio
        }
        return propuesta
    }

    func sugerenciaLocal(ultimoMensaje: String) -> SugerenciaNotaFrida {
        let palabras = Set(ConsultaFrida.palabras(nota.texto))
        let ultimas = Set(ConsultaFrida.palabras(ultimoMensaje))
        let paseo = !palabras.isDisjoint(with: ["caminar", "camine", "camino", "caminamos", "paseo", "pasear", "paseamos"])
        let dificil = !ultimas.isDisjoint(with: ["dificil", "pesado", "complicado", "triste", "sola", "solo", "dificiles"])
        let temas: [SugerenciaNotaFrida.Detalle]
        if paseo {
            temas = [.duracion, .lugar, .comoSeSintio]
        } else if dificil {
            temas = [.quePaso, .queAyudo, .comoSeSintio]
        } else {
            temas = [.quePaso, .comoSeSintio, .queAyudo]
        }
        let siguiente = temas.first { !detallesPreguntados.contains($0) }
        return SugerenciaNotaFrida(
            categoria: "", detalle: siguiente?.rawValue ?? "",
            tono: dificil ? "dificil" : "neutral", yaPreguntados: detallesPreguntados
        )
    }

    static func esRelatoCotidiano(_ texto: String) -> Bool {
        guard !texto.contains("?") && !texto.contains("¿") else { return false }
        var comienzo = ConsultaFrida.palabras(texto)[...]
        for llamada in [["ay", "frida"], ["oye", "frida"], ["frida"]] where comienzo.starts(with: llamada) {
            comienzo = comienzo.dropFirst(llamada.count)
            break
        }
        if comienzo.first == "hoy" || comienzo.first == "ayer" { comienzo = comienzo.dropFirst() }
        if comienzo.first == "mi", comienzo.count > 2 { comienzo = comienzo.dropFirst(2) }
        if comienzo.starts(with: ["me", "senti"]) || comienzo.starts(with: ["me", "siento"]) {
            return comienzo.count > 2
        }
        let verbos: Set<String> = [
            "tuve", "tuvimos", "tuvo", "sali", "salimos", "salio", "camine", "caminamos", "camino",
            "fui", "fuimos", "fue", "dormi", "durmio", "comi", "comio",
            "desayune", "desayuno", "visite", "platique", "descanse", "descanso",
            "estuve", "estaba", "estuvo", "jugue", "jugamos", "tome", "pasamos"
        ]
        return comienzo.count > 1 && comienzo.first.map(verbos.contains) == true
    }

    static func esConsultaExplicita(_ texto: String) -> Bool {
        if texto.contains("?") || texto.contains("¿") { return true }
        let palabras = ConsultaFrida.palabras(texto)
        guard let primera = palabras.first else { return false }
        return ["abre", "abreme", "muestrame", "dime", "llevame", "que", "cuando", "cual", "cuales"].contains(primera)
            || palabras.starts(with: ["quiero", "ver"]) || palabras.starts(with: ["a", "quien"])
    }

    static func pideGuardar(_ texto: String) -> Bool {
        let palabras = ConsultaFrida.palabras(texto).drop(while: { $0 == "frida" })
        let pide = palabras.first.map { ["guarda", "guardar", "guardalo", "guardame", "revisa", "revisar"].contains($0) } == true
            || palabras.starts(with: ["quiero", "guardar"])
        return palabras.elementsEqual(["guardalo"]) || (pide && palabras.contains { ["nota", "notas", "diario", "esto", "relato", "resumen"].contains($0) })
    }

    static func quiereCerrar(_ texto: String) -> Bool {
        let frase = ConsultaFrida.palabras(texto).joined(separator: " ")
        return ["eso es todo", "eso fue todo", "solo queria contarte", "gracias por escuchar",
                "eso era lo que queria contar", "ya te conte todo"].contains(frase)
    }

    static func quiereOmitir(_ texto: String) -> Bool {
        let frase = ConsultaFrida.palabras(texto).joined(separator: " ")
        return ["no", "no gracias", "gracias", "prefiero no decirlo", "no quiero decirlo",
                "no quiero guardarlo", "no lo guardes", "no se", "no recuerdo", "no me acuerdo"].contains(frase)
    }
}
