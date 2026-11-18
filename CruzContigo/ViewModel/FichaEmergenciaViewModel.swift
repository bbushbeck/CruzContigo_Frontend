//
//  FichaEmergenciaViewModel.swift
//  CruzContigo
//

import Foundation
import Observation

@MainActor
@Observable
final class FichaEmergenciaViewModel {
    enum Estado: Equatable {
        case cargando, lista, sinDatos, sinAcceso(String)
    }

    let familiarID: UUID
    private(set) var ficha: FichaEmergencia?
    private(set) var estado: Estado = .cargando
    /// La ficha que se muestra es la copia guardada, no la del servidor.
    private(set) var sinConexion = false
    var procesandoQR = false
    var errorQR: String?

    private let sincronizador: SincronizadorFichaEmergencia
    private let accesos: AccesosRepository

    init(
        familiarID: UUID,
        sincronizador: SincronizadorFichaEmergencia? = nil,
        accesos: AccesosRepository? = nil
    ) {
        self.familiarID = familiarID
        self.sincronizador = sincronizador ?? SincronizadorFichaEmergencia()
        self.accesos = accesos ?? Repositorios.accesos()
    }

    /// Primero muestra la copia guardada (abre al instante y en modo avión) y después
    /// intenta actualizarla. Sin datos del familiar (la lista no cargó) solo usa la copia.
    func cargar(familiar: Familiar?) async {
        if let guardada = FichasEmergenciaGuardadas.obtener(familiarID) {
            ficha = guardada
            estado = .lista
        }
        guard let familiar else {
            sinConexion = true
            if ficha == nil { estado = .sinDatos }
            return
        }
        do {
            ficha = try await sincronizador.sincronizar(familiar)
            sinConexion = false
            estado = .lista
        } catch APIError.sinAcceso(let mensaje) {
            ficha = nil
            estado = .sinAcceso(mensaje)
        } catch {
            sinConexion = true
            if ficha == nil { estado = .sinDatos }
        }
    }

    func cambiarQR(_ consentido: Bool, familiar: Familiar?) async -> Bool {
        procesandoQR = true
        defer { procesandoQR = false }
        let solicitud = consentido
            ? SolicitudQR(consentido: true, versionAviso: AvisoPrivacidad.version, aceptaAviso: true)
            : SolicitudQR(consentido: false)
        do {
            _ = try await accesos.cambiarQR(solicitud, familiarID: familiarID)
            await cargar(familiar: familiar)
            return true
        } catch {
            errorQR = error.localizedDescription
            return false
        }
    }
}
