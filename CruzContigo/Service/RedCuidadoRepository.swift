//
//  RedCuidadoRepository.swift
//  CruzContigo
//

import Foundation

protocol RedCuidadoRepository {
    func red(familiarID: UUID) async throws -> RespuestaRed
    func invitar(_ solicitud: SolicitudInvitacion, familiarID: UUID) async throws -> InvitacionCreada
    func cancelar(invitacionID: UUID, familiarID: UUID) async throws
    func recibidas() async throws -> [InvitacionRecibida]
    func consultar(codigo: String) async throws -> InvitacionRecibida
    func aceptar(codigo: String) async throws -> ResultadoAceptacion
    func aceptar(invitacionID: UUID) async throws -> ResultadoAceptacion
    func rechazar(invitacionID: UUID) async throws
}

struct RemoteRedCuidadoRepository: RedCuidadoRepository {
    let api: APIClient

    private struct CuerpoCodigo: Encodable { let codigo: String }
    private struct CuerpoAceptar: Encodable {
        var codigo: String?
        var invitacionId: UUID?
    }

    func red(familiarID: UUID) async throws -> RespuestaRed {
        try await api.get("familiares/\(familiarID.uuidString)/red")
    }

    func invitar(_ solicitud: SolicitudInvitacion, familiarID: UUID) async throws -> InvitacionCreada {
        try await api.post("familiares/\(familiarID.uuidString)/invitaciones", cuerpo: solicitud)
    }

    func cancelar(invitacionID: UUID, familiarID: UUID) async throws {
        try await api.delete("familiares/\(familiarID.uuidString)/invitaciones/\(invitacionID.uuidString)")
    }

    func recibidas() async throws -> [InvitacionRecibida] {
        try await api.get("invitaciones")
    }

    func consultar(codigo: String) async throws -> InvitacionRecibida {
        try await api.post("invitaciones/consultar", cuerpo: CuerpoCodigo(codigo: CodigoInvitacion.normalizar(codigo)))
    }

    func aceptar(codigo: String) async throws -> ResultadoAceptacion {
        try await api.post("invitaciones/aceptar", cuerpo: CuerpoAceptar(codigo: CodigoInvitacion.normalizar(codigo)))
    }

    func aceptar(invitacionID: UUID) async throws -> ResultadoAceptacion {
        try await api.post("invitaciones/aceptar", cuerpo: CuerpoAceptar(invitacionId: invitacionID))
    }

    func rechazar(invitacionID: UUID) async throws {
        try await api.delete("invitaciones/\(invitacionID.uuidString)")
    }
}

protocol ContactosRepository {
    func listar(familiarID: UUID) async throws -> [ContactoRegistrado]
    func crear(_ contacto: SolicitudContacto, familiarID: UUID) async throws -> ContactoRegistrado
    func actualizar(_ contacto: SolicitudContacto, id: UUID, familiarID: UUID) async throws -> ContactoRegistrado
    func eliminar(id: UUID, familiarID: UUID) async throws
    func ordenar(_ ids: [UUID], familiarID: UUID) async throws -> [ContactoRegistrado]
}

struct RemoteContactosRepository: ContactosRepository {
    let api: APIClient

    private struct CuerpoOrden: Encodable { let ids: [UUID] }

    func listar(familiarID: UUID) async throws -> [ContactoRegistrado] {
        try await api.get(ruta(familiarID))
    }

    func crear(_ contacto: SolicitudContacto, familiarID: UUID) async throws -> ContactoRegistrado {
        try await api.post(ruta(familiarID), cuerpo: contacto.limpia)
    }

    func actualizar(_ contacto: SolicitudContacto, id: UUID, familiarID: UUID) async throws -> ContactoRegistrado {
        try await api.put("\(ruta(familiarID))/\(id.uuidString)", cuerpo: contacto.limpia)
    }

    func eliminar(id: UUID, familiarID: UUID) async throws {
        try await api.delete("\(ruta(familiarID))/\(id.uuidString)")
    }

    func ordenar(_ ids: [UUID], familiarID: UUID) async throws -> [ContactoRegistrado] {
        try await api.put("\(ruta(familiarID))/orden", cuerpo: CuerpoOrden(ids: ids))
    }

    private func ruta(_ id: UUID) -> String { "familiares/\(id.uuidString)/contactos" }
}

protocol DiarioRepository {
    func listar(familiarID: UUID, categoria: CategoriaNota?, antes: Date?) async throws -> [NotaDiario]
    func crear(_ nota: SolicitudNota, familiarID: UUID) async throws -> NotaDiario
    func actualizar(_ nota: SolicitudNota, id: UUID, familiarID: UUID) async throws -> NotaDiario
    func eliminar(id: UUID, familiarID: UUID) async throws
}

struct RemoteDiarioRepository: DiarioRepository {
    let api: APIClient

    func listar(familiarID: UUID, categoria: CategoriaNota?, antes: Date?) async throws -> [NotaDiario] {
        var consulta: [URLQueryItem] = []
        if let categoria { consulta.append(URLQueryItem(name: "categoria", value: categoria.rawValue)) }
        if let antes { consulta.append(URLQueryItem(name: "antes", value: antes.ISO8601Format())) }
        return try await api.get(ruta(familiarID), consulta: consulta)
    }

    func crear(_ nota: SolicitudNota, familiarID: UUID) async throws -> NotaDiario {
        try await api.post(ruta(familiarID), cuerpo: limpia(nota))
    }

    func actualizar(_ nota: SolicitudNota, id: UUID, familiarID: UUID) async throws -> NotaDiario {
        try await api.put("\(ruta(familiarID))/\(id.uuidString)", cuerpo: limpia(nota))
    }

    func eliminar(id: UUID, familiarID: UUID) async throws {
        try await api.delete("\(ruta(familiarID))/\(id.uuidString)")
    }

    private func limpia(_ nota: SolicitudNota) -> SolicitudNota {
        var limpia = nota
        limpia.texto = nota.texto.trimmingCharacters(in: .whitespacesAndNewlines)
        return limpia
    }

    private func ruta(_ id: UUID) -> String { "familiares/\(id.uuidString)/diario" }
}

/// La red, los contactos y el diario se comparten entre varias cuentas: sin API no hay red.
private struct SinConexion: RedCuidadoRepository, ContactosRepository, DiarioRepository {
    private var error: APIError { .servidor("Esta función requiere conexión con la API.") }

    func red(familiarID: UUID) async throws -> RespuestaRed { throw error }
    func invitar(_ solicitud: SolicitudInvitacion, familiarID: UUID) async throws -> InvitacionCreada { throw error }
    func cancelar(invitacionID: UUID, familiarID: UUID) async throws { throw error }
    func recibidas() async throws -> [InvitacionRecibida] { throw error }
    func consultar(codigo: String) async throws -> InvitacionRecibida { throw error }
    func aceptar(codigo: String) async throws -> ResultadoAceptacion { throw error }
    func aceptar(invitacionID: UUID) async throws -> ResultadoAceptacion { throw error }
    func rechazar(invitacionID: UUID) async throws { throw error }

    func listar(familiarID: UUID) async throws -> [ContactoRegistrado] { throw error }
    func crear(_ contacto: SolicitudContacto, familiarID: UUID) async throws -> ContactoRegistrado { throw error }
    func actualizar(_ contacto: SolicitudContacto, id: UUID, familiarID: UUID) async throws -> ContactoRegistrado { throw error }
    func eliminar(id: UUID, familiarID: UUID) async throws { throw error }
    func ordenar(_ ids: [UUID], familiarID: UUID) async throws -> [ContactoRegistrado] { throw error }

    func listar(familiarID: UUID, categoria: CategoriaNota?, antes: Date?) async throws -> [NotaDiario] { throw error }
    func crear(_ nota: SolicitudNota, familiarID: UUID) async throws -> NotaDiario { throw error }
    func actualizar(_ nota: SolicitudNota, id: UUID, familiarID: UUID) async throws -> NotaDiario { throw error }
}

extension Repositorios {
    static func redCuidado() -> RedCuidadoRepository {
        guard let url = AppConfig.apiBaseURL else { return SinConexion() }
        return RemoteRedCuidadoRepository(api: APIClient(baseURL: url))
    }

    static func contactos() -> ContactosRepository {
        guard let url = AppConfig.apiBaseURL else { return SinConexion() }
        return RemoteContactosRepository(api: APIClient(baseURL: url))
    }

    static func diario() -> DiarioRepository {
        guard let url = AppConfig.apiBaseURL else { return SinConexion() }
        return RemoteDiarioRepository(api: APIClient(baseURL: url))
    }
}
