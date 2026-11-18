//
//  RedCuidado.swift
//  CruzContigo
//
//  HU-17 (RF-11): invitaciones a la red de cuidado. RF-15: contactos de emergencia.
//

import Foundation

struct InvitacionEnviada: Codable, Identifiable, Hashable {
    let id: UUID
    let telefono: String?
    let rol: RolAcceso
    let relacion: String?
    let accesoHasta: Date?
    let permisoFicha: Bool
    let expiraEn: Date

    var destino: String { telefono ?? "Con enlace" }
}

struct RespuestaRed: Codable {
    let puedeInvitar: Bool
    let miembros: [MiembroAcceso]
    let invitaciones: [InvitacionEnviada]
}

struct SolicitudInvitacion: Codable, Equatable {
    static let diasMaximos = 365

    var telefono: String?
    var rol: RolAcceso = .cocuidador
    var relacion: String?
    var accesoHasta: Date?
    var permisoFicha = false
    var versionAviso = AvisoPrivacidad.version
    var aceptaAviso = false

    var errores: [String] {
        var e: [String] = []
        if let telefono, telefono.filter(\.isNumber).count != 10 { e.append("Escribe un teléfono de 10 dígitos.") }
        if !RolAcceso.invitables.contains(rol) { e.append("Elige qué podrá hacer.") }
        if rol == .temporal {
            if let accesoHasta {
                if accesoHasta <= Date() { e.append("La fecha de vencimiento debe ser futura.") }
                if accesoHasta > Date().addingTimeInterval(Double(Self.diasMaximos) * 86_400) {
                    e.append("El acceso temporal dura como máximo un año.")
                }
            } else {
                e.append("Elige hasta cuándo dura el acceso.")
            }
        }
        if (relacion?.count ?? 0) > 40 { e.append("La relación no puede superar 40 caracteres.") }
        if !aceptaAviso { e.append("Debes aceptar el aviso de privacidad.") }
        return e
    }

    var esValida: Bool { errores.isEmpty }
}

struct InvitacionCreada: Codable {
    let invitacion: InvitacionEnviada
    let codigo: String
    let enlace: String

    func mensaje(para nombre: String) -> String {
        """
        Te invito a cuidar a \(nombre) conmigo en CruzContigo.

        Abre este enlace en tu iPhone: \(enlace)

        O en la app ve a Más → Red de cuidado → Tengo un código y escribe: \(codigo)

        El código sirve una sola vez y vence el \(invitacion.expiraEn.formatted(date: .long, time: .omitted)).
        """
    }
}

struct InvitacionRecibida: Codable, Identifiable, Hashable {
    let id: UUID
    let familiarNombre: String
    let rol: RolAcceso
    let relacion: String?
    let accesoHasta: Date?
    let permisoFicha: Bool
    let expiraEn: Date
    let invitadaPor: String
}

struct ResultadoAceptacion: Codable {
    let familiarID: UUID
    let nombre: String
    let rol: RolAcceso
}

enum CodigoInvitacion {
    static let largo = 10

    /// Mayúsculas y sin guiones ni espacios, como lo compara el servidor.
    static func normalizar(_ texto: String) -> String {
        String(texto.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
    }

    /// Lo muestra en dos bloques fáciles de dictar: ABCDE-FGHJK.
    static func formatear(_ texto: String) -> String {
        let limpio = normalizar(texto)
        guard limpio.count > 5 else { return limpio }
        return "\(limpio.prefix(5))-\(limpio.dropFirst(5).prefix(largo - 5))"
    }

    static func esCompleto(_ texto: String) -> Bool { normalizar(texto).count == largo }

    /// `cruzcontigo://invitacion/ABCDEFGHJK` → `ABCDEFGHJK`
    static func desdeEnlace(_ url: URL) -> String? {
        guard url.scheme?.lowercased() == "cruzcontigo", url.host()?.lowercased() == "invitacion" else { return nil }
        let codigo = normalizar(url.lastPathComponent)
        return codigo.count == largo ? codigo : nil
    }
}

// MARK: - Contactos de emergencia (RF-15)

struct ContactoRegistrado: Codable, Identifiable, Hashable {
    let id: UUID
    let nombre: String
    let telefono: String
    let parentesco: String?
    let prioridad: Int
}

struct SolicitudContacto: Codable, Equatable {
    var nombre = ""
    var telefono = ""
    var parentesco: String?

    static let parentescosSugeridos = ["Hija", "Hijo", "Pareja", "Hermana", "Hermano", "Vecina", "Vecino", "Amistad"]

    var errores: [String] {
        var e: [String] = []
        if nombre.trimmingCharacters(in: .whitespaces).count < 2 { e.append("Escribe el nombre.") }
        let digitos = telefono.filter(\.isNumber).count
        if digitos < 10 || digitos > 15 { e.append("Escribe un teléfono de 10 dígitos.") }
        return e
    }

    var esValida: Bool { errores.isEmpty }

    var limpia: SolicitudContacto {
        let relacion = parentesco?.trimmingCharacters(in: .whitespaces) ?? ""
        return SolicitudContacto(
            nombre: nombre.trimmingCharacters(in: .whitespaces),
            telefono: (telefono.hasPrefix("+") ? "+" : "") + telefono.filter(\.isNumber),
            parentesco: relacion.isEmpty ? nil : relacion
        )
    }
}
