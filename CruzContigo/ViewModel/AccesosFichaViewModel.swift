//
//  AccesosFichaViewModel.swift
//  CruzContigo
//

import Foundation
import Observation

@MainActor
@Observable
final class AccesosFichaViewModel {
    enum Estado: Equatable {
        case cargando, listo, error(String)
    }

    let familiarID: UUID
    private(set) var miembros: [MiembroAcceso] = []
    private(set) var historial: [RegistroConsentimiento] = []
    private(set) var estado: Estado = .cargando
    private(set) var versionServidor: String?
    var procesando = false
    var error: String?

    private let repositorio: AccesosRepository

    init(familiarID: UUID, repositorio: AccesosRepository? = nil) {
        self.familiarID = familiarID
        self.repositorio = repositorio ?? Repositorios.accesos()
    }

    /// El texto que ve la persona debe ser el mismo que acepta. Si el servidor ya usa otra
    /// versión, la app está desactualizada y no debe pedir consentimiento.
    var avisoDesactualizado: Bool {
        guard let versionServidor else { return false }
        return versionServidor != AvisoPrivacidad.version
    }

    var activos: [MiembroAcceso] { miembros.filter { $0.estado != .vencido } }
    var vencidos: [MiembroAcceso] { miembros.filter { $0.estado == .vencido } }

    func cargar() async {
        if miembros.isEmpty { estado = .cargando }
        do {
            let respuesta = try await repositorio.listar(familiarID: familiarID)
            miembros = respuesta.miembros.sorted(by: Self.orden)
            versionServidor = respuesta.versionAviso
            historial = try await repositorio.consentimientos(familiarID: familiarID)
            estado = .listo
        } catch {
            estado = .error(error.localizedDescription)
        }
    }

    func autorizar(_ solicitud: SolicitudAcceso) async -> String? {
        guard solicitud.esValida else { return solicitud.errores.first }
        guard !avisoDesactualizado else { return "Actualiza la app para revisar el aviso de privacidad vigente." }
        procesando = true
        defer { procesando = false }
        do {
            _ = try await repositorio.autorizar(Self.limpia(solicitud), familiarID: familiarID)
            await cargar()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func revocar(_ miembro: MiembroAcceso) async {
        guard miembro.revocable else { return }
        procesando = true
        defer { procesando = false }
        do {
            try await repositorio.revocar(miembroID: miembro.id, familiarID: familiarID)
            miembros.removeAll { $0.id == miembro.id }
            historial = (try? await repositorio.consentimientos(familiarID: familiarID)) ?? historial
        } catch {
            self.error = error.localizedDescription
        }
    }

    private static func limpia(_ solicitud: SolicitudAcceso) -> SolicitudAcceso {
        var limpia = solicitud
        limpia.telefono = String(solicitud.telefono.filter(\.isNumber))
        let relacion = solicitud.relacion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        limpia.relacion = relacion.isEmpty || solicitud.rol == .profesional ? nil : relacion
        if solicitud.rol != .profesional { limpia.diasVigencia = nil }
        limpia.versionAviso = AvisoPrivacidad.version
        return limpia
    }

    private static func orden(_ a: MiembroAcceso, _ b: MiembroAcceso) -> Bool {
        if a.esTuCuenta != b.esTuCuenta { return a.esTuCuenta }
        return a.nombreVisible.localizedCompare(b.nombreVisible) == .orderedAscending
    }
}
