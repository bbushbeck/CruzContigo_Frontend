import Foundation

struct SugerenciaNotaFrida: Equatable {
    enum Detalle: String {
        case hora, duracion, lugar, observacion

        var pregunta: String {
            switch self {
            case .hora: "¿Quieres agregar a qué hora pasó?"
            case .duracion: "¿Cuánto duró?"
            case .lugar: "¿Dónde fue?"
            case .observacion: "¿Qué otro detalle te gustaría anotar?"
            }
        }
    }

    let categoria: CategoriaNota?
    let detalle: Detalle?

    init(categoria: String, detalle: String, yaPreguntados: Set<Detalle>) {
        self.categoria = CategoriaNota(rawValue: categoria)
        self.detalle = Detalle(rawValue: detalle).flatMap { yaPreguntados.contains($0) ? nil : $0 }
    }

    var tieneContenido: Bool { categoria != nil || detalle != nil }
}

struct ConversacionNotaFrida {
    struct Turno: Identifiable {
        let detalle: SugerenciaNotaFrida.Detalle
        let respuesta: String

        var id: SugerenciaNotaFrida.Detalle { detalle }
    }

    private(set) var turnos: [Turno] = []
    var detallesPreguntados: Set<SugerenciaNotaFrida.Detalle> { Set(turnos.map(\.detalle)) }
    var puedeContinuar: Bool { turnos.count < 2 }

    func notaConRespuesta(_ respuesta: String, en nota: String) -> String? {
        let limpia = respuesta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpia.isEmpty else { return nil }
        let resultado = nota + "\n" + limpia
        return resultado.count <= SolicitudNota.largoMaximo ? resultado : nil
    }

    mutating func agregar(
        _ respuesta: String, a detalle: SugerenciaNotaFrida.Detalle, en nota: String
    ) -> String? {
        guard puedeContinuar, !detallesPreguntados.contains(detalle),
              let actualizada = notaConRespuesta(respuesta, en: nota) else { return nil }
        turnos.append(Turno(detalle: detalle, respuesta: respuesta.trimmingCharacters(in: .whitespacesAndNewlines)))
        return actualizada
    }
}
