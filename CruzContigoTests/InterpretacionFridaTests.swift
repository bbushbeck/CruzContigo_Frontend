import Testing
@testable import CruzContigo

@MainActor
struct InterpretacionFridaTests {
    @Test func usaLaIntencionDelModeloParaUnaConsultaIndirecta() throws {
        let texto = "Oye Frida dime qué tengo agendado para el siguiente día"
        #expect(ConsultaFrida(texto) == nil)
        let respuesta = try #require(interpretar("recordatorios", periodo: "mañana", pendientes: true))
        let consulta = InterpretacionFrida.resolverConsulta(respuesta, texto: texto, contandoRelato: false)
        #expect(consulta?.tema == .recordatorios)
        #expect(consulta?.periodo == .manana)
        #expect(consulta?.pendientes == true)
    }

    @Test func traduceLaAperturaDeMedicamentosYRequiereVerificarAlFamiliar() throws {
        let respuesta = try #require(interpretar("medicamentos", accion: "abrir", familiar: "Ana"))
        let consulta = respuesta.consulta(para: "¿Puedes abrir lo que toma Ana?", contandoRelato: false)
        #expect(consulta?.tema == .medicamentos)
        #expect(consulta?.abrirPantalla == true)
        #expect(consulta?.mencionaPersona == true)
    }

    @Test func requiereUnaPeticionRealParaMostrarContactos() throws {
        let respuesta = try #require(interpretar("contactosEmergencia"))
        #expect(respuesta.consulta(para: "¿A quién puedo llamar si le pasa algo?", contandoRelato: false)?.tema == .contactosEmergencia)
        #expect(respuesta.consulta(para: "No quiero los contactos, quiero que me escuches.", contandoRelato: false) == nil)
        #expect(respuesta.consulta(para: "Tengo que alimentar a mi familia.", contandoRelato: false) == nil)
    }

    @Test(arguments: [
        "Dame los contactos de emergencia de Mafer",
        "Contactos de emergencia de Mafer",
        "Necesito contactos de emergencia de Mafer",
        "Oye Frida, pásame los teléfonos de emergencia de Mafer",
        "A quién puedo avisarle si le pasa algo a mi mamá"
    ])
    func priorizaLaPeticionDeContactosDuranteUnRelato(_ texto: String) throws {
        let relato = try #require(interpretar("relato"))
        let diario = try #require(interpretar("prepararDiario"))
        let contactos = try #require(interpretar("contactosEmergencia"))
        for modelo in [nil, relato, diario, contactos] {
            let consulta = InterpretacionFrida.resolverConsulta(modelo, texto: texto, contandoRelato: true)
            #expect(consulta?.tema == .contactosEmergencia)
            #expect(consulta?.requiereFamiliar == true)
        }
    }

    @Test(arguments: [
        "Hoy revisé los contactos de emergencia de Mafer",
        "Los contactos de emergencia de Mafer no contestaron",
        "No me des los contactos de emergencia de Mafer",
        "No quiero los contactos de emergencia, solo escúchame",
        "Tengo que llamar a alguien de mi familia"
    ])
    func noAbreContactosSiSoloSeMencionanOSeRechazan(_ texto: String) throws {
        let modelo = try #require(interpretar("contactosEmergencia"))
        #expect(InterpretacionFrida.resolverConsulta(modelo, texto: texto, contandoRelato: true) == nil)
        #expect(InterpretacionFrida.resolverConsulta(nil, texto: texto, contandoRelato: false) == nil)
    }

    @Test func pedirAyudaGeneralAbreLaOrientacionDeCuidado() throws {
        let texto = "Cómo puedo ayudar a Mafer"
        let relato = try #require(interpretar("relato"))
        let orientacion = try #require(interpretar("orientacionCuidado"))
        #expect(BorradorDiarioFrida.esConsultaExplicita(texto))
        #expect(InterpretacionFrida.pideOrientacionDeCuidado(relato, texto: texto))
        #expect(InterpretacionFrida.pideOrientacionDeCuidado(nil, texto: texto))
        #expect(InterpretacionFrida.pideOrientacionDeCuidado(orientacion, texto: "¿Qué opciones de apoyo tiene mi mamá?"))
        #expect(!InterpretacionFrida.pideOrientacionDeCuidado(orientacion, texto: "Me preocupa el cuidado de mi mamá."))
        #expect(InterpretacionFrida.resolverConsulta(orientacion, texto: texto, contandoRelato: true) == nil)
    }

    @Test func reconoceElRelatoAunqueMencioneMedicamentos() throws {
        let mensaje = "Frida, tengo muchas deudas por los medicamentos de mi mamá."
        let relato = try #require(interpretar("relato"))
        let consultaErronea = try #require(interpretar("medicamentos"))
        #expect(InterpretacionFrida.resolverConsulta(relato, texto: mensaje, contandoRelato: false) == nil)
        #expect(InterpretacionFrida.resolverConsulta(consultaErronea, texto: mensaje, contandoRelato: false) == nil)
    }

    @Test func validaCodigosYUsaElRespaldoSiFaltaElModelo() throws {
        #expect(interpretar("enviarDatos") == nil)
        let periodoInvalido = try #require(interpretar("recordatorios", periodo: "ayer"))
        #expect(periodoInvalido.consulta(para: "¿Qué tengo agendado?", contandoRelato: false) == nil)
        let accionInvalida = try #require(interpretar("medicamentos", accion: "eliminar"))
        #expect(accionInvalida.consulta(para: "¿Qué medicamentos toma Ana?", contandoRelato: false) == nil)

        let respaldo = InterpretacionFrida.resolverConsulta(nil, texto: "Mis recordatorios de hoy", contandoRelato: false)
        #expect(respaldo?.tema == .recordatorios)
        #expect(respaldo?.periodo == .hoy)
    }

    @Test func acotaLaInterpretacionDelDiarioYElConsejoMedico() throws {
        let nota = try #require(interpretar("prepararDiario"))
        #expect(nota.autorizaRevision("Hazme un resumen de lo que te conté"))
        #expect(!nota.autorizaRevision("No hagas un resumen"))
        #expect(!nota.autorizaRevision("Hoy escribí una nota en mi diario"))
        let consejo = try #require(interpretar("consejoMedico"))
        #expect(InterpretacionFrida.resolverConsulta(consejo, texto: "¿Puedo cambiar mis medicamentos?", contandoRelato: false) == nil)
    }

    private func interpretar(
        _ intencion: String, periodo: String = "todos", pendientes: Bool = false,
        accion: String = "consultar", familiar: String? = nil
    ) -> InterpretacionFrida? {
        InterpretacionFrida(
            intencion: intencion, periodo: periodo, pendientes: pendientes, accion: accion, familiar: familiar,
            orientacion: SugerenciaNotaFrida(
                categoria: "otro", detalle: "ninguno", tono: "neutral", yaPreguntados: [],
                esRelato: intencion == "relato"
            )
        )
    }
}
