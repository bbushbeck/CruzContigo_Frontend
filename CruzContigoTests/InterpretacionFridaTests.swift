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
