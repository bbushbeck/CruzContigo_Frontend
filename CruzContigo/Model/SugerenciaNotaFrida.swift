import Foundation

struct SugerenciaNotaFrida: Equatable {
    enum Detalle: String {
        case hora, duracion, lugar, quePaso, comoSeSintio, queAyudo, quePesa, desdeCuando

        var pregunta: String {
            switch self {
            case .hora: "¿A qué hora pasó?"
            case .duracion: "¿Cuánto duró?"
            case .lugar: "¿Dónde fue?"
            case .quePaso: "¿Qué pasó?"
            case .comoSeSintio: "¿Cómo te sentiste en ese momento?"
            case .queAyudo: "¿Hubo algo que te ayudó ese día?"
            case .quePesa: "¿Qué es lo que más te preocupa ahora?"
            case .desdeCuando: "¿Desde cuándo lo has notado?"
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

    enum TemaEscucha: String {
        case dinero, alimentacion, familia, responsabilidades, soledad, ninguno

        var respuesta: String? {
            switch self {
            case .dinero: "La preocupación por el dinero puede pesar mucho."
            case .alimentacion: "Entiendo que te preocupe cómo ha estado comiendo."
            case .familia: "Te leo. Esto que cuentas sobre tu familia importa."
            case .responsabilidades: "Suena a que traes varias cosas encima."
            case .soledad: "Gracias por contarme cómo te has sentido."
            case .ninguno: nil
            }
        }

        static func reconocer(_ texto: String) -> TemaEscucha {
            let textoNormalizado = ConsultaFrida.palabras(texto)
            let palabras = Set(textoNormalizado)
            if !palabras.isDisjoint(with: ["dinero", "deuda", "deudas", "deaudas", "pagar", "renta", "gastarlo", "gastamos"]) {
                return .dinero
            }
            if faltaApetito(textoNormalizado) { return .alimentacion }
            if !palabras.isDisjoint(with: ["soledad", "acompanado", "acompanada"])
                || ConsultaFrida.contiene("me siento sola", en: textoNormalizado)
                || ConsultaFrida.contiene("me siento solo", en: textoNormalizado) {
                return .soledad
            }
            if !palabras.isDisjoint(with: ["familia", "hijos", "hijas", "hijo", "hija"]) {
                return .familia
            }
            if !palabras.isDisjoint(with: ["pendientes", "responsabilidades", "trabajo", "tareas"]) {
                return .responsabilidades
            }
            return .ninguno
        }

        static func faltaApetito(_ palabras: [String]) -> Bool {
            ["no se le antoja", "no le da hambre", "no tiene apetito", "no tiene antojo",
             "no ha comido bien", "no come bien", "ha comido poco", "esta comiendo poco",
             "perdio el apetito"].contains { ConsultaFrida.contiene($0, en: palabras) }
        }
    }

    let esRelato: Bool
    let categoria: CategoriaNota?
    let detalle: Detalle?
    let tono: Tono
    let temaEscucha: TemaEscucha

    init(
        categoria: String, detalle: String, tono: String, yaPreguntados: Set<Detalle>,
        esRelato: Bool = true, temaEscucha: String = ""
    ) {
        self.esRelato = esRelato
        self.categoria = CategoriaNota(rawValue: categoria)
        self.detalle = Detalle(rawValue: detalle).flatMap { yaPreguntados.contains($0) ? nil : $0 }
        self.tono = Tono(rawValue: tono) ?? .neutral
        self.temaEscucha = TemaEscucha(rawValue: temaEscucha) ?? .ninguno
    }

    func convieneSeguirEscuchando(_ ultimoMensaje: String) -> Bool {
        let temaLocal = TemaEscucha.reconocer(ultimoMensaje)
        return tono == .dificil || [.dinero, .soledad, .alimentacion].contains(temaLocal)
    }

    func respuesta(para ultimoMensaje: String) -> String {
        let temaLocal = TemaEscucha.reconocer(ultimoMensaje)
        let palabras = ConsultaFrida.palabras(ultimoMensaje)
        let deudasPropias = ["tengo deudas", "tengo muchas deudas", "tenia muchas deudas", "me endeude"].contains {
            ConsultaFrida.contiene($0, en: palabras)
        }
        if temaLocal == .dinero, deudasPropias,
           ConsultaFrida.contiene("por los medicamentos de mi mama", en: palabras) {
            return "Lidiar con las deudas por los medicamentos de tu mamá suena pesado."
        }
        return temaLocal.respuesta ?? temaEscucha.respuesta ?? tono.respuesta
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

    mutating func elegirPregunta(
        _ sugerencia: SugerenciaNotaFrida, ultimoMensaje: String = ""
    ) -> SugerenciaNotaFrida.Detalle? {
        let tema = SugerenciaNotaFrida.TemaEscucha.reconocer(ultimoMensaje)
        if tema == .alimentacion, nota.categoria == .otro {
            nota.categoria = .alimentacion
        } else if let categoria = sugerencia.categoria {
            nota.categoria = categoria
        }

        let detalle: SugerenciaNotaFrida.Detalle?
        if tema == .alimentacion {
            let relato = ConsultaFrida.palabras(nota.texto)
            let yaDijoCuando = ["desde", "hace", "lleva", "llevaba"].contains { relato.contains($0) }
            let posibilidades: [SugerenciaNotaFrida.Detalle] = yaDijoCuando ? [.quePesa] : [.desdeCuando, .quePesa]
            detalle = posibilidades.first { !detallesPreguntados.contains($0) }
        } else {
            detalle = sugerencia.detalle
        }
        guard let detalle, detallesPreguntados.insert(detalle).inserted else { return nil }
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

    var fragmentos: FragmentosRelatoFrida { FragmentosRelatoFrida(nota.texto) }

    func notaParaRevision(seleccion: [Int]?) -> SolicitudNota {
        var propuesta = nota
        let resumen = fragmentos.resumen(seleccion: seleccion)
        if !resumen.isEmpty, resumen.count <= SolicitudNota.largoMaximo {
            propuesta.texto = resumen
        }
        return propuesta
    }

    func sugerenciaLocal(ultimoMensaje: String) -> SugerenciaNotaFrida {
        let palabras = Set(ConsultaFrida.palabras(nota.texto))
        let ultimas = Set(ConsultaFrida.palabras(ultimoMensaje))
        let paseo = !palabras.isDisjoint(with: ["caminar", "camine", "camino", "caminamos", "paseo", "pasear", "paseamos"])
        let tema = SugerenciaNotaFrida.TemaEscucha.reconocer(ultimoMensaje)
        let dificil = !ultimas.isDisjoint(with: ["dificil", "pesado", "complicado", "triste", "sola", "solo", "dificiles"])
        let temas: [SugerenciaNotaFrida.Detalle]
        if paseo {
            temas = [.duracion, .lugar, .comoSeSintio]
        } else if tema == .dinero || tema == .responsabilidades {
            temas = [.quePesa, .queAyudo, .comoSeSintio]
        } else if dificil {
            temas = [.quePaso, .queAyudo, .comoSeSintio]
        } else {
            temas = [.quePaso, .comoSeSintio, .queAyudo]
        }
        let siguiente = temas.first { !detallesPreguntados.contains($0) }
        return SugerenciaNotaFrida(
            categoria: "", detalle: siguiente?.rawValue ?? "",
            tono: dificil ? "dificil" : "neutral", yaPreguntados: detallesPreguntados,
            temaEscucha: tema.rawValue
        )
    }

    static func esRelatoCotidiano(_ texto: String) -> Bool {
        guard !texto.contains("?") && !texto.contains("¿") else { return false }
        var comienzo = ConsultaFrida.palabras(FragmentosRelatoFrida.sinVocativo(texto))[...]
        if comienzo.first == "hoy" || comienzo.first == "ayer" { comienzo = comienzo.dropFirst() }
        if comienzo.first == "mi", comienzo.count > 2 { comienzo = comienzo.dropFirst(2) }
        if comienzo.starts(with: ["me", "senti"]) || comienzo.starts(with: ["me", "siento"]) {
            return comienzo.count > 2
        }
        if comienzo.first == "tengo", SugerenciaNotaFrida.TemaEscucha.reconocer(texto) == .dinero {
            return true
        }
        if SugerenciaNotaFrida.TemaEscucha.faltaApetito(Array(comienzo)) {
            return true
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
        let palabras = ConsultaFrida.palabras(texto).drop(while: { ["frida", "oye"].contains($0) })
        guard let primera = palabras.first else { return false }
        return ["abre", "abreme", "muestrame", "dime", "llevame", "ver", "consulta", "consultar",
                "puedes", "podrias", "que", "cuando", "cual", "cuales", "donde", "quien"].contains(primera)
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
