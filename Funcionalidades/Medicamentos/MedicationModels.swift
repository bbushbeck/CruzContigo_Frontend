import Foundation

struct CareRecipient: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var age: Int
}

enum MedicationStatus: String, Codable, CaseIterable, Identifiable {
    case active = "Activo"
    case discontinued = "Anterior"
    var id: String { rawValue }
}

struct Medication: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var recipientID: UUID
    var name: String
    var dose: String
    var frequency: String
    var route: String
    var startDate: Date
    var endDate: Date?
    var indication: String
    var prescribingDoctor: String
    var status: MedicationStatus = .active
}

extension CareRecipient {
    init(familiar: Familiar) {
        self.init(id: familiar.id, name: familiar.nombreCompleto, age: familiar.edad)
    }

    static let maria = CareRecipient(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "María López", age: 72)
    static let jose = CareRecipient(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "José Torres", age: 68)
    static let examples = [maria, jose]
}

extension Medication {
    static let examples: [Medication] = [
        Medication(recipientID: CareRecipient.maria.id, name: "Paracetamol", dose: "500 mg", frequency: "Cada 8 horas", route: "Oral", startDate: .now, endDate: nil, indication: "Dolor o fiebre", prescribingDoctor: "Dr. Ramírez"),
        Medication(recipientID: CareRecipient.maria.id, name: "Metformina", dose: "850 mg", frequency: "Cada 12 horas", route: "Oral", startDate: .now, endDate: nil, indication: "Diabetes", prescribingDoctor: "Dr. Ramírez"),
        Medication(recipientID: CareRecipient.maria.id, name: "Atorvastatina", dose: "10 mg", frequency: "Cada 24 horas", route: "Oral", startDate: .now, endDate: .now, indication: "", prescribingDoctor: "", status: .discontinued),
        Medication(recipientID: CareRecipient.jose.id, name: "Losartán", dose: "50 mg", frequency: "Cada 24 horas", route: "Oral", startDate: .now, endDate: nil, indication: "", prescribingDoctor: "")
    ]
}
