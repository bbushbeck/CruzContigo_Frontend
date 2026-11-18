import Foundation
import Testing
@testable import CruzContigo

@MainActor
struct FichaEmergenciaTests {
    private func familiar(telefono: String? = "8112345678") -> Familiar {
        var familiar = Familiar(nombre: "Rosa", apellidos: "López", fechaNacimiento: Date(), parentesco: .madre, tipoCuidado: .adultoMayor)
        familiar.telefono = telefono
        return familiar
    }

    private func formulario(_ ficha: FichaMedica? = nil) -> EditFichaMedicaViewModel {
        EditFichaMedicaViewModel(ficha: ficha ?? FichaMedica(familiarID: UUID())) { _ in nil }
    }

    // MARK: - Formulario por pasos

    @Test("Una ficha nueva empieza sin respuestas y sin cambios")
    func fichaNueva() {
        let viewModel = formulario()
        #expect(viewModel.esNueva)
        #expect(viewModel.tieneAlergias == nil)
        #expect(!viewModel.hayCambios)
        #expect(viewModel.paso == .sangre)
    }

    @Test("«No lo sé» no bloquea: sin tipo de sangre se guarda como desconocido")
    func sangreOpcional() {
        let viewModel = formulario()
        #expect(viewModel.fichaFinal.tipoSanguineo == .desconocido)
        #expect(viewModel.fichaFinal.esValida)
    }

    @Test("No se avanza en alergias sin contestar Sí o No")
    func alergiasRequierenRespuesta() {
        let viewModel = formulario()
        viewModel.paso = .alergias
        #expect(!viewModel.siguiente())
        #expect(viewModel.mostrarError)
        viewModel.tieneAlergias = false
        #expect(viewModel.siguiente())
        #expect(viewModel.paso == .enfermedades)
    }

    @Test("Tocar una sugerencia la agrega y tocarla otra vez la quita")
    func alternarSugerencias() {
        let viewModel = formulario()
        viewModel.tieneAlergias = true
        viewModel.alternarAlergia("Penicilina")
        #expect(viewModel.tieneAlergia("penicilina"))
        viewModel.alternarAlergia("PENICILINA")
        #expect(viewModel.ficha.alergias.isEmpty)
    }

    @Test("Lo escrito en «Otra» se agrega aunque no se toque Agregar")
    func agregaPendientes() {
        let viewModel = formulario()
        viewModel.paso = .alergias
        viewModel.otraAlergia = "Nuez"
        #expect(viewModel.siguiente())
        #expect(viewModel.tieneAlergias == true)
        #expect(viewModel.tieneAlergia("Nuez"))
        #expect(viewModel.otraAlergia.isEmpty)
    }

    @Test("Contestar No deja la lista vacía al guardar")
    func noLimpiaLista() {
        var ficha = FichaMedica(familiarID: UUID(), tipoSanguineo: .oPositivo)
        ficha.alergias = [Alergia(nombre: "Látex", severidad: .grave)]
        let viewModel = formulario(ficha)
        #expect(viewModel.tieneAlergias == true)
        viewModel.tieneAlergias = false
        #expect(viewModel.fichaFinal.alergias.isEmpty)
        #expect(viewModel.hayCambios)
    }

    @Test("La severidad usa lenguaje cotidiano")
    func severidadCotidiana() {
        #expect(Severidad.grave.titulo == "Peligrosa")
        #expect(Severidad.grave.descripcion.contains("peligroso"))
    }

    @Test("La ficha indica qué datos importantes faltan")
    func datosPendientes() {
        let ficha = FichaMedica(familiarID: UUID(), tipoSanguineo: .desconocido)
        #expect(ficha.datosPendientes.contains("tipo de sangre"))
        #expect(!ficha.tieneDetalles)
    }

    // MARK: - Ficha de emergencia (HU-19)

    @Test("El resumen incluye solo medicamentos activos y el teléfono de la persona")
    func resumenEmergencia() {
        let persona = familiar()
        var ficha = FichaMedica(familiarID: persona.id, tipoSanguineo: .aPositivo)
        ficha.alergias = [Alergia(nombre: "Penicilina", severidad: .grave)]
        let medicamentos = [
            Medication(recipientID: persona.id, name: "Metformina", dose: "850", unit: "mg", frequency: "Cada 12 horas", startDate: "2026-01-01"),
            Medication(recipientID: persona.id, name: "Amoxicilina", dose: "500", startDate: "2025-01-01", endDate: "2025-01-10"),
        ]
        let resumen = FichaEmergencia.generar(familiar: persona, ficha: ficha, medicamentos: medicamentos, qrConsentido: false)
        #expect(resumen.medicamentos.map(\.nombre) == ["Metformina"])
        #expect(resumen.contactos.first?.telefono == "8112345678")
        #expect(resumen.tipoSanguineo == .aPositivo)
        #expect(!resumen.qrConsentido)
    }

    @Test("El texto del QR marca las alergias peligrosas y tiene un tamaño legible")
    func textoQR() {
        let persona = familiar(telefono: nil)
        var ficha = FichaMedica(familiarID: persona.id, tipoSanguineo: .oNegativo)
        ficha.alergias = [Alergia(nombre: "Penicilina", severidad: .grave), Alergia(nombre: "Polen", severidad: .leve)]
        ficha.observaciones = String(repeating: "x", count: 2000)
        let resumen = FichaEmergencia.generar(familiar: persona, ficha: ficha, medicamentos: [], qrConsentido: true)
        #expect(resumen.textoQR.contains("Penicilina (PELIGROSA)"))
        #expect(resumen.textoQR.contains("Sangre: O-"))
        #expect(resumen.textoQR.count <= 1200)
        #expect(resumen.contactos.isEmpty)
    }

    @Test("Sin ficha médica el resumen dice que no hay alergias conocidas")
    func sinFicha() {
        let resumen = FichaEmergencia.generar(familiar: familiar(), ficha: nil, medicamentos: [], qrConsentido: false)
        #expect(resumen.alergias.isEmpty)
        #expect(resumen.textoQR.contains("Ninguna conocida"))
    }

    @Test("El historial entiende el consentimiento del QR")
    func accionQR() throws {
        let json = """
        {"id":"6f1c2b8e-1d2a-4c3b-9e8f-0a1b2c3d4e5f","accion":"compartir_qr","rol":"administrador","versionAviso":"2026-11",
        "fecha":"2026-11-17T18:00:00Z","otorgadoPor":{"nombre":"Ana","telefono":null},"usuario":{"nombre":"Ana","telefono":null}}
        """
        let registro = try APIClient.decoder.decode(RegistroConsentimiento.self, from: Data(json.utf8))
        #expect(registro.accion == .compartirQR)
        #expect(registro.descripcion.contains("código QR"))
    }
}
