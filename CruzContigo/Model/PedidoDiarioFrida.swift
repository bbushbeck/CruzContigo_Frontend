import Foundation

struct PedidoDiarioFrida {
    enum Accion: Equatable {
        case guardar, revisar
    }

    let accion: Accion
    let contenido: String?
    let referencia: String

    private static let formas: [(palabras: [String], accion: Accion)] = {
        let formasGuardar = [
            "puedes guardarlo", "puedes guardar", "puedes anotarlo", "puedes anotar", "puedes apuntar",
            "podrias guardarlo", "podrias guardar", "podrias anotarlo", "podrias anotar", "podrias apuntar",
            "me lo puedes guardar", "me lo podrias guardar", "me lo guardas",
            "me puedes guardar", "me podrias guardar", "me puedes anotar",
            "que lo guardes", "que lo anotes", "quiero que lo guardes", "quiero que lo anotes",
            "quiero guardar", "quiero anotarlo", "quiero anotar",
            "guarda", "guardar", "guardalo", "guardarlo", "guardame", "guardemos",
            "anota", "anotalo", "anotame", "apunta", "apuntalo", "registra", "registralo",
            "archiva", "archivalo", "pasalo", "dejalo por escrito", "dejalo"
        ]
        let formasRevisar = [
            "revisa", "revisar", "quiero revisar", "resume", "resumelo", "resumir", "hazme un resumen",
            "haz un resumen", "prepara un resumen", "puedes resumir", "puedes hacer un resumen"
        ]
        return formasGuardar.map { (ConsultaFrida.palabras($0), .guardar) }
            + formasRevisar.map { (ConsultaFrida.palabras($0), .revisar) }
    }()

    private static let destinos: Set<String> = ["nota", "notas", "diario"]

    init?(_ texto: String) {
        let partes = texto.split { !$0.isLetter && !$0.isNumber }
        let palabras = ConsultaFrida.palabras(texto)
        let introductores: Set<String> = ["frida", "oye", "ay", "si", "bueno", "ok", "por", "favor"]
        let inicio = palabras.drop(while: introductores.contains).startIndex
        let referencias: Set<String> = ["esto", "eso", "relato", "resumen"]
        guard partes.count == palabras.count else { return nil }

        for indice in inicio..<palabras.count {
            let coincidencias = Self.formas.filter { palabras[indice...].starts(with: $0.palabras) }
            guard !coincidencias.isEmpty else { continue }
            let previo = texto[..<partes[indice].startIndex]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if indice > inicio {
                let antes = Array(palabras[..<indice])
                let niegaPedido = ["no", "no quiero", "no lo", "no me", "no puedes", "no podrias",
                                   "sin", "no se si", "no se si quiero"].contains {
                    let negacion = ConsultaFrida.palabras($0)
                    return antes.suffix(negacion.count).elementsEqual(negacion)
                }
                let citaAOtraPersona = ["me dijo", "me pregunto", "me pidio", "me dijeron", "dijo que", "dile que"]
                    .contains {
                        ConsultaFrida.contiene($0, en: antes)
                    }
                let negacionSobreGuardar = ["no quiero", "no necesito", "no te pido", "no te estoy pidiendo",
                                            "no se como", "como puedo", "como se", "me ensenas a", "me explicas como"]
                    .contains { ConsultaFrida.contiene($0, en: antes) }
                guard !niegaPedido, antes.last != "puedo", !negacionSobreGuardar, !citaAOtraPersona,
                      previo.last.map({ !"«“\"".contains($0) }) != false else { continue }
            }
            for (comando, accion) in coincidencias {
                let forma = comando.joined(separator: " ")
                let resto = palabras.dropFirst(indice + comando.count)
                let destino = resto.firstIndex(where: Self.destinos.contains)
                let pideRelato = !referencias.isDisjoint(with: resto)
                    || ["lo que te", "lo de hoy"].contains { ConsultaFrida.contiene($0, en: Array(resto)) }
                let breve = resto.allSatisfy(introductores.contains)
                    && ["guardalo", "guardarlo", "anotalo", "apuntalo", "registralo", "dejalo por escrito", "puedes guardarlo",
                        "puedes anotarlo", "que lo guardes", "que lo anotes", "quiero que lo guardes",
                        "quiero que lo anotes", "resumelo", "hazme un resumen", "haz un resumen"].contains(forma)
                let introduceDictado = ["anota", "anotame", "apunta", "registra"].contains(forma) && resto.first == "que"
                let formaDirecta = comando.count > 1
                    || ["guardalo", "anotalo", "apuntalo", "registralo", "archivalo", "pasalo", "dejalo"].contains(forma)
                if indice == inicio {
                    guard destino != nil || pideRelato || breve || introduceDictado else { continue }
                } else {
                    guard destino != nil, formaDirecta || pideRelato || previo.last?.isPunctuation == true else { continue }
                }

                if indice > inicio {
                    let previo = String(texto[..<partes[indice].startIndex])
                    let limpio = previo.replacingOccurrences(
                        of: #"(?i)^(?:y\s+)?creo que deber[ií]a(?:\s+de)?\s+(?:anotarlo|guardarlo)\s+que\s+"#,
                        with: "", options: .regularExpression
                    ).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                    contenido = limpio.isEmpty ? nil : limpio
                    referencia = String(texto[partes[indice].startIndex...])
                } else {
                    let finPedido = introduceDictado ? resto.startIndex : destino.map { $0 + 1 }
                    if let finPedido, finPedido + 1 < partes.count, palabras[finPedido] == "que" {
                        contenido = String(texto[partes[finPedido + 1].startIndex...])
                        referencia = String(texto[..<partes[finPedido].startIndex])
                    } else {
                        contenido = nil
                        referencia = texto
                    }
                }
                self.accion = accion
                return
            }
        }
        return nil
    }

    func destinoUnico(relato: String, personas: [Familiar], diariosDisponibles: [Familiar], recibeCuidados: Bool) -> Familiar? {
        let palabras = ConsultaFrida.palabras(referencia)
        let titulares = diariosDisponibles.filter { $0.rol == RolAcceso.titular.rawValue }
        let diarioPropio = recibeCuidados && titulares.count == 1 ? titulares.first : nil
        if ConsultaFrida.contiene("mi diario", en: palabras) {
            return diarioPropio
        }
        let explicito = palabras.indices.dropLast().first {
            Self.destinos.contains(palabras[$0]) && palabras[$0 + 1] == "de"
        }
        let texto = explicito.map { palabras.dropFirst($0 + 2).joined(separator: " ") } ?? referencia + "\n" + relato
        let mencionadas = personas.filter {
            !ConsultaFrida.coincidencias(texto, familiares: [$0]).isEmpty
        }
        if mencionadas.isEmpty, explicito == nil { return diarioPropio }
        guard mencionadas.count == 1, let persona = mencionadas.first else { return nil }
        return diariosDisponibles.first { $0.id == persona.id }
    }
}
