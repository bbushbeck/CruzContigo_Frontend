//
//  Modulo.swift
//  CruzContigo
//

import Foundation

enum Modulo: String, CaseIterable, Identifiable, Hashable {
    case fichaMedica, medicamentos, recordatorios, citas, emergencia, redCuidado, comunidad, bienestar, ayuda, accesibilidad

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .fichaMedica: "Información médica"
        case .medicamentos: "Medicamentos"
        case .recordatorios: "Recordatorios"
        case .citas: "Citas médicas"
        case .emergencia: "Ficha de emergencia"
        case .redCuidado: "Red de cuidado"
        case .comunidad: "Avisos de Cruz Roja"
        case .bienestar: "Tu bienestar"
        case .ayuda: "Directorio y donaciones"
        case .accesibilidad: "Accesibilidad"
        }
    }

    var subtitulo: String {
        switch self {
        case .fichaMedica: "Alergias, padecimientos y tipo de sangre"
        case .medicamentos: "Tratamientos y registro de tomas"
        case .recordatorios: "Avisos de tomas y pendientes"
        case .citas: "Agenda y notas de cada consulta"
        case .emergencia: "Resumen disponible sin conexión"
        case .redCuidado: "Invita a otras personas a cuidar contigo"
        case .comunidad: "Campañas, cursos y comunicados"
        case .bienestar: "Cuida también de ti"
        case .ayuda: "Sedes, servicios y enlace oficial de donación"
        case .accesibilidad: "Letra para dislexia, modo oscuro, tamaño y más"
        }
    }

    var icono: String {
        switch self {
        case .fichaMedica: "cross.case.fill"
        case .medicamentos: "pills.fill"
        case .recordatorios: "bell.fill"
        case .citas: "calendar"
        case .emergencia: "staroflife.fill"
        case .redCuidado: "person.3.fill"
        case .comunidad: "megaphone.fill"
        case .bienestar: "heart.circle.fill"
        case .ayuda: "mappin.and.ellipse"
        case .accesibilidad: "accessibility"
        }
    }

    var sprint: Int {
        switch self {
        case .redCuidado, .accesibilidad: 1
        case .fichaMedica, .medicamentos, .recordatorios, .citas: 2
        case .emergencia, .comunidad, .bienestar, .ayuda: 3
        }
    }

    var esPorFamiliar: Bool {
        switch self {
        case .fichaMedica, .medicamentos, .recordatorios, .citas, .emergencia: true
        default: false
        }
    }

    static let disponibles: Set<Modulo> = [.fichaMedica, .medicamentos, .recordatorios, .citas, .accesibilidad]

    var disponible: Bool { Self.disponibles.contains(self) }

    static let accesosRapidos: [Modulo] = [.fichaMedica, .medicamentos, .recordatorios]
    static let delPerfil: [Modulo] = [.fichaMedica, .medicamentos, .recordatorios, .citas, .emergencia]
    static let generales: [Modulo] = [.accesibilidad, .redCuidado, .comunidad, .bienestar, .ayuda]
}
