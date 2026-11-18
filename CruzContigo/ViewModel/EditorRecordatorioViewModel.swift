import Foundation
import Observation

@MainActor
@Observable
final class EditorRecordatorioViewModel {
    let recordatorio: Recordatorio?
    var titulo: String
    var familiarID: UUID?
    var fecha: Date
    var guardando = false
    var error: String?

    private let onGuardar: (DatosRecordatorio) async throws -> Void

    init(
        familiarInicial: UUID?,
        recordatorio: Recordatorio?,
        onGuardar: @escaping (DatosRecordatorio) async throws -> Void
    ) {
        self.recordatorio = recordatorio
        self.onGuardar = onGuardar
        titulo = recordatorio?.titulo ?? ""
        familiarID = recordatorio?.familiarID ?? familiarInicial
        fecha = recordatorio?.fecha ?? Date().addingTimeInterval(300)
    }

    var tituloLimpio: String {
        titulo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var puedeGuardar: Bool {
        !guardando && familiarID != nil && !tituloLimpio.isEmpty && tituloLimpio.count <= 120
    }

    func guardar() async -> Bool {
        guard !guardando, let familiarID else { return false }
        guard !tituloLimpio.isEmpty, tituloLimpio.count <= 120 else { return false }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await onGuardar(DatosRecordatorio(
                titulo: tituloLimpio, familiarID: familiarID, fecha: fecha,
                completado: recordatorio?.completado ?? false
            ))
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
