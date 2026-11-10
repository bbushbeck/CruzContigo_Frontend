import Foundation

struct CareRecipient: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var age: Int
}

enum MedicationStatus: String, CaseIterable, Identifiable {
    case active = "Actual"
    case discontinued = "Anterior"
    var id: String { rawValue }
}

/// Las fechas DATE viajan como YYYY-MM-DD, sin conversión a otro huso horario.
/// Los valores DECIMAL viajan como texto, separados de la unidad.
struct Medication: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var recipientID: UUID
    var name: String
    var presentation: String? = nil
    var dose: String
    var unit: String? = nil
    var frequency: String? = nil
    var startDate: String
    var endDate: String? = nil
    var indication: String? = nil
    var stock: String? = nil
    var refillThresholdDays: Int = 5

    // El esquema no tiene estado: un tratamiento es anterior si su fin ya pasó.
    var status: MedicationStatus {
        if let endDate, endDate < MedicationDay.string(from: .now) { return .discontinued }
        return .active
    }

    var doseLabel: String {
        [dose, unit].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }
}

extension CareRecipient {
    init(familiar: Familiar) {
        self.init(id: familiar.id, name: familiar.nombreCompleto, age: familiar.edad)
    }

    static let maria = CareRecipient(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "María López", age: 72)
    static let jose = CareRecipient(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "José Torres", age: 68)
    static let examples = [maria, jose]
}
