import Foundation
import Testing
@testable import CruzContigo

@MainActor
struct AtajosFridaTests {
    @Test func laPreguntaSeEntregaUnaVezInclusoSiSeRepiteElTexto() throws {
        let solicitudes = SolicitudesDeFrida()
        solicitudes.abrir(pregunta: "  ¿Qué recordatorios tengo hoy?  ")
        let primera = try #require(solicitudes.tomarSolicitud())
        #expect(primera.pregunta == "¿Qué recordatorios tengo hoy?")
        #expect(solicitudes.tomarSolicitud() == nil)

        solicitudes.abrir(pregunta: "¿Qué recordatorios tengo hoy?")
        let segunda = try #require(solicitudes.tomarSolicitud())
        #expect(segunda.id != primera.id)

        solicitudes.abrir()
        let abrirChat = try #require(solicitudes.tomarSolicitud())
        #expect(abrirChat.pregunta == nil)
    }

    @Test func siriUsaElDiaLocalYLeeLosRecordatoriosEnOrden() throws {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = try #require(TimeZone(identifier: "America/Monterrey"))
        let ahora = try Date("2026-11-20T01:00:00Z", strategy: .iso8601)
        let temprano = try recordatorio("Llamar a Ana", "2026-11-19T06:30:00Z", completado: true)
        let noche = try recordatorio("Preparar la cena", "2026-11-20T03:00:00Z")
        let anterior = try recordatorio("De ayer", "2026-11-19T05:59:59Z")
        let siguiente = try recordatorio("De mañana", "2026-11-20T06:00:00Z")
        let recordatorios = [siguiente, noche, anterior, temprano]

        let resumen = ResumenRecordatoriosFrida.paraSiri(recordatorios, ahora: ahora, calendario: calendario)
        #expect(resumen.hasPrefix("Hoy tienes 2 recordatorios."))
        #expect(!resumen.contains("De ayer"))
        #expect(!resumen.contains("De mañana"))
        let primeraFila = try #require(resumen.range(of: "Llamar a Ana, completado"))
        let ultimaFila = try #require(resumen.range(of: "Preparar la cena"))
        #expect(primeraFila.lowerBound < ultimaFila.lowerBound)
        let pendientes = ResumenRecordatoriosFrida.filtrar(
            recordatorios, periodo: .hoy, pendientes: true, ahora: ahora, calendario: calendario
        )
        #expect(pendientes.map(\.id) == [noche.id])
    }

    @Test func elResumenHabladoManejaLaListaVaciaYLimitaElDetalle() throws {
        let ahora = try Date("2026-11-19T14:00:00Z", strategy: .iso8601)
        let muchos = try (1...6).map { try recordatorio("Actividad \($0)", "2026-11-19T14:0\($0):00Z") }
        let resumen = ResumenRecordatoriosFrida.paraSiri(muchos, ahora: ahora)
        #expect(ResumenRecordatoriosFrida.paraSiri([], ahora: ahora) == "No tienes recordatorios para hoy.")
        #expect(resumen.contains("Hoy tienes 6 recordatorios."))
        #expect(resumen.contains("Actividad 5"))
        #expect(!resumen.contains("Actividad 6"))
        #expect(resumen.hasSuffix("Hay uno más en CruzContigo."))
    }

    private func recordatorio(_ titulo: String, _ fechaISO: String, completado: Bool = false) throws -> Recordatorio {
        Recordatorio(
            id: UUID(), titulo: titulo, familiarID: UUID(),
            fecha: try Date(fechaISO, strategy: .iso8601), completado: completado
        )
    }
}
