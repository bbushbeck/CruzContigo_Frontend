import Foundation
import Testing
@testable import CruzContigo

@MainActor
struct ConsultaFridaTests {
    @Test func interpretaConsultasEnEspanol() {
        let medicamentos = ConsultaFrida("¿QUÉ MEDICAMENTOS toma mi mamá hoy?")
        #expect(medicamentos?.tema == .medicamentos)
        #expect(medicamentos?.periodo == .hoy)
        #expect(medicamentos?.abrirPantalla == false)
        #expect(ConsultaFrida("¿Qué toma mi mamá?")?.tema == .medicamentos)

        let recordatorios = ConsultaFrida("Recuérdame mis avisos de medicamentos pendientes de mañana")
        #expect(recordatorios?.tema == .recordatorios)
        #expect(recordatorios?.periodo == .manana)
        #expect(recordatorios?.pendientes == true)
        #expect(ConsultaFrida("¿Qué tengo hoy?")?.tema == .recordatorios)
    }

    @Test func distingueNavegacionYCambios() {
        #expect(ConsultaFrida("Llévame a Recordatorios")?.abrirPantalla == true)
        #expect(ConsultaFrida("Medicamentos y recordatorios") == nil)
        #expect(ConsultaFrida.pideCambios("Elimina un recordatorio"))
        #expect(ConsultaFrida.pideConsejoMedico("¿Qué medicamento le doy?"))
    }

    @Test func seleccionaPorNombreCompletoOParentesco() {
        let madre = Familiar(nombre: "María", apellidos: "López", fechaNacimiento: .now,
                             parentesco: .madre, tipoCuidado: .otro)
        let hermana = Familiar(nombre: "María", apellidos: "Pérez", fechaNacimiento: .now,
                               parentesco: .hermana, tipoCuidado: .otro)
        let personas = [madre, hermana]
        #expect(ConsultaFrida.coincidencias("Medicinas de mi mamá", familiares: personas) == [madre])
        #expect(ConsultaFrida.coincidencias("Medicinas de Maria Perez", familiares: personas) == [hermana])
        #expect(ConsultaFrida.coincidencias("Medicinas de María", familiares: personas) == personas)
        #expect(ConsultaFrida.mencionaFamiliar("Medicamentos de Ana"))
        #expect(!ConsultaFrida.mencionaFamiliar("Recordatorios de hoy, por favor"))
        #expect(!ConsultaFrida.mencionaFamiliar("Recordatorios de medicamentos"))
    }
}
