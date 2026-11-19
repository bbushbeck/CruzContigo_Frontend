import Foundation

enum ApoyoFrida: Equatable {
    case hacerseDano, peligroInmediato

    var mensaje: String {
        switch self {
        case .hacerseDano:
            "Gracias por decírmelo. No tienes que pasar por esto a solas. Si puedes, avisa a alguien de confianza y pídele que esté contigo. En México, si estás en peligro inmediato o ya te hiciste daño, llama al 911. También puedes hablar con alguien de Línea de la Vida."
        case .peligroInmediato:
            "Gracias por decírmelo. Si estás en peligro ahora, llama al 911 en México. Si puedes hacerlo con seguridad, avisa a alguien de confianza que pueda acompañarte."
        }
    }

    private static let dano = [
        "me quiero matar", "quiero matarme", "me voy a matar", "voy a matarme",
        "voy a suicidarme", "quiero suicidarme", "me voy a suicidar", "me quiero suicidar",
        "pienso suicidarme", "pienso en suicidarme", "he pensado en suicidarme", "pienso en matarme",
        "estoy pensando en matarme", "pense en matarme", "me quiero quitar la vida", "quiero quitarme la vida",
        "voy a quitarme la vida", "estoy pensando en quitarme la vida", "quiero acabar con mi vida",
        "voy a acabar con mi vida", "puedo acabar con mi vida",
        "quiero hacerme dano", "me quiero hacer dano", "voy a hacerme dano", "me voy a hacer dano",
        "quiero lastimarme", "me quiero lastimar", "voy a lastimarme", "me voy a lastimar",
        "me quiero morir", "quiero morirme", "quiero morir", "prefiero morir",
        "no quiero vivir", "ya no quiero vivir", "no quiero seguir viviendo",
        "no tengo ganas de vivir", "quiero dejar de existir", "no quiero estar vivo", "no quiero estar viva",
        "quisiera no despertar", "ojala no despertara"
    ]

    private static let peligro = [
        "me acabo de hacer dano", "me lastime a proposito", "me acabo de cortar", "me intente suicidar", "intente suicidarme",
        "me tome todas las pastillas", "me tome muchas pastillas", "tome muchas pastillas",
        "me tome un frasco de pastillas", "acabo de tomar una sobredosis",
        "no estoy a salvo", "estoy en peligro", "me estan golpeando", "me estan atacando",
        "me quieren matar", "me amenaza con matarme", "me quieren hacer dano"
    ]

    static func detectar(en texto: String) -> ApoyoFrida? {
        let partes = texto.split { ".,;!?\n".contains($0) }.map { ConsultaFrida.palabras(String($0)) }
        if partes.contains(where: { coincide(peligro, en: $0) }) { return .peligroInmediato }
        if partes.contains(where: { coincide(dano, en: $0) }) { return .hacerseDano }
        return nil
    }

    private static func coincide(_ expresiones: [String], en palabras: [String]) -> Bool {
        let frase = palabras.joined(separator: " ")
        if ["que significa", "como se dice", "la frase", "un personaje dice", "ejemplo de"].contains(where: frase.hasPrefix) {
            return false
        }

        return expresiones.contains { expresion in
            let prueba = ConsultaFrida.palabras(expresion)
            guard prueba.count <= palabras.count else { return false }
            return (0...(palabras.count - prueba.count)).contains { inicio in
                let fin = inicio + prueba.count
                guard palabras[inicio..<fin].elementsEqual(prueba) else { return false }
                if inicio > 0, ["no", "nunca", "jamas"].contains(palabras[inicio - 1]), prueba.first != "no" {
                    return false
                }
                let cola = palabras.dropFirst(fin)
                return !cola.starts(with: ["de", "risa"]) && !cola.starts(with: ["de", "verguenza"])
            }
        }
    }
}

enum IntencionEscuchaFrida {
    private static let escuchar = [
        "quiero que me escuches", "solo escuchame", "necesito desahogarme",
        "no he acabado", "todavia no termino", "no he terminado", "dejame terminar",
        "solo quiero hablar", "necesito hablar", "quiero hablar contigo"
    ]

    private static let rechazoContactos = [
        "no quiero los contactos", "no quiero contactos", "no me muestres los contactos",
        "no me abras los contactos", "no me ensenes los contactos", "no quiero ver los contactos"
    ]

    static func pideEscucha(_ texto: String) -> Bool {
        let palabras = ConsultaFrida.palabras(texto)
        return escuchar.contains { ConsultaFrida.contiene($0, en: palabras) }
    }

    static func rechazaContactos(_ texto: String) -> Bool {
        let palabras = ConsultaFrida.palabras(texto)
        return rechazoContactos.contains { ConsultaFrida.contiene($0, en: palabras) }
    }

    static func soloPideEscucha(_ texto: String) -> Bool {
        let frase = ConsultaFrida.palabras(texto).joined(separator: " ")
        guard pideEscucha(texto) || rechazaContactos(texto) else { return false }
        var resto = " " + frase + " "
        for indicacion in escuchar + rechazoContactos {
            resto = resto.replacingOccurrences(of: " " + indicacion + " ", with: " ")
        }
        return resto.split(separator: " ").allSatisfy {
            ["oye", "ay", "frida", "yo", "solo", "nomás", "nomas", "por", "favor", "y"].contains($0)
        }
    }

    static func solicitaContacto(_ texto: String) -> Bool {
        guard !rechazaContactos(texto), !pideEscucha(texto) else { return false }
        let comienzo = ConsultaFrida.comienzoDePeticion(texto)
        let palabras = Array(comienzo)
        let acciones: Set<String> = ["llamar", "llamarle", "llamo", "avisar", "avisarle", "aviso", "contactar",
                                     "contacto", "comunicarme", "comunico", "telefono", "numero"]
        let peticiones = [
            "dame", "dime", "pasame", "muestra", "muestrame", "ensename", "abre", "abreme", "busca", "ver",
            "quiero ver", "quiero los contactos", "necesito ver", "necesito contactos", "necesito los", "necesito el",
            "puedes", "podrias", "me puedes", "me podrias", "me pasas", "me das",
            "cuales", "cual", "donde", "a quien", "con quien", "no se a quien", "ayudame a encontrar"
        ]
        let pide = peticiones.contains { comienzo.starts(with: ConsultaFrida.palabras($0)) }
        let nombres = ["contactos de emergencia", "contacto de emergencia", "telefono de emergencia",
                       "telefonos de emergencia", "numero de emergencia", "numeros de emergencia"]

        if let nombre = nombres.first(where: { ConsultaFrida.contiene($0, en: palabras) }) {
            if pide { return !ConsultaFrida.contiene("ejemplo de", en: palabras) }
            let asunto = comienzo.drop(while: { ["los", "el", "las", "la", "mis", "sus"].contains($0) })
            let terminos = ConsultaFrida.palabras(nombre)
            guard asunto.starts(with: terminos) else { return false }
            let complemento = asunto.dropFirst(terminos.count)
            return complemento.isEmpty || complemento.starts(with: ["por", "favor"])
                || (["de", "para"].contains(complemento.first ?? "") && complemento.count > 1
                    && !complemento.contains("no") && !complemento.contains("ya"))
        }

        let esTelefono = ["numero de", "telefono de"].contains { comienzo.starts(with: ConsultaFrida.palabras($0)) }
        let buscaPersona = ["a quien", "con quien", "llamar a alguien", "avisarle a alguien",
                            "contactar a alguien", "numero de", "telefono de"].contains {
            ConsultaFrida.contiene($0, en: palabras)
        }
        return (pide || esTelefono) && buscaPersona && !acciones.isDisjoint(with: palabras)
    }
}
