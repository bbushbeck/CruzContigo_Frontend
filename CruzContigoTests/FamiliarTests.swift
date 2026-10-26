import Foundation
import Testing
@testable import CruzContigo

@MainActor
struct FamiliarTests {
    private func familiar(nombre: String, apellidos: String) -> Familiar {
        Familiar(nombre: nombre, apellidos: apellidos, fechaNacimiento: Date(), parentesco: .madre, tipoCuidado: .adultoMayor)
    }

    @Test("El nombre completo une nombre y apellidos")
    func nombreCompleto() {
        #expect(familiar(nombre: "Ana", apellidos: "López").nombreCompleto == "Ana López")
    }

    @Test("Las iniciales son la primera letra de nombre y apellidos en mayúsculas")
    func iniciales() {
        #expect(familiar(nombre: "ana", apellidos: "lópez").iniciales == "AL")
    }

    @Test("El nombre corto toma solo el primer nombre")
    func nombreCorto() {
        var draft = FamiliarDraft()
        draft.nombre = "  María José "
        #expect(draft.nombreCorto == "María")
    }

    @Test("Los dígitos del teléfono quitan formato y la lada 52")
    func telefonoDigitos() {
        var draft = FamiliarDraft()
        draft.telefono = "+52 81 1234 5678"
        #expect(draft.telefonoDigitos == "8112345678")
    }

    @Test("Una fecha de nacimiento inválida regresa nil")
    func fechaInvalida() {
        var draft = FamiliarDraft()
        draft.dia = "31"
        draft.mes = 2
        draft.anio = "1950"
        #expect(draft.fechaNacimiento == nil)
    }
}
