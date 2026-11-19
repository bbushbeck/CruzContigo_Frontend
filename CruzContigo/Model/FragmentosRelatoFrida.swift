import Foundation

/// El modelo elige turnos del relato. El texto que llega a la nota sale del chat.
struct FragmentosRelatoFrida {
    let turnos: [String]

    init(_ relato: String) {
        turnos = relato.split(whereSeparator: \.isNewline)
            .map { Self.sinVocativo(String($0)) }
            .filter { !$0.isEmpty }
    }

    func resumen(seleccion: [Int]?) -> String {
        let completo = turnos.joined(separator: "\n")
        guard !turnos.isEmpty, let seleccion, !seleccion.isEmpty,
              seleccion.allSatisfy({ (1...turnos.count).contains($0) }) else { return completo }

        let incluidos = Set(seleccion)
        let omitidos = turnos.enumerated().filter { !incluidos.contains($0.offset + 1) }

        // Una negación, una corrección o un dato que completa otro turno puede
        // cambiar el sentido del resumen si se omite.
        let palabrasDeContexto: Set<String> = [
            "no", "nunca", "tampoco", "pero", "sino", "desde", "hace", "porque", "aunque",
            "medicamento", "medicamentos", "deuda", "deudas", "deaudas", "triste", "dificil", "preocupa",
            "apetito", "antojo"
        ]
        let omitioContexto = omitidos.contains {
            !palabrasDeContexto.isDisjoint(with: ConsultaFrida.palabras($0.element))
        }
        let dependeDeOtroTurno = turnos.contains {
            let inicio = ConsultaFrida.palabras($0).first ?? ""
            return ["ella", "el", "ellos", "ellas", "le", "eso", "esa", "ese", "tambien", "entonces"].contains(inicio)
        }
        guard !omitioContexto, omitidos.isEmpty || !dependeDeOtroTurno else { return completo }

        return turnos.enumerated()
            .filter { incluidos.contains($0.offset + 1) }
            .map(\.element)
            .joined(separator: "\n")
    }

    static func sinVocativo(_ texto: String) -> String {
        let original = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        let inicio = #"^[¡¿]?(?:(?:hola|ay|oye)\s*,?\s+)?frida(?:\s*[,!:;]+\s*|\s+(?=(?:(?:hoy|ayer)\s+)?(?:yo|me|mi|tengo|tuve|estoy|sal[ií]|camin[eé]|fu[ií]|debo|te)\b))"#
        guard let vocativo = original.range(of: inicio, options: [.regularExpression, .caseInsensitive]) else {
            return original
        }

        let relato = original[vocativo.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        let palabras = ConsultaFrida.palabras(relato)
        let mascotas: Set<String> = ["perrita", "perro", "perra", "mascota", "cachorra"]
        let presentaMascota = palabras.count >= 2 && ["mi", "la", "el"].contains(palabras[0])
            && mascotas.contains(palabras[1])
        guard let primera = relato.first, !presentaMascota else { return original }
        return primera.uppercased() + relato.dropFirst()
    }
}
