import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    var telefono = ""
    var codigo = ""
    var mensajeError: String?
    private(set) var challengeId: String?
    private(set) var cargando = false
    private(set) var estaAutenticado: Bool

    var esperandoCodigo: Bool { challengeId != nil }
    var puedeSolicitarCodigo: Bool { telefono.filter(\.isNumber).count >= 10 && !cargando }
    var puedeVerificar: Bool { codigo.count == 6 && !cargando }

    private let service: AuthService
    private let tokens: AuthTokenStore

    init(service: AuthService? = nil, tokens: AuthTokenStore? = nil) {
        self.service = service ?? AuthService()
        self.tokens = tokens ?? .shared
        self.estaAutenticado = self.tokens.cargar() != nil
    }

    func solicitarCodigo() async {
        guard puedeSolicitarCodigo else { return }
        await ejecutar {
            let response = try await service.solicitarCodigo(telefono: telefonoParaEnvio())
            challengeId = response.challengeId
            codigo = ""
        }
    }

    func verificarCodigo() async {
        guard puedeVerificar, let challengeId else { return }
        await ejecutar {
            let response = try await service.verificarCodigo(challengeId: challengeId, codigo: codigo)
            try tokens.guardar(response.token)
            estaAutenticado = true
            codigo = ""
        }
    }

    func cambiarNumero() {
        challengeId = nil
        codigo = ""
        mensajeError = nil
    }

    func cerrarSesion() async {
        if let token = tokens.cargar() {
            try? await service.cerrarSesion(token: token)
        }
        tokens.eliminar()
        estaAutenticado = false
        cambiarNumero()
    }

    private func telefonoParaEnvio() -> String {
        let digitos = telefono.filter(\.isNumber)
        return !telefono.hasPrefix("+") && digitos.count == 10 ? "+52\(digitos)" : telefono
    }

    private func ejecutar(_ operacion: () async throws -> Void) async {
        cargando = true
        mensajeError = nil
        defer { cargando = false }
        do {
            try await operacion()
        } catch {
            mensajeError = error.localizedDescription
        }
    }
}
