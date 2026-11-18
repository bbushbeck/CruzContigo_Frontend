//
//  NotaDiario.swift
//  CruzContigo
//
//  HU-13 (RF-13): diario de cuidado.
//

import Foundation

enum CategoriaNota: String, Codable, CaseIterable, Identifiable {
    case alimentacion, sueno, animo, incidencia, otro

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .alimentacion: "Comida"
        case .sueno: "Sueño"
        case .animo: "Ánimo"
        case .incidencia: "Incidencia"
        case .otro: "Otro"
        }
    }

    var icono: String {
        switch self {
        case .alimentacion: "fork.knife"
        case .sueno: "bed.double.fill"
        case .animo: "face.smiling"
        case .incidencia: "exclamationmark.triangle.fill"
        case .otro: "note.text"
        }
    }

    var pregunta: String {
        switch self {
        case .alimentacion: "¿Qué y cuánto comió?"
        case .sueno: "¿Cómo durmió?"
        case .animo: "¿Cómo se sintió?"
        case .incidencia: "¿Qué pasó?"
        case .otro: "¿Qué quiere anotar?"
        }
    }

    /// Respuestas rápidas para no tener que escribir.
    var sugerencias: [String] {
        switch self {
        case .alimentacion: ["Comió todo", "Comió la mitad", "Casi no comió", "Tomó suficiente agua"]
        case .sueno: ["Durmió bien", "Despertó varias veces", "Durmió poco", "Tomó siesta"]
        case .animo: ["Contenta / contento", "Tranquila / tranquilo", "Triste", "Irritable", "Confundida / confundido"]
        case .incidencia: ["Tuvo una caída", "Tuvo mareo", "Tuvo dolor", "Rechazó su medicina"]
        case .otro: []
        }
    }
}

struct NotaDiario: Codable, Identifiable, Hashable {
    struct Autor: Codable, Hashable {
        let nombre: String
        let esTuyo: Bool
    }

    let id: UUID
    let familiarID: UUID
    let categoria: CategoriaNota
    let texto: String
    let fecha: Date
    let creadoEn: Date
    let editadoEn: Date?
    let autor: Autor
}

struct SolicitudNota: Codable, Equatable {
    static let largoMaximo = 2000

    var categoria: CategoriaNota = .alimentacion
    var texto = ""
    var fecha = Date()

    var errores: [String] {
        var e: [String] = []
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if limpio.isEmpty { e.append("Escribe la nota o toca una respuesta rápida.") }
        if limpio.count > Self.largoMaximo { e.append("La nota puede tener hasta 2000 letras.") }
        if fecha > Date().addingTimeInterval(300) { e.append("La fecha no puede ser futura.") }
        return e
    }

    var esValida: Bool { errores.isEmpty }
}
