import Foundation

/// Convierte fechas entre `Date` y el texto YYYY-MM-DD que usa la API.
enum MedicationDay {
    nonisolated private static var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }

    nonisolated static func string(from date: Date) -> String { formatter.string(from: date) }
    nonisolated static func date(from string: String) -> Date? { formatter.date(from: string) }
    nonisolated static func label(_ string: String) -> String {
        date(from: string)?.formatted(date: .abbreviated, time: .omitted) ?? string
    }
}
