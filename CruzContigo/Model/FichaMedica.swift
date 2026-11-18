//
//  FichaMedica.swift
//  CruzContigo
//

import Foundation

enum TipoSanguineo: String, Codable, CaseIterable, Identifiable {
    case aPositivo = "A+", aNegativo = "A-"
    case bPositivo = "B+", bNegativo = "B-"
    case abPositivo = "AB+", abNegativo = "AB-"
    case oPositivo = "O+", oNegativo = "O-"
    case desconocido

    var id: String { rawValue }

    var titulo: String { self == .desconocido ? "No lo sé" : rawValue }
}

enum Severidad: String, Codable, CaseIterable, Identifiable {
    case leve, moderada, grave

    var id: String { rawValue }

    /// Etiqueta corta para chips y listas.
    var titulo: String {
        switch self {
        case .leve: "Leve"
        case .moderada: "Fuerte"
        case .grave: "Peligrosa"
        }
    }

    /// Explicación en lenguaje cotidiano para quien no es médico.
    var descripcion: String {
        switch self {
        case .leve: "Le molesta un poco (comezón, ronchas)"
        case .moderada: "Le hace daño (vómito, mucha hinchazón)"
        case .grave: "Es peligroso (le falta el aire, se desmaya)"
        }
    }
}

struct Alergia: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var nombre: String
    var severidad: Severidad
}

struct Enfermedad: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var nombre: String
    var notas: String?
}

struct FichaMedica: Codable, Hashable {
    let familiarID: UUID
    var tipoSanguineo: TipoSanguineo?
    var alergias: [Alergia] = []
    var enfermedades: [Enfermedad] = []
    var medicoTratante: String?
    var institucionSalud: String?
    var antecedentes: String?
    var observaciones: String?
    var ultimaActualizacion: Date = Date()

    var errores: [String] {
        var e: [String] = []
        if tipoSanguineo == nil { e.append("Selecciona el tipo sanguíneo (o “No lo sé”).") }
        if Self.tieneDuplicados(alergias.map(\.nombre)) { e.append("Hay alergias repetidas.") }
        if Self.tieneDuplicados(enfermedades.map(\.nombre)) { e.append("Hay enfermedades repetidas.") }
        if (medicoTratante?.count ?? 0) > 120 { e.append("El médico tratante no puede superar 120 caracteres.") }
        if (institucionSalud?.count ?? 0) > 120 { e.append("La institución no puede superar 120 caracteres.") }
        if (antecedentes?.count ?? 0) > 4000 { e.append("Los antecedentes no pueden superar 4000 caracteres.") }
        if (observaciones?.count ?? 0) > 1000 { e.append("Las observaciones no pueden superar 1000 caracteres.") }
        return e
    }

    var esValida: Bool { errores.isEmpty }

    /// Lo que un paramédico necesita y todavía no está registrado.
    var datosPendientes: [String] {
        var pendientes: [String] = []
        if tipoSanguineo == nil || tipoSanguineo == .desconocido { pendientes.append("tipo de sangre") }
        if medicoTratante == nil { pendientes.append("su doctor") }
        if institucionSalud == nil { pendientes.append("dónde se atiende") }
        return pendientes
    }

    var tieneDetalles: Bool {
        medicoTratante != nil || institucionSalud != nil || antecedentes != nil || observaciones != nil
    }

    private static func tieneDuplicados(_ nombres: [String]) -> Bool {
        let normalizados = nombres.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        return Set(normalizados).count != normalizados.count
    }
}
