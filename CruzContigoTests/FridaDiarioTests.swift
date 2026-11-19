import Testing
@testable import CruzContigo

@MainActor
struct FridaDiarioTests {
    @Test func entiendeUnaEntradaDeConversacionYRespondeConEmpatia() {
        let texto = "Ay Frida, hoy tuve un día muy difícil."
        #expect(BorradorDiarioFrida.esRelatoCotidiano(texto))
        #expect(BorradorDiarioFrida.esRelatoCotidiano("Me siento sola."))
        #expect(!BorradorDiarioFrida.esRelatoCotidiano("¿Qué medicamentos tomo hoy?"))

        var borrador = BorradorDiarioFrida(texto: texto)
        let orientacion = borrador.sugerenciaLocal(ultimoMensaje: texto)
        let pregunta = borrador.elegirPregunta(orientacion)
        #expect(orientacion.tono == .dificil)
        #expect(pregunta == .quePaso)
        let ofreceAlInicio = borrador.ofrecerResumen()
        #expect(!ofreceAlInicio)
        #expect(!borrador.muestraOferta)
    }

    @Test func mantieneLaConversacionYOfreceResumenUnaSolaVez() {
        var borrador = BorradorDiarioFrida(texto: "Hoy salí a caminar.")
        let primera = borrador.sugerenciaLocal(ultimoMensaje: borrador.nota.texto)
        let primeraPregunta = borrador.elegirPregunta(primera)
        #expect(primeraPregunta == .duracion)
        let aceptada = borrador.agregar("Duró 40 minutos.")
        #expect(aceptada)
        let segunda = borrador.sugerenciaLocal(ultimoMensaje: "Duró 40 minutos.")
        let segundaPregunta = borrador.elegirPregunta(segunda)
        #expect(segundaPregunta == .lugar)
        let ofreceTrasDos = borrador.ofrecerResumen()
        #expect(!ofreceTrasDos)
        let agregoLugar = borrador.agregar("Fui al parque.")
        #expect(agregoLugar)
        let ofreceTrasTres = borrador.ofrecerResumen()
        #expect(ofreceTrasTres)
        #expect(borrador.muestraOferta)

        borrador.descartarOferta()
        let continua = borrador.agregar("Vi a una amiga.")
        #expect(continua)
        let vuelveAOfrecer = borrador.ofrecerResumen(alCerrar: true)
        #expect(!vuelveAOfrecer)
        #expect(!borrador.muestraOferta)
    }

    @Test func reconoceElCierreYElPedidoDeGuardar() {
        #expect(BorradorDiarioFrida.quiereCerrar("Eso es todo."))
        #expect(!BorradorDiarioFrida.quiereCerrar("No recuerdo."))
        #expect(BorradorDiarioFrida.quiereOmitir("No, gracias."))
        #expect(BorradorDiarioFrida.pideGuardar("Guarda esto en mi diario."))
        #expect(BorradorDiarioFrida.pideGuardar("Frida, guárdalo."))
        #expect(!BorradorDiarioFrida.pideGuardar("Hoy guardé una nota en mi diario."))
        #expect(BorradorDiarioFrida.esConsultaExplicita("Muéstrame los medicamentos"))
        #expect(!BorradorDiarioFrida.esConsultaExplicita("Mi hija me acompañó a la cita."))

        var borrador = BorradorDiarioFrida(texto: "Hoy me sentí bien.")
        let ofreceAlCerrar = borrador.ofrecerResumen(alCerrar: true)
        #expect(ofreceAlCerrar)
        #expect(borrador.nota.texto == "Hoy me sentí bien.")
    }

    @Test func elResumenEsEditableYPreservaElRelatoOriginalComoRespaldo() {
        var borrador = BorradorDiarioFrida(texto: "Hoy salí a caminar.")
        let agrego = borrador.agregar("Fui al parque.")
        #expect(agrego)
        let propuesta = borrador.notaParaRevision(resumen: "  Hoy caminé en el parque.  ")
        #expect(propuesta.texto == "Hoy caminé en el parque.")
        #expect(propuesta.esValida)
        #expect(borrador.nota.texto == "Hoy salí a caminar.\nFui al parque.")
        #expect(borrador.notaParaRevision(resumen: nil) == borrador.nota)
        #expect(borrador.notaParaRevision(resumen: " ") == borrador.nota)
        #expect(borrador.notaParaRevision(resumen: String(repeating: "a", count: SolicitudNota.largoMaximo + 1)) == borrador.nota)
    }

    @Test func conservaPreguntasYRespuestasDentroDeLasOpcionesPermitidas() {
        let fueraDelEsquema = SugerenciaNotaFrida(
            categoria: "diagnóstico", detalle: "sugiere un tratamiento", tono: "indicación", yaPreguntados: []
        )
        #expect(fueraDelEsquema.categoria == nil)
        #expect(fueraDelEsquema.detalle == nil)
        #expect(fueraDelEsquema.tono == .neutral)

        let repetida = SugerenciaNotaFrida(categoria: "otro", detalle: "lugar", tono: "neutral", yaPreguntados: [.lugar])
        #expect(repetida.detalle == nil)

        var borrador = BorradorDiarioFrida(texto: String(repeating: "a", count: SolicitudNota.largoMaximo))
        let vacia = borrador.agregar("  ")
        let larga = borrador.agregar("Un detalle más.")
        #expect(!vacia)
        #expect(!larga)
        #expect(borrador.intervenciones == 1)
    }
}
