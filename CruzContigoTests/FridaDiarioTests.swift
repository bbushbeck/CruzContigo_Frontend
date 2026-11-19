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
