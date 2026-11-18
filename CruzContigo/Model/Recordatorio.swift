import Foundation

struct DatosRecordatorio: Encodable {
    var titulo: String
    var familiarID: UUID
    var fecha: Date
    var completado = false
}

struct Recordatorio: Decodable, Identifiable {
    let id: UUID
    let titulo: String
    let familiarID: UUID
    let fecha: Date
    let completado: Bool

    var datos: DatosRecordatorio {
        DatosRecordatorio(titulo: titulo, familiarID: familiarID, fecha: fecha, completado: completado)
    }

    var fechaCorta: String {
        fecha.formatted(.dateTime.day().month().hour().minute().locale(Locale(identifier: "es_MX")))
    }
}
