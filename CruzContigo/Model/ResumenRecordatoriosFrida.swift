import Foundation

enum ResumenRecordatoriosFrida {
    static func filtrar(
        _ recordatorios: [Recordatorio], periodo: ConsultaFrida.Periodo, pendientes: Bool = false,
        familiarID: UUID? = nil, ahora: Date = .now, calendario: Calendar = .current
    ) -> [Recordatorio] {
        let dia: Date?
        switch periodo {
        case .hoy: dia = ahora
        case .manana: dia = calendario.date(byAdding: .day, value: 1, to: ahora)
        case .todos, .proximos: dia = nil
        }
        return recordatorios.filter { recordatorio in
            if let familiarID, recordatorio.familiarID != familiarID { return false }
            if (pendientes || periodo == .proximos) && recordatorio.completado { return false }
            if let dia { return calendario.isDate(recordatorio.fecha, inSameDayAs: dia) }
            return periodo != .proximos || recordatorio.fecha >= ahora
        }
    }

    static func paraSiri(_ recordatorios: [Recordatorio], ahora: Date = .now, calendario: Calendar = .current) -> String {
        let hoy = filtrar(recordatorios, periodo: .hoy, ahora: ahora, calendario: calendario)
            .sorted { $0.fecha < $1.fecha }
        guard !hoy.isEmpty else { return "No tienes recordatorios para hoy." }

        var formato = Date.FormatStyle.dateTime.hour().minute().locale(Locale(identifier: "es_MX"))
        formato.calendar = calendario
        formato.timeZone = calendario.timeZone
        let limite = 5
        let filas = hoy.prefix(limite).map {
            let estado = $0.completado ? ", completado" : ""
            return "\($0.fecha.formatted(formato)): \($0.titulo)\(estado)."
        }
        let restantes = hoy.count - filas.count
        let encabezado = hoy.count == 1 ? "Hoy tienes un recordatorio." : "Hoy tienes \(hoy.count) recordatorios."
        var oraciones = [encabezado] + filas
        if restantes == 1 {
            oraciones.append("Hay uno más en CruzContigo.")
        } else if restantes > 1 {
            oraciones.append("Hay \(restantes) más en CruzContigo.")
        }
        return oraciones.joined(separator: " ")
    }
}
