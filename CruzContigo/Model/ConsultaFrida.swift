import Foundation

struct ConsultaFrida: Equatable {
    enum Tema { case medicamentos, recordatorios }
    enum Periodo { case todos, hoy, manana, proximos }

    let tema: Tema
    let periodo: Periodo
    let pendientes: Bool
    let abrirPantalla: Bool

    init?(_ texto: String) {
        let palabras = Self.palabras(texto)
        let medicamentos: Set<String> = ["medicamentos", "medicamento", "medicinas", "medicina",
                                         "tratamientos", "tratamiento", "pastillas", "pastilla"]
        let recordatorios: Set<String> = ["recordatorios", "recordatorio", "avisos", "aviso", "alertas", "alerta", "citas", "cita"]
        let med = palabras.firstIndex { medicamentos.contains($0) }
        let rec = palabras.firstIndex { recordatorios.contains($0) }

        switch (med, rec) {
        case let (m?, r?) where r < m && palabras[(r + 1)..<m].contains(where: { ["de", "para"].contains($0) }):
            tema = .recordatorios
        case (nil, .some):
            tema = .recordatorios
        case (.some, nil):
            tema = .medicamentos
        case (nil, nil) where ["que toma", "que esta tomando"].contains(where: { Self.contiene($0, en: palabras) }):
            tema = .medicamentos
        case (nil, nil) where Self.contiene("que tengo", en: palabras)
            && palabras.contains(where: { ["hoy", "manana"].contains($0) }):
            tema = .recordatorios
        default:
            return nil
        }

        if palabras.contains("hoy") { periodo = .hoy }
        else if palabras.contains("manana") { periodo = .manana }
        else if palabras.contains(where: { ["proximo", "proxima", "proximos", "proximas", "siguiente", "siguientes"].contains($0) }) {
            periodo = .proximos
        } else { periodo = .todos }

        pendientes = palabras.contains(where: { ["pendiente", "pendientes"].contains($0) })
        abrirPantalla = palabras.contains(where: { ["abre", "abreme", "abrir", "llevame", "ir"].contains($0) })
    }

    static func palabras(_ texto: String) -> [String] {
        texto.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_MX"))
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    static func contiene(_ frase: String, en palabras: [String]) -> Bool {
        let frase = Self.palabras(frase)
        guard !frase.isEmpty, frase.count <= palabras.count else { return false }
        return (0...(palabras.count - frase.count)).contains { indice in
            palabras[indice..<(indice + frase.count)].elementsEqual(frase)
        }
    }

    static func coincidencias(_ texto: String, familiares: [Familiar]) -> [Familiar] {
        let palabras = palabras(texto)
        let porNombreCompleto = familiares.filter { contiene($0.nombreCompleto, en: palabras) }
        if !porNombreCompleto.isEmpty { return porNombreCompleto }
        return familiares.filter {
            contiene($0.nombre, en: palabras) || alias(de: $0.parentesco).contains { contiene($0, en: palabras) }
        }
    }

    static func mencionaFamiliar(_ texto: String) -> Bool {
        var palabras = palabras(texto)
        if palabras.suffix(2).elementsEqual(["por", "favor"]) { palabras.removeLast(2) }
        if Parentesco.allCases.contains(where: { alias(de: $0).contains { contiene($0, en: palabras) } }) {
            return true
        }
        guard let indice = palabras.lastIndex(where: { ["de", "para"].contains($0) }) else { return false }
        let complemento = palabras.dropFirst(indice + 1)
        let generales: Set<String> = ["hoy", "manana", "mis", "todos", "todas", "los", "las", "medicamentos",
                                      "medicamento", "medicina", "medicinas", "tratamiento", "pastillas",
                                      "pastilla", "esta", "este", "la", "el", "cuidado", "citas"]
        return !complemento.isEmpty && !complemento.allSatisfy { generales.contains($0) }
    }

    static func pideCambios(_ texto: String) -> Bool {
        let palabras = Set(palabras(texto))
        return !palabras.isDisjoint(with: ["agrega", "agregar", "crea", "crear", "registra", "registrar",
                                          "borra", "borrar", "elimina", "eliminar", "edita", "editar",
                                          "cambia", "cambiar", "marca", "marcar", "programa", "programar"])
    }

    static func pideConsejoMedico(_ texto: String) -> Bool {
        let palabras = palabras(texto)
        return ["le doy", "debo darle", "deberia tomar", "me recomiendas", "le puedo dar",
                "cuanta dosis", "que dosis debo", "puede tomar"].contains { contiene($0, en: palabras) }
    }

    private static func alias(de parentesco: Parentesco) -> [String] {
        switch parentesco {
        case .madre: ["madre", "mama", "mami"]
        case .padre: ["padre", "papa", "papi"]
        case .abuela: ["abuela", "abuelita"]
        case .abuelo: ["abuelo", "abuelito"]
        case .otro: []
        default: [parentesco.rawValue]
        }
    }
}
