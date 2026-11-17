import Foundation

struct RecordatoriosService {
    func listar() async throws -> [Recordatorio] {
        try await cliente().get("recordatorios")
    }

    func guardar(_ datos: DatosRecordatorio, id: UUID?) async throws -> Recordatorio {
        let api = try cliente()
        if let id {
            return try await api.put("recordatorios/\(id.uuidString)", cuerpo: datos)
        }
        return try await api.post("recordatorios", cuerpo: datos)
    }

    func eliminar(id: UUID) async throws {
        try await cliente().delete("recordatorios/\(id.uuidString)")
    }

    private func cliente() throws -> APIClient {
        guard let url = AppConfig.apiBaseURL else {
            throw APIError.servidor("Configura CRUZ_API_URL para conectar con la API.")
        }
        guard let token = AuthTokenStore.shared.cargar() else {
            throw APIError.servidor("Inicia sesión para consultar tus recordatorios.")
        }
        return APIClient(baseURL: url, token: token)
    }
}
