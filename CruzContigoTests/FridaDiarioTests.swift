import Foundation
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
        #expect(PedidoDiarioFrida("Guarda esto en mi diario.")?.accion == .guardar)
        #expect(PedidoDiarioFrida("Frida, guárdalo.")?.accion == .guardar)
        #expect(PedidoDiarioFrida("Hoy guardé una nota en mi diario.") == nil)
        #expect(BorradorDiarioFrida.esConsultaExplicita("Muéstrame los medicamentos"))
        #expect(!BorradorDiarioFrida.esConsultaExplicita("Mi hija me acompañó a la cita."))

        var borrador = BorradorDiarioFrida(texto: "Hoy me sentí bien.")
        let ofreceAlCerrar = borrador.ofrecerResumen(alCerrar: true)
        #expect(ofreceAlCerrar)
        #expect(borrador.nota.texto == "Hoy me sentí bien.")
    }

    @Test(arguments: [
        "Puedes guardar esto en notas",
        "Qué lo guardes en notas",
        "Guarda lo que te acabo de decir de Ana y su antojo en notas",
        "Oye Frida, ¿podrías anotarlo en el diario?",
        "Sí, guárdalo, por favor"
    ])
    func reconocePedidosDictadosSinIncluirLaOrdenEnLaNota(_ texto: String) {
        let pedido = PedidoDiarioFrida(texto)
        #expect(pedido?.accion == .guardar)
        #expect(pedido?.contenido == nil)
    }

    @Test func separaElDatoNuevoDelPedidoDeGuardar() throws {
        let dictado = try #require(PedidoDiarioFrida(
            "Y creo que debería de anotarlo que no ha estado comiendo bien puedes guardarlo en notas"
        ))
        #expect(dictado.accion == .guardar)
        #expect(dictado.contenido == "no ha estado comiendo bien")
        #expect(dictado.referencia == "puedes guardarlo en notas")
        #expect(PedidoDiarioFrida("No ha comido bien. ¿Puedes guardarlo en notas?")?.contenido == "No ha comido bien")
        #expect(PedidoDiarioFrida("Anota en el diario que hoy salí a caminar.")?.contenido == "hoy salí a caminar.")
        #expect(PedidoDiarioFrida("Anota que hoy salí a caminar.")?.contenido == "hoy salí a caminar.")
        #expect(PedidoDiarioFrida("Hazme un resumen de lo que te conté")?.accion == .revisar)
        #expect(PedidoDiarioFrida("No quiero que lo guardes en notas") == nil)
        #expect(PedidoDiarioFrida("No te estoy pidiendo que lo guardes en notas") == nil)
        #expect(PedidoDiarioFrida("Mi hermana me dijo que lo guardes en notas") == nil)
        #expect(PedidoDiarioFrida("Ana guarda sus citas en el diario") == nil)
        #expect(PedidoDiarioFrida("No sé cómo guardar esto en notas") == nil)
        #expect(PedidoDiarioFrida("Guarda mis medicamentos") == nil)
    }

    @Test func guardarDirectoRequiereUnDiarioIdentificadoYDisponible() throws {
        let ana = Familiar(nombre: "Ana", apellidos: "López", fechaNacimiento: .now, parentesco: .madre, tipoCuidado: .adultoMayor)
        let eli = Familiar(nombre: "Eli", apellidos: "Gil", fechaNacimiento: .now, parentesco: .hermana, tipoCuidado: .adultoMayor)
        let pedido = try #require(PedidoDiarioFrida("Puedes guardarlo en notas"))
        #expect(pedido.destinoUnico(relato: "Ana no ha comido bien", personas: [ana, eli], diariosDisponibles: [ana, eli], recibeCuidados: false)?.id == ana.id)
        #expect(pedido.destinoUnico(relato: "Ana y Eli salieron hoy", personas: [ana, eli], diariosDisponibles: [ana], recibeCuidados: false) == nil)
        #expect(pedido.destinoUnico(relato: "Ana no ha comido bien", personas: [ana, eli], diariosDisponibles: [eli], recibeCuidados: false) == nil)
        let destinoDistinto = try #require(PedidoDiarioFrida("Guárdalo en el diario de Sol"))
        #expect(destinoDistinto.destinoUnico(relato: "Ana no ha comido bien", personas: [ana, eli], diariosDisponibles: [ana, eli], recibeCuidados: false) == nil)

        var titular = eli
        titular.rol = RolAcceso.titular.rawValue
        let propio = try #require(PedidoDiarioFrida("Guárdalo en mi diario"))
        #expect(propio.destinoUnico(relato: "Hoy salí a caminar", personas: [ana, titular], diariosDisponibles: [ana, titular], recibeCuidados: true)?.id == titular.id)
        #expect(pedido.destinoUnico(relato: "Hoy salí a caminar", personas: [ana, titular], diariosDisponibles: [ana, titular], recibeCuidados: true)?.id == titular.id)
        #expect(destinoDistinto.destinoUnico(relato: "Hoy salí a caminar", personas: [ana, titular], diariosDisponibles: [ana, titular], recibeCuidados: true) == nil)
    }

    @Test func elResumenConservaElTextoYElOrdenDelRelato() {
        var borrador = BorradorDiarioFrida(texto: "Hoy salí a caminar.")
        let dijoLugar = borrador.agregar("Fui al parque.")
        let agregoRelleno = borrador.agregar("Qué más te iba a contar.")
        #expect(dijoLugar)
        #expect(agregoRelleno)
        let propuesta = borrador.notaParaRevision(seleccion: [2, 1, 1])
        #expect(propuesta.texto == "Hoy salí a caminar.\nFui al parque.")
        #expect(propuesta.esValida)
        #expect(borrador.nota.texto.hasSuffix("Qué más te iba a contar."))
        #expect(borrador.notaParaRevision(seleccion: nil) == borrador.nota)
        #expect(borrador.notaParaRevision(seleccion: []) == borrador.nota)
        #expect(borrador.notaParaRevision(seleccion: [0, 4]) == borrador.nota)
    }

    @Test func separaElNombreDelAsistenteDeQuienCuentaElRelato() {
        let texto = "Frida tengo muchas deudas por los medicamentos de mi mamá. Hoy fue difícil y estoy triste."
        #expect(BorradorDiarioFrida.esRelatoCotidiano(texto))
        let borrador = BorradorDiarioFrida(texto: texto)
        let propuesta = borrador.notaParaRevision(seleccion: [1])
        #expect(propuesta.texto == "Tengo muchas deudas por los medicamentos de mi mamá. Hoy fue difícil y estoy triste.")

        let mascota = "Frida, mi perrita, salió a caminar conmigo."
        #expect(FragmentosRelatoFrida.sinVocativo(mascota) == mascota)
        #expect(FragmentosRelatoFrida.sinVocativo("Frida salió a caminar.") == "Frida salió a caminar.")
        #expect(FragmentosRelatoFrida.sinVocativo("Ay, Frida, hoy estuve triste.") == "Hoy estuve triste.")
        #expect(FragmentosRelatoFrida.sinVocativo("Frida salí a caminar.") == "Salí a caminar.")
    }

    @Test func evitaOmitirCorreccionesYAntecedentes() {
        let relato = "Mi mamá no ha comido bien.\nDesde hace una semana.\nMe preocupa."
        let parte = FragmentosRelatoFrida(relato)
        #expect(parte.resumen(seleccion: [1, 3]) == relato)
        #expect(parte.resumen(seleccion: [2, 3]) == relato)

        let cambioDeContexto = FragmentosRelatoFrida("Mi hermana me acompañó.\nElla estaba contenta.")
        #expect(cambioDeContexto.resumen(seleccion: [2]) == "Mi hermana me acompañó.\nElla estaba contenta.")
    }

    @Test func haceSeguimientoNaturalCuandoUnFamiliarComePoco() {
        let texto = "Últimamente no tiene antojo mi hermana, no ha comido bien y me preocupa."
        let preguntaDelModelo = SugerenciaNotaFrida(categoria: "alimentacion", detalle: "hora", tono: "dificil", yaPreguntados: [])
        #expect(BorradorDiarioFrida.esRelatoCotidiano(texto))
        #expect(preguntaDelModelo.respuesta(para: texto) == "Entiendo que te preocupe cómo ha estado comiendo.")

        var borrador = BorradorDiarioFrida(texto: texto)
        let pregunta = borrador.elegirPregunta(preguntaDelModelo, ultimoMensaje: texto)
        #expect(pregunta == .desdeCuando)
        #expect(borrador.nota.categoria == .alimentacion)

        let conDuracion = "No ha comido bien desde hace una semana."
        var otroBorrador = BorradorDiarioFrida(texto: conDuracion)
        let otraPregunta = otroBorrador.elegirPregunta(preguntaDelModelo, ultimoMensaje: conDuracion)
        #expect(otraPregunta == .quePesa)
    }

    @Test func usaLaConversacionCompletaParaEvitarPreguntarYResponderLoMismo() throws {
        let inicial = "No ha estado comiendo bien últimamente en esta última semana"
        let seguimiento = "Realmente no se le antoja nada y sí me preocupa mucho"
        let aclaracion = "Según yo desde la última semana lleva así, no sé si lleva más tiempo"
        let orientacion = SugerenciaNotaFrida(
            categoria: "alimentacion", detalle: "desdeCuando", tono: "dificil",
            yaPreguntados: [], temaEscucha: "alimentacion", enfoque: "reconocerDetalle"
        )
        var borrador = BorradorDiarioFrida(texto: inicial)
        for (indice, mensaje) in [inicial, seguimiento, aclaracion].enumerated() {
            if indice > 0 {
                let agregado = borrador.agregar(mensaje)
                try #require(agregado)
            }
            let pregunta = borrador.elegirPregunta(orientacion, ultimoMensaje: mensaje, sugeridaPorModelo: true)
            #expect(pregunta == nil)
            let respuesta = borrador.responder(orientacion, texto: mensaje, pregunta: pregunta)
            #expect(!respuesta.isEmpty)
        }
        #expect(borrador.detallesCubiertos.contains(.desdeCuando))
        #expect(borrador.detallesCubiertos.contains(.quePesa))
        #expect(borrador.respuestasDadas.first?.contains("última semana") == true)
        #expect(Set(borrador.respuestasDadas).count == 3)
    }

    #if canImport(FoundationModels)
    @Test func adaptaLaOrientacionEstructuradaDeFoundationModels() {
        let respuesta = OrientacionDelModeloFrida(
            categoria: "alimentacion", detalle: "desdeCuando", tono: "dificil",
            tema: "alimentacion", enfoque: "reconocerDetalle"
        )
        let orientacion = SugerenciaNotaFrida(respuesta, detallesCubiertos: [.desdeCuando], esRelato: true)
        #expect(orientacion.categoria == .alimentacion)
        #expect(orientacion.detalle == nil)
        #expect(orientacion.enfoque == .reconocerDetalle)
    }
    #endif

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
