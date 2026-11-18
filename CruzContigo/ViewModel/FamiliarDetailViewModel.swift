import Foundation
import Observation

@MainActor
@Observable
final class FamiliarDetailViewModel {
    func eliminar(
        _ familiar: Familiar,
        usando store: FamiliaresStore,
        alTerminar: @escaping () -> Void
    ) async {
        await store.eliminar(familiar)
        alTerminar()
    }

    func formatearTelefono(_ telefono: String) -> String {
        guard telefono.count == 10 else { return telefono }
        let a = telefono.prefix(2)
        let b = telefono.dropFirst(2).prefix(4)
        let c = telefono.suffix(4)
        return "\(a) \(b) \(c)"
    }
}
