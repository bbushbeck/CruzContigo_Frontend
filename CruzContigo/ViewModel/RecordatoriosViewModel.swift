import Foundation
import Observation

@MainActor
@Observable
final class RecordatoriosViewModel {
    let familiarID: UUID?
    var recordatorios: [Recordatorio] = []
    var cargando = false
    var guardando = false
    var mensajeCarga: String?
    var mensajeOperacion: String?

    private let servicio: RecordatoriosService
    private let notificaciones: NotificationHandler

    init(
        familiarID: UUID? = nil,
        servicio: RecordatoriosService? = nil,
        notificaciones: NotificationHandler? = nil
    ) {
        self.familiarID = familiarID
        self.servicio = servicio ?? RecordatoriosService()
        self.notificaciones = notificaciones ?? NotificationHandler()
    }

    var visibles: [Recordatorio] {
        recordatorios.filter { familiarID == nil || $0.familiarID == familiarID }
            .sorted { $0.fecha < $1.fecha }
    }

    func cargar() async {
        guard !cargando, !guardando else { return }
        cargando = true
        defer { cargando = false }
        do {
            let respuesta = try await servicio.listar()
            guard !Task.isCancelled else { return }
            recordatorios = respuesta
            mensajeCarga = nil
        } catch {
            if !Task.isCancelled { mensajeCarga = error.localizedDescription }
        }
    }

    func guardar(_ datos: DatosRecordatorio, id: UUID?, familiares: [Familiar]) async throws {
        guard !cargando, !guardando else {
            throw APIError.servidor("Espera a que termine la actualización.")
        }
        guardando = true
        defer { guardando = false }
        let guardado = try await servicio.guardar(datos, id: id)
        recordatorios.removeAll { $0.id == guardado.id }
        recordatorios.append(guardado)
        await notificaciones.actualizar(guardado, nombre: nombre(de: guardado.familiarID, familiares: familiares))
    }

    func alternarCompletado(_ recordatorio: Recordatorio, familiares: [Familiar]) async {
        var datos = recordatorio.datos
        datos.completado.toggle()
        do {
            try await guardar(datos, id: recordatorio.id, familiares: familiares)
        } catch {
            mensajeOperacion = error.localizedDescription
        }
    }

    func eliminar(_ recordatorio: Recordatorio) async {
        guard !cargando, !guardando else { return }
        guardando = true
        defer { guardando = false }
        do {
            try await servicio.eliminar(id: recordatorio.id)
            recordatorios.removeAll { $0.id == recordatorio.id }
            notificaciones.cancelar(id: recordatorio.id)
        } catch {
            mensajeOperacion = error.localizedDescription
        }
    }

    private func nombre(de id: UUID, familiares: [Familiar]) -> String {
        familiares.first { $0.id == id }?.nombreCompleto ?? "Familiar"
    }
}
