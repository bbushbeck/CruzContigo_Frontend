//
//  RecetaTextoParser.swift
//  CruzContigo
//

import Foundation

/// Organiza en medicamentos las líneas que Vision reconoce en una receta.
/// Se usa cuando Apple Intelligence no está disponible (por ejemplo en iOS 26 sin
/// un dispositivo compatible). Solo copia lo que está escrito: no calcula ni corrige dosis.
nonisolated enum RecetaTextoParser {
    static func medicamentos(en lineas: [String]) -> [MedicamentoTranscrito] {
        var resultado: [MedicamentoTranscrito] = []
        var actual: MedicamentoTranscrito?
        var nombrePendiente: String?

        func cerrarActual() {
            if let medicamento = actual { resultado.append(medicamento) }
            actual = nil
        }

        func iniciar(_ nombre: String) {
            cerrarActual()
            actual = MedicamentoTranscrito(nombre: nombre)
            nombrePendiente = nil
        }

        for linea in lineas.map(normalizar) where !linea.isEmpty {
            if esEncabezado(linea) {
                nombrePendiente = nil
                continue
            }

            let dosis = primeraDosis(en: linea)
            let esIndicacion = empiezaConInstruccion(linea)

            if let dosis, !esIndicacion {
                let nombre = limpiarNombre(String(linea[..<dosis.inicio]))
                if tieneLetras(nombre) {
                    iniciar(nombre)
                } else if let pendiente = nombrePendiente {
                    iniciar(pendiente)
                }
                if actual != nil, actual?.dosis == nil {
                    actual?.dosis = dosis.cantidad
                    actual?.unidad = dosis.unidad
                }
            } else if esIndicacion {
                if let pendiente = nombrePendiente { iniciar(pendiente) }
                guard actual != nil else { continue }
                if actual?.dosis == nil, let dosis {
                    actual?.dosis = dosis.cantidad
                    actual?.unidad = dosis.unidad
                }
                let previa = actual?.indicacion.map { $0 + " " } ?? ""
                actual?.indicacion = previa + linea
            } else if pareceNombre(linea) {
                nombrePendiente = linea
                continue
            }

            guard actual != nil else { continue }
            if actual?.presentacion == nil { actual?.presentacion = coincidencia(presentacion, en: linea) }
            if actual?.frecuencia == nil { actual?.frecuencia = coincidencia(frecuencia, en: linea) }
            if actual?.duracionDias == nil { actual?.duracionDias = duracionDias(en: linea) }
        }
        cerrarActual()
        return resultado
    }

    // MARK: - Patrones

    private static let unidades = #"mcg|µg|mg|ml|g|ui|u\.i\.|%"#

    private static let patronDosis = expresion(#"(\d+(?:[.,]\d+)?)\s*("# + unidades + #")(?![a-záéíóúñ])"#)

    private static let frecuencia = expresion(
        #"cada\s+\d+(?:[.,]\d+)?\s*(?:horas?|hrs?|h|minutos?|min|d[ií]as?|semanas?)(?![a-záéíóúñ])"# +
        #"|\d+\s+(?:veces|vez)\s+(?:al|por)\s+(?:d[ií]a|semana)"# +
        #"|(?:una|dos|tres|cuatro)\s+(?:veces|vez)\s+al\s+d[ií]a"# +
        #"|cada\s+(?:ma[ñn]ana|noche|d[ií]a|tercer\s+d[ií]a)"# +
        #"|en\s+ayunas|antes\s+de\s+dormir|al\s+acostarse|diariamente|diario"#
    )

    private static let duracion = expresion(#"(?:por|durante)\s+(\d+)\s*(d[ií]as?|semanas?|mes(?:es)?)"#)

    private static let presentacion = expresion(
        #"(?<![a-záéíóúñ])(?:tabletas?|c[aá]psulas?|comprimidos?|grageas?|soluci[oó]n|suspensi[oó]n|jarabe|gotas|crema|ung[üu]ento|pomada|gel|inyectable|ampolletas?|ampollas?|parches?|sobres?|[oó]vulos?|supositorios?|aerosol|inhalador)(?![a-záéíóúñ])"#
    )

    /// Datos del paciente, del médico o de la clínica: nunca son medicamentos.
    private static let encabezados = [
        "paciente", "nombre", "edad", "fecha", "dr ", "dr.", "dra", "doctor", "medico", "cedula",
        "firma", "tel", "direccion", "domicilio", "hospital", "clinica", "diagnostico", "peso",
        "talla", "folio", "especialidad", "consultorio", "alergia", "temperatura", "rfc", "receta",
    ]

    /// Palabras con las que empieza una instrucción de toma, no el nombre de un medicamento.
    private static let instrucciones = [
        "tomar", "tome", "toma", "aplicar", "aplique", "administrar", "administre", "dar", "de ",
        "ingerir", "colocar", "coloque", "usar", "use", "inhalar", "inhale", "masticar", "disolver",
        "via ", "indicacion", "indicaciones", "instrucciones", "dosis:",
    ]

    // MARK: - Ayudantes

    private static func expresion(_ patron: String) -> NSRegularExpression {
        // Los patrones son constantes del código; si alguno no compila es un error de programación.
        try! NSRegularExpression(pattern: patron, options: [.caseInsensitive])
    }

    private static func normalizar(_ linea: String) -> String {
        linea.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func plegar(_ texto: String) -> String {
        texto.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
    }

    private static func esEncabezado(_ linea: String) -> Bool {
        let texto = plegar(linea)
        return encabezados.contains { empieza(texto, con: $0) }
    }

    private static func empiezaConInstruccion(_ linea: String) -> Bool {
        let texto = plegar(limpiarNombre(linea))
        return instrucciones.contains { empieza(texto, con: $0) }
    }

    /// Compara palabras completas: "tel" no debe coincidir con "Telmisartán".
    private static func empieza(_ texto: String, con palabra: String) -> Bool {
        guard texto.hasPrefix(palabra) else { return false }
        guard let siguiente = texto.dropFirst(palabra.count).first else { return true }
        return !siguiente.isLetter
    }

    private static func primeraDosis(en linea: String) -> (inicio: String.Index, cantidad: String, unidad: String)? {
        let rango = NSRange(linea.startIndex..., in: linea)
        guard let match = patronDosis.firstMatch(in: linea, range: rango),
              let todo = Range(match.range, in: linea),
              let cantidad = Range(match.range(at: 1), in: linea),
              let unidad = Range(match.range(at: 2), in: linea) else { return nil }
        return (todo.lowerBound, String(linea[cantidad]), String(linea[unidad]))
    }

    private static func coincidencia(_ expresion: NSRegularExpression, en linea: String) -> String? {
        let rango = NSRange(linea.startIndex..., in: linea)
        guard let match = expresion.firstMatch(in: linea, range: rango),
              let encontrado = Range(match.range, in: linea) else { return nil }
        return String(linea[encontrado])
    }

    private static func duracionDias(en linea: String) -> Int? {
        let rango = NSRange(linea.startIndex..., in: linea)
        guard let match = duracion.firstMatch(in: linea, range: rango),
              let numero = Range(match.range(at: 1), in: linea),
              let unidad = Range(match.range(at: 2), in: linea),
              let cantidad = Int(linea[numero]) else { return nil }
        let periodo = plegar(String(linea[unidad]))
        if periodo.hasPrefix("semana") { return cantidad * 7 }
        if periodo.hasPrefix("mes") { return cantidad * 30 }
        return cantidad
    }

    /// Quita viñetas y numeración ("1.", "2)", "-", "•", "Rx:") y la primera cifra de una
    /// dosis combinada ("Amoxicilina/Ácido clavulánico 875/" → sin "875/").
    private static func limpiarNombre(_ texto: String) -> String {
        texto.replacingOccurrences(of: #"^\s*(?:rx[:.]?\s*)?(?:\d+\s*[.)-]\s*|[-•*·]\s*)?"#, with: "",
                                   options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s*\d+(?:[.,]\d+)?\s*/\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,;:-/").union(.whitespacesAndNewlines))
    }

    private static func tieneLetras(_ texto: String) -> Bool {
        texto.filter(\.isLetter).count >= 3
    }

    /// Una línea corta, sin números, que podría ser el nombre de un medicamento
    /// cuya dosis viene en la línea siguiente.
    private static func pareceNombre(_ linea: String) -> Bool {
        let nombre = limpiarNombre(linea)
        return tieneLetras(nombre) && !nombre.contains(where: \.isNumber) &&
            nombre.split(separator: " ").count <= 4
    }
}
