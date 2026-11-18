//
//  AccesoFicha.swift
//  CruzContigo
//
//  HU-08 (RF-30, RF-31) y HU-16 (RF-38): quién puede consultar la ficha médica.
//

import Foundation

enum RolAcceso: String, Codable, CaseIterable, Identifiable {
    case titular, administrador, cocuidador
    case soloLectura = "solo_lectura"
    case temporal, profesional

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .titular: "Titular"
        case .administrador: "Responsable"
        case .cocuidador: "Cocuidador"
        case .soloLectura: "Solo lectura"
        case .temporal: "Temporal"
        case .profesional: "Profesional de salud"
        }
    }

    var descripcion: String {
        switch self {
        case .titular: "Dueña de la información médica."
        case .administrador: "Administra el perfil y sus accesos."
        case .cocuidador: "Consulta y edita la ficha, los medicamentos y los recordatorios."
        case .soloLectura: "Consulta la información sin poder cambiarla."
        case .temporal: "Acceso con vencimiento a tareas y recordatorios."
        case .profesional: "Consulta solo la ficha médica por tiempo limitado. Su institución debe tener convenio con Cruz Roja y cada consulta queda registrada."
        }
    }

    static let autorizables: [RolAcceso] = [.cocuidador, .soloLectura, .profesional]
}

enum EstadoAcceso: String, Codable {
    case invitado, activo, revocado, vencido
}

struct MiembroAcceso: Codable, Identifiable, Hashable {
    let id: UUID
    let nombre: String?
    let telefono: String?
    let rol: RolAcceso
    let relacion: String?
    let estado: EstadoAcceso
    let venceEn: Date?
    let esTuCuenta: Bool

    var nombreVisible: String {
        if let nombre, !nombre.isEmpty { return nombre }
        return telefono ?? "Cuenta sin nombre"
    }

    /// La persona titular y la propia cuenta no se pueden retirar desde aquí.
    var revocable: Bool { !esTuCuenta && rol != .titular }
}

struct RespuestaAccesos: Codable {
    let versionAviso: String
    let miembros: [MiembroAcceso]
}

struct SolicitudAcceso: Codable, Equatable {
    static let diasProfesional = 1...30

    var telefono: String = ""
    var rol: RolAcceso = .cocuidador
    var relacion: String?
    var diasVigencia: Int?
    var versionAviso: String = AvisoPrivacidad.version
    var aceptaAviso: Bool = false

    var errores: [String] {
        var e: [String] = []
        if telefono.filter(\.isNumber).count != 10 { e.append("Escribe un teléfono de 10 dígitos.") }
        if !RolAcceso.autorizables.contains(rol) { e.append("Elige el tipo de acceso.") }
        if rol == .profesional, !Self.diasProfesional.contains(diasVigencia ?? 0) {
            e.append("El acceso profesional dura de 1 a 30 días.")
        }
        if (relacion?.count ?? 0) > 40 { e.append("La relación no puede superar 40 caracteres.") }
        if !aceptaAviso { e.append("Debes aceptar el aviso de privacidad.") }
        return e
    }

    var esValida: Bool { errores.isEmpty }
}

struct RegistroConsentimiento: Codable, Identifiable, Hashable {
    enum Accion: String, Codable {
        case autorizar, revocar
    }

    struct Persona: Codable, Hashable {
        let nombre: String?
        let telefono: String?

        var visible: String {
            if let nombre, !nombre.isEmpty { return nombre }
            return telefono ?? "Cuenta sin nombre"
        }
    }

    let id: UUID
    let accion: Accion
    let rol: RolAcceso
    let versionAviso: String
    let fecha: Date
    let otorgadoPor: Persona
    let usuario: Persona

    var descripcion: String {
        switch accion {
        case .autorizar: "\(otorgadoPor.visible) autorizó a \(usuario.visible) como \(rol.titulo.lowercased())"
        case .revocar: "\(otorgadoPor.visible) retiró el acceso de \(usuario.visible)"
        }
    }
}

/// Texto que la persona acepta al compartir datos médicos. Si cambia, sube la versión
/// aquí y en el backend (`VERSION_AVISO`); la API rechaza versiones distintas.
enum AvisoPrivacidad {
    static let version = "2026-11"

    static let texto = """
    Al autorizar este acceso, compartes datos médicos sensibles: tipo sanguíneo, alergias, \
    enfermedades, antecedentes, médico tratante e institución de salud. La otra persona solo \
    verá lo que su tipo de acceso permite. CruzContigo guarda quién autorizó, a quién, cuándo \
    y con qué versión de este aviso. Puedes retirar el acceso en cualquier momento y se aplica \
    en la siguiente consulta. Los datos se tratan conforme a la LFPDPPP.
    """
}
