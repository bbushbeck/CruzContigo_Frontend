import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    var destinoFrida: Ruta?

    private var seleccionVersion = 0
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var seleccionID: String {
        _ = seleccionVersion
        return defaults.string(forKey: ClavesApp.personaSeleccionada) ?? ""
    }

    var textoSaludo: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: "¡Buenos días!"
        case 12..<19: "¡Buenas tardes!"
        default: "¡Buenas noches!"
        }
    }

    func subtitulo(para familiares: [Familiar]) -> String {
        switch familiares.count {
        case 0: "Empecemos por registrar a la persona que cuidas."
        case 1: "Aquí tienes lo importante sobre \(familiares[0].nombre)."
        default: "Elige a quién quieres atender ahora."
        }
    }

    func seleccionar(_ familiar: Familiar) {
        defaults.set(familiar.id.uuidString, forKey: ClavesApp.personaSeleccionada)
        seleccionVersion += 1
    }

    func navegarDesdeFrida() -> Ruta? {
        guard let destinoFrida else { return nil }
        self.destinoFrida = nil
        return destinoFrida
    }
}
