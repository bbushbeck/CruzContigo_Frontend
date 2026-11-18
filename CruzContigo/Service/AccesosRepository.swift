//
//  AccesosRepository.swift
//  CruzContigo
//

import Foundation

protocol AccesosRepository {
    func listar(familiarID: UUID) async throws -> RespuestaAccesos
    func autorizar(_ solicitud: SolicitudAcceso, familiarID: UUID) async throws -> MiembroAcceso
    func revocar(miembroID: UUID, familiarID: UUID) async throws
    func consentimientos(familiarID: UUID) async throws -> [RegistroConsentimiento]
}

struct RemoteAccesosRepository: AccesosRepository {
    let api: APIClient

    func listar(familiarID: UUID) async throws -> RespuestaAccesos {
        try await api.get(ruta(familiarID))
    }

    func autorizar(_ solicitud: SolicitudAcceso, familiarID: UUID) async throws -> MiembroAcceso {
        try await api.post(ruta(familiarID), cuerpo: solicitud)
    }

    func revocar(miembroID: UUID, familiarID: UUID) async throws {
        try await api.delete("\(ruta(familiarID))/\(miembroID.uuidString)")
    }

    func consentimientos(familiarID: UUID) async throws -> [RegistroConsentimiento] {
        try await api.get("\(ruta(familiarID))/consentimientos")
    }

    private func ruta(_ id: UUID) -> String { "familiares/\(id.uuidString)/accesos" }
}

/// Los permisos viven en el servidor: sin API no hay nada que autorizar.
struct SinConexionAccesosRepository: AccesosRepository {
    private var error: APIError { .servidor("Los accesos requieren conexión con la API.") }

    func listar(familiarID: UUID) async throws -> RespuestaAccesos { throw error }
    func autorizar(_ solicitud: SolicitudAcceso, familiarID: UUID) async throws -> MiembroAcceso { throw error }
    func revocar(miembroID: UUID, familiarID: UUID) async throws { throw error }
    func consentimientos(familiarID: UUID) async throws -> [RegistroConsentimiento] { throw error }
}

extension Repositorios {
    static func accesos() -> AccesosRepository {
        if let url = AppConfig.apiBaseURL {
            return RemoteAccesosRepository(api: APIClient(baseURL: url))
        }
        return SinConexionAccesosRepository()
    }
}
