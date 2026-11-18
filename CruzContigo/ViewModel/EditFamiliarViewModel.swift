import Foundation
import Observation

@MainActor
@Observable
final class EditFamiliarViewModel {
    private let original: Familiar

    var draft: FamiliarDraft
    var fecha: Date
    var guardando = false
    var error: String?

    init(familiar: Familiar) {
        original = familiar
        fecha = familiar.fechaNacimiento

        var draft = FamiliarDraft()
        draft.nombre = familiar.nombre
        draft.apellidos = familiar.apellidos
        draft.parentesco = familiar.parentesco
        draft.tipoCuidado = familiar.tipoCuidado
        draft.telefono = familiar.telefono ?? ""
        draft.notas = familiar.notas ?? ""
        let componentes = Calendar.current.dateComponents([.day, .month, .year], from: familiar.fechaNacimiento)
        draft.dia = String(componentes.day ?? 1)
        draft.mes = componentes.month
        draft.anio = String(componentes.year ?? 2000)
        self.draft = draft
    }

    func guardar(usando store: FamiliaresStore) async -> Bool {
        let componentes = Calendar.current.dateComponents([.day, .month, .year], from: fecha)
        draft.dia = String(componentes.day ?? 1)
        draft.mes = componentes.month
        draft.anio = String(componentes.year ?? 2000)

        guard var actualizado = draft.construir() else {
            error = draft.errores.values.joined(separator: "\n")
            return false
        }
        actualizado.id = original.id
        actualizado.fechaRegistro = original.fechaRegistro
        actualizado.rol = original.rol

        guardando = true
        defer { guardando = false }
        error = await store.actualizar(actualizado)
        return error == nil
    }
}
