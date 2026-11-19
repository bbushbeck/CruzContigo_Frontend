import Testing
@testable import CruzContigo

@MainActor
struct ApoyoFridaTests {
    @Test(arguments: [
        "Me quiero matar", "Quiero matarme", "Me voy a suicidar", "Quiero quitarme la vida",
        "Ya no quiero vivir", "A veces pienso en matarme", "Frida solo escúchame, me quiero morir",
        "No, quiero morir", "Me quiero hacer daño", "Me voy a lastimar", "Quisiera no despertar"
    ])
    func reconoceExpresionesDeDano(_ texto: String) {
        #expect(ApoyoFrida.detectar(en: texto) == .hacerseDano)
    }

    @Test(arguments: [
        "Me tomé todas las pastillas", "No estoy a salvo", "Me están golpeando",
        "Me acabo de hacer daño", "Me quiero morir y ya me tomé muchas pastillas"
    ])
    func priorizaElPeligroInmediato(_ texto: String) {
        #expect(ApoyoFrida.detectar(en: texto) == .peligroInmediato)
    }

    @Test(arguments: [
        "Tengo que alimentar a mi familia y no tengo dinero",
        "Hoy tuve un día horrible y estoy muy triste",
        "No me quiero matar", "No quiero morir", "Me quiero morir de risa",
        "¿Qué significa la frase me quiero matar?", "Me están acompañando y estoy a salvo"
    ])
    func distingueElDesahogoYLasNegaciones(_ texto: String) {
        #expect(ApoyoFrida.detectar(en: texto) == nil)
    }

    @Test func distingueUnaPeticionRealDeUnaExpresionDeAgobio() {
        let desahogo = "No he acabado tengo muchas cosas tengo que alimentar a mi familia"
        #expect(IntencionEscuchaFrida.pideEscucha(desahogo))
        #expect(!IntencionEscuchaFrida.soloPideEscucha(desahogo))
        #expect(ConsultaFrida(desahogo) == nil)

        let rechazo = "Yo no quiero los contactos yo quiero que me escuches"
        #expect(IntencionEscuchaFrida.soloPideEscucha(rechazo))
        #expect(ConsultaFrida(rechazo) == nil)

        let pregunta = "¿A quién puedo avisarle si le pasa algo a mi mamá?"
        #expect(ConsultaFrida(pregunta)?.tema == .contactosEmergencia)
    }

    @Test func respondeAlTemaDelUltimoMensaje() {
        let texto = "Mañana tengo que ir por mis hijos a la escuela y no tengo dinero."
        let borrador = BorradorDiarioFrida(texto: texto)
        let respuesta = borrador.sugerenciaLocal(ultimoMensaje: texto)
        #expect(respuesta.respuesta(para: texto) == "La preocupación por el dinero puede pesar mucho.")
        #expect(respuesta.detalle == .quePesa)
        #expect(respuesta.convieneSeguirEscuchando(texto))
    }
}
