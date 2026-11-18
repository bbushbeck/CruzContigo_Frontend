//
//  RedCuidadoViewModel.swift
//  CruzContigo
//

import Foundation
import Observation

@MainActor
@Observable
final class RedCuidadoViewModel {
    enum Estado: Equatable {
        case cargando, listo, error(String)
    }

    private(set) var recibidas: [InvitacionRecibida] = []
    private(set) var red: RespuestaRed?
    private(set) var estadoRed: Estado = .cargando
    var procesando = false
    var error: String?

    private let repositorio: RedCuidadoRepository

    init(repositorio: RedCuidadoRepository = Repositorios.redCuidado()) {
        self.repositorio = repositorio
    }

    func cargarRecibidas() async {
        recibidas = (try? await repositorio.recibidas()) ?? recibidas
    }

    func cargarRed(familiarID: UUID) async {
        if red == nil { estadoRed = .cargando }
        do {
            red = try await repositorio.red(familiarID: familiarID)
            estadoRed = .listo
        } catch {
            red = nil
            estadoRed = .error(error.localizedDescription)
        }
    }

    /// Lanza el error para que el formulario lo muestre junto a sus campos.
    func invitar(_ solicitud: SolicitudInvitacion, familiarID: UUID) async throws -> InvitacionCreada {
        guard solicitud.esValida else {
            throw APIError.servidor(solicitud.errores.first ?? "Revisa los datos.")
        }
        let creada = try await repositorio.invitar(Self.limpia(solicitud), familiarID: familiarID)
        await cargarRed(familiarID: familiarID)
        return creada
    }

    func cancelar(_ invitacion: InvitacionEnviada, familiarID: UUID) async {
        procesando = true
        defer { procesando = false }
        do {
            try await repositorio.cancelar(invitacionID: invitacion.id, familiarID: familiarID)
            await cargarRed(familiarID: familiarID)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func aceptar(_ invitacion: InvitacionRecibida) async -> ResultadoAceptacion? {
        procesando = true
        defer { procesando = false }
        do {
            let resultado = try await repositorio.aceptar(invitacionID: invitacion.id)
            recibidas.removeAll { $0.id == invitacion.id }
            return resultado
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func rechazar(_ invitacion: InvitacionRecibida) async {
        procesando = true
        defer { procesando = false }
        do {
            try await repositorio.rechazar(invitacionID: invitacion.id)
            recibidas.removeAll { $0.id == invitacion.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    static func limpia(_ solicitud: SolicitudInvitacion) -> SolicitudInvitacion {
        var limpia = solicitud
        if let telefono = solicitud.telefono {
            limpia.telefono = String(telefono.filter(\.isNumber))
        }
        let relacion = solicitud.relacion?.trimmingCharacters(in: .whitespaces) ?? ""
        limpia.relacion = relacion.isEmpty ? nil : relacion
        if solicitud.rol != .temporal {
            limpia.accesoHasta = nil
            limpia.permisoFicha = false
        }
        limpia.versionAviso = AvisoPrivacidad.version
        return limpia
    }
}
