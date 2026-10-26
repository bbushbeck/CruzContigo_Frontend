import Foundation

struct AuthService {
    private var api: APIClient {
        APIClient(baseURL: AppConfig.apiBaseURL ?? URL(string: "http://localhost:3000")!)
    }

    func solicitarCodigo(telefono: String) async throws -> RespuestaSolicitud {
        try await api.post("/auth/phone/request-code", cuerpo: SolicitudCodigo(phoneNumber: telefono))
    }

    func verificarCodigo(challengeId: String, codigo: String) async throws -> RespuestaAuth {
        try await api.post(
            "/auth/phone/verify-code",
            cuerpo: VerificacionCodigo(challengeId: challengeId, code: codigo)
        )
    }

    func cerrarSesion(token: String) async throws {
        var cliente = api
        cliente.token = token
        try await cliente.delete("/auth/logout")
    }
}
