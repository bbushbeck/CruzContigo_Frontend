import Foundation
#if canImport(FoundationModels)
import FoundationModels

@Generable
nonisolated struct OrientacionDelModeloFrida {
    @Guide(description: "Categoría del relato: alimentacion, sueno, animo, incidencia, otro o ninguno.")
    var categoria: String

    @Guide(description: "Un detalle nuevo que valga la pena preguntar: hora, duracion, lugar, quePaso, comoSeSintio, queAyudo, quePesa, desdeCuando o ninguno.")
    var detalle: String

    @Guide(description: "Tono del último mensaje: dificil, alegre o neutral.")
    var tono: String

    @Guide(description: "Tema del último mensaje: dinero, alimentacion, familia, responsabilidades, soledad o ninguno.")
    var tema: String

    @Guide(description: "Cómo continuar: reconocerDetalle si precisó algo, reconocerPreocupacion si expresó preocupación o darEspacio si prefiere seguir hablando. Usa normal en otros casos.")
    var enfoque: String
}
#endif

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
            case .dinero: "Lamento que te estés sintiendo así."
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
             "no ha comido bien", "no ha estado comiendo bien", "no esta comiendo bien",
             "no come bien", "ha comido poco", "esta comiendo poco",
             "perdio el apetito"].contains { ConsultaFrida.contiene($0, en: palabras) }
        }
    }

    enum Enfoque: String {
        case normal, reconocerDetalle, reconocerPreocupacion, darEspacio
    }

    let esRelato: Bool
    let categoria: CategoriaNota?
    let detalle: Detalle?
    let tono: Tono
    let temaEscucha: TemaEscucha
    let enfoque: Enfoque

    init(
        categoria: String, detalle: String, tono: String, yaPreguntados: Set<Detalle>,
        esRelato: Bool = true, temaEscucha: String = "", enfoque: String = ""
    ) {
        self.esRelato = esRelato
        self.categoria = CategoriaNota(rawValue: categoria)
        self.detalle = Detalle(rawValue: detalle).flatMap { yaPreguntados.contains($0) ? nil : $0 }
        self.tono = Tono(rawValue: tono) ?? .neutral
        self.temaEscucha = TemaEscucha(rawValue: temaEscucha) ?? .ninguno
        self.enfoque = Enfoque(rawValue: enfoque) ?? .normal
    }

    #if canImport(FoundationModels)
    init(_ respuesta: OrientacionDelModeloFrida, detallesCubiertos: Set<Detalle>, esRelato: Bool) {
        self.init(
            categoria: respuesta.categoria, detalle: respuesta.detalle, tono: respuesta.tono,
            yaPreguntados: detallesCubiertos, esRelato: esRelato, temaEscucha: respuesta.tema,
            enfoque: respuesta.enfoque
        )
    }
    #endif

    func convieneSeguirEscuchando(_ ultimoMensaje: String) -> Bool {
        let temaLocal = TemaEscucha.reconocer(ultimoMensaje)
        return tono == .dificil || enfoque != .normal || [.dinero, .soledad, .alimentacion].contains(temaLocal)
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

    func respuestas(para texto: String, categoria: CategoriaNota) -> [String] {
        let palabras = ConsultaFrida.palabras(texto)
        var opciones: [String] = []
        if categoria == .alimentacion, ConsultaFrida.contiene("ultima semana", en: palabras),
           enfoque != .darEspacio, enfoque != .reconocerPreocupacion {
            opciones.append("Por lo que cuentas, lo has notado durante la última semana.")
        }
        if Self.TemaEscucha.faltaApetito(palabras), ConsultaFrida.contiene("me preocupa", en: palabras),
           enfoque != .darEspacio {
            opciones.append("Entiendo que te inquiete que no se le antoje comer.")
        }
        switch enfoque {
        case .reconocerDetalle: opciones.append("Gracias por aclararme ese detalle.")
        case .reconocerPreocupacion: opciones.append(respuesta(para: texto))
        case .darEspacio: opciones.append("Tómate tu tiempo. Te sigo leyendo.")
        case .normal: break
        }
        return opciones + [respuesta(para: texto), "Te sigo leyendo.", "Gracias por contarme esa parte.",
                           "Puedes contarme más, a tu ritmo."]
    }
}

struct BorradorDiarioFrida {
    private(set) var nota: SolicitudNota
    private(set) var intervenciones = 1
    private(set) var detallesPreguntados: Set<SugerenciaNotaFrida.Detalle> = []
    private(set) var respuestasDadas: [String] = []
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

    mutating func actualizarCategoria(_ sugerencia: SugerenciaNotaFrida, ultimoMensaje: String) {
        if SugerenciaNotaFrida.TemaEscucha.reconocer(ultimoMensaje) == .alimentacion {
            nota.categoria = .alimentacion
        } else if let categoria = sugerencia.categoria, categoria != .otro || nota.categoria == .otro {
            nota.categoria = categoria
        }
    }

    var detallesCubiertos: Set<SugerenciaNotaFrida.Detalle> {
        var cubiertos = detallesPreguntados
        let palabras = ConsultaFrida.palabras(nota.texto)
        let tiempos = ["esta semana", "ultima semana", "semana pasada", "desde ayer", "desde hoy",
                       "desde el", "desde la", "desde hace", "lleva una", "lleva un", "hace dias",
                       "hace semanas", "hace una semana", "hace unos dias", "desde anoche"]
        if tiempos.contains(where: { ConsultaFrida.contiene($0, en: palabras) }) {
            cubiertos.insert(.desdeCuando)
        }
        if ["minuto", "minutos", "media hora", "una hora", "dos horas"].contains(where: {
            ConsultaFrida.contiene($0, en: palabras)
        }) {
            cubiertos.insert(.duracion)
        }
        if ConsultaFrida.contiene("me preocupa que", en: palabras)
            || (nota.categoria == .alimentacion && ConsultaFrida.contiene("me preocupa", en: palabras)) {
            cubiertos.insert(.quePesa)
        }
        return cubiertos
    }

    mutating func elegirPregunta(
        _ sugerencia: SugerenciaNotaFrida, ultimoMensaje: String = "", sugeridaPorModelo: Bool = false
    ) -> SugerenciaNotaFrida.Detalle? {
        actualizarCategoria(sugerencia, ultimoMensaje: ultimoMensaje)
        let cubiertos = detallesCubiertos
        guard sugerencia.enfoque != .darEspacio else { return nil }
        let candidatos: [SugerenciaNotaFrida.Detalle]
        if nota.categoria == .alimentacion {
            let pertinentes: Set<SugerenciaNotaFrida.Detalle> = [.desdeCuando, .quePesa]
            let local = SugerenciaNotaFrida.TemaEscucha.reconocer(ultimoMensaje)
            if sugeridaPorModelo || local != .alimentacion {
                candidatos = [sugerencia.detalle].compactMap { $0 }.filter(pertinentes.contains)
            } else {
                candidatos = [.desdeCuando, .quePesa]
            }
        } else {
            candidatos = [sugerencia.detalle].compactMap { $0 }
        }
        guard let detalle = candidatos.first(where: { !cubiertos.contains($0) }) else { return nil }
        detallesPreguntados.insert(detalle)
        return detalle
    }

    mutating func responder(
        _ sugerencia: SugerenciaNotaFrida, texto: String, pregunta: SugerenciaNotaFrida.Detalle?
    ) -> String {
        let opciones = sugerencia.respuestas(para: texto, categoria: nota.categoria)
        let reflexion = opciones.first { !respuestasDadas.contains($0) }
            ?? (pregunta == nil ? opciones.first { !respuestasDadas.suffix(3).contains($0) } : nil)
        if let reflexion { respuestasDadas.append(reflexion) }
        return [reflexion, pregunta?.pregunta].compactMap { $0 }.joined(separator: " ")
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
        let siguiente = temas.first { !detallesCubiertos.contains($0) }
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
        if texto.contains("?") || texto.contains("¿")
            || ConsultaFrida.autorizaContactos(texto) || ConsultaFrida.pideOrientacionDeCuidado(texto) { return true }
        let palabras = ConsultaFrida.comienzoDePeticion(texto)
        guard let primera = palabras.first else { return false }
        return ["abre", "abreme", "muestrame", "dime", "llevame", "ver", "consulta", "consultar",
                "puedes", "podrias", "que", "cuando", "cual", "cuales", "donde", "quien"].contains(primera)
            || palabras.starts(with: ["quiero", "ver"]) || palabras.starts(with: ["a", "quien"])
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
