import Foundation
import Observation

struct SolicitudDeFrida: Equatable {
    let id = UUID()
    let pregunta: String?
}

@MainActor
@Observable
final class SolicitudesDeFrida {
    static let compartidas = SolicitudesDeFrida()
    private(set) var pendiente: SolicitudDeFrida?

    func abrir(pregunta: String? = nil) {
        let texto = pregunta?.trimmingCharacters(in: .whitespacesAndNewlines)
        pendiente = SolicitudDeFrida(pregunta: texto?.isEmpty == false ? texto : nil)
    }

    func tomarSolicitud() -> SolicitudDeFrida? {
        defer { pendiente = nil }
        return pendiente
    }
}
