import Foundation
import Testing
@testable import CruzContigo

@MainActor
struct HUFeaturesTests {
    @Test("La ficha conserva los campos de atención y antecedentes")
    func camposFicha() {
        var ficha = FichaMedica(familiarID: UUID(), tipoSanguineo: .oPositivo)
        ficha.medicoTratante = "Dra. López"
        ficha.institucionSalud = "IMSS"
        ficha.antecedentes = "Padre con diabetes"
        #expect(ficha.esValida)
        #expect(ficha.medicoTratante == "Dra. López")
        #expect(ficha.institucionSalud == "IMSS")
        #expect(ficha.antecedentes == "Padre con diabetes")
    }

    @Test("La ficha valida la longitud de antecedentes")
    func antecedentesLargos() {
        var ficha = FichaMedica(familiarID: UUID(), tipoSanguineo: .desconocido)
        ficha.antecedentes = String(repeating: "a", count: 4001)
        #expect(!ficha.esValida)
    }

    @Test("Solo lectura no puede editar")
    func permisos() {
        var familiar = Familiar(nombre: "Ana", apellidos: "López", fechaNacimiento: Date(), parentesco: .madre, tipoCuidado: .adultoMayor)
        familiar.rol = "solo_lectura"
        #expect(!familiar.puedeEditar)
        familiar.rol = "cocuidador"
        #expect(familiar.puedeEditar)
    }

    @Test("La vista simplificada se conserva y puede restablecerse")
    func lecturaFacilPersistente() {
        let nombre = "HUFeaturesTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: nombre) else {
            Issue.record("No se pudo crear UserDefaults de prueba")
            return
        }
        defer { defaults.removePersistentDomain(forName: nombre) }
        let prefs = Preferencias(defaults: defaults)
        prefs.lecturaFacil = true
        #expect(Preferencias(defaults: defaults).lecturaFacil)
        prefs.restablecer()
        #expect(!Preferencias(defaults: defaults).lecturaFacil)
    }

    @Test("Los documentos se guardan, clasifican y eliminan")
    func documentos() throws {
        let familiarID = UUID()
        try DocumentosMedicosRepository.guardar(Data([0, 1, 2]), titulo: "Receta de prueba", extensionArchivo: "jpg", tipo: .receta, familiarID: familiarID)
        let documentos = try DocumentosMedicosRepository.listar(familiarID: familiarID)
        #expect(documentos.count == 1)
        #expect(documentos[0].tipo == .receta)
        #expect(FileManager.default.fileExists(atPath: documentos[0].url.path()))
        try DocumentosMedicosRepository.eliminar(documentos[0])
        #expect(try DocumentosMedicosRepository.listar(familiarID: familiarID).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: documentos[0].url.path()))
    }
}
