import Testing
@testable import CruzContigo

@MainActor
struct FridaDiarioTests {
    @Test func transformaLosCodigosEnUnaPreguntaNeutral() {
        let sugerencia = SugerenciaNotaFrida(categoria: "otro", detalle: "duracion", yaPreguntados: [])
        #expect(sugerencia.categoria == .otro)
        #expect(sugerencia.detalle?.pregunta == "¿Cuánto duró?")

        let respuestaFueraDelEsquema = SugerenciaNotaFrida(
            categoria: "diagnóstico", detalle: "sugiere un tratamiento", yaPreguntados: []
        )
        #expect(!respuestaFueraDelEsquema.tieneContenido)
    }

    @Test func agregaRespuestasAlBorradorYSigueUnaVez() throws {
        var conversacion = ConversacionNotaFrida()
        let nota = "Hoy salimos a caminar."
        let notaConDuracion = conversacion.agregar("  Unos 40 minutos. ", a: .duracion, en: nota)
        let primera = try #require(notaConDuracion)
        #expect(primera == "Hoy salimos a caminar.\nUnos 40 minutos.")
        #expect(conversacion.puedeContinuar)
        #expect(conversacion.detallesPreguntados == [.duracion])

        let repetida = SugerenciaNotaFrida(
            categoria: "otro", detalle: "duracion", yaPreguntados: conversacion.detallesPreguntados
        )
        #expect(repetida.detalle == nil)

        let notaConLugar = conversacion.agregar("Fuimos al parque.", a: .lugar, en: primera)
        let segunda = try #require(notaConLugar)
        #expect(segunda.hasSuffix("\nFuimos al parque."))
        #expect(!conversacion.puedeContinuar)
        let tercera = conversacion.agregar("A las seis", a: .hora, en: segunda)
        #expect(tercera == nil)
    }

    @Test func preparaUnaNotaDelChatSinGuardarAutomaticamente() {
        let texto = "Hoy salí a caminar."
        #expect(BorradorDiarioFrida.esRelatoCotidiano(texto))
        #expect(BorradorDiarioFrida.esRelatoCotidiano("Me siento sola."))
        #expect(!BorradorDiarioFrida.esRelatoCotidiano("¿Qué medicamentos tomo hoy?"))
        #expect(!BorradorDiarioFrida.esRelatoCotidiano("Hola"))

        var borrador = BorradorDiarioFrida(texto: texto)
        let inicial = borrador.sugerenciaLocal()
        borrador.aplicar(inicial)
        #expect(borrador.pregunta == .duracion)
        let aceptada = borrador.responder("Duró 40 minutos.")
        #expect(aceptada)
        let seguimiento = borrador.sugerenciaLocal()
        borrador.aplicar(seguimiento)
        #expect(borrador.pregunta == .lugar)
        #expect(borrador.nota.texto == "Hoy salí a caminar.\nDuró 40 minutos.")
        #expect(borrador.nota.esValida)
    }

    @Test func dejaDePreguntarSinAgregarElRechazoALaNota() {
        var borrador = BorradorDiarioFrida(texto: "Hoy salí a caminar.")
        let inicial = borrador.sugerenciaLocal()
        borrador.aplicar(inicial)
        #expect(BorradorDiarioFrida.quiereTerminar("No, gracias."))
        borrador.terminarPreguntas()
        #expect(borrador.pregunta == nil)
        #expect(borrador.nota.texto == "Hoy salí a caminar.")
    }

    @Test func descartaRespuestasVaciasOLargasSinModificarLaConversacion() {
        var conversacion = ConversacionNotaFrida()
        let notaLlena = String(repeating: "a", count: SolicitudNota.largoMaximo)
        let vacia = conversacion.agregar("  ", a: .hora, en: "Hoy salimos.")
        let larga = conversacion.agregar("A las seis", a: .hora, en: notaLlena)
        #expect(vacia == nil)
        #expect(larga == nil)
        #expect(conversacion.turnos.isEmpty)
    }
}
