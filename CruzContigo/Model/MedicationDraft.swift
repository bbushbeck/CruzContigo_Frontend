import Foundation

/// Datos capturados en el formulario de medicamentos. Concentra la validación
/// y la conversión a `Medication`, para que la vista solo muestre campos.
struct MedicationDraft: Equatable {
    var name = ""
    var presentation = ""
    var dose = ""
    var unit = ""
    var frequency = ""
    var startDate = Calendar.current.startOfDay(for: .now)
    var hasEndDate = false
    var endDate = Calendar.current.startOfDay(for: .now)
    var indication = ""
    var stock = ""
    var refillThresholdDays = 5

    init() {}

    init(medication: Medication) {
        name = medication.name
        presentation = medication.presentation ?? ""
        dose = medication.dose
        unit = medication.unit ?? ""
        frequency = medication.frequency ?? ""
        startDate = MedicationDay.date(from: medication.startDate) ?? startDate
        hasEndDate = medication.endDate != nil
        endDate = medication.endDate.flatMap { MedicationDay.date(from: $0) } ?? startDate
        indication = medication.indication ?? ""
        stock = medication.stock ?? ""
        refillThresholdDays = medication.refillThresholdDays
    }

    var isValid: Bool {
        Self.optionalText(name) != nil && name.count <= 120 &&
        Self.validDecimal(dose, positive: true) && presentation.count <= 60 &&
        unit.count <= 10 && frequency.count <= 60 && indication.utf8.count <= 65535 &&
        (Self.optionalText(stock) == nil || Self.validDecimal(stock, positive: false)) &&
        (!hasEndDate || MedicationDay.string(from: endDate) >= MedicationDay.string(from: startDate))
    }

    /// Construye el tratamiento. Solo debe llamarse cuando `isValid` es verdadero.
    func medication(id: UUID, recipientID: UUID) -> Medication {
        Medication(
            id: id,
            recipientID: recipientID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            presentation: Self.optionalText(presentation),
            dose: Self.decimalText(dose),
            unit: Self.optionalText(unit),
            frequency: Self.optionalText(frequency),
            startDate: MedicationDay.string(from: startDate),
            endDate: hasEndDate ? MedicationDay.string(from: endDate) : nil,
            indication: Self.optionalText(indication),
            stock: Self.optionalText(stock) == nil ? nil : Self.decimalText(stock),
            refillThresholdDays: refillThresholdDays
        )
    }

    private static func optionalText(_ value: String) -> String? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func decimalText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
    }

    private static func validDecimal(_ value: String, positive: Bool) -> Bool {
        let normalized = decimalText(value)
        guard normalized.range(of: #"^[0-9]{1,8}(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil,
              let number = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else { return false }
        return positive ? number > 0 : number >= 0
    }
}
