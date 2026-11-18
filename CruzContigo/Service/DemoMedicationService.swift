import Foundation

/// Solo para vistas previas; la navegación de la app utiliza RemoteMedicationService.
actor DemoMedicationService: MedicationService {
    private var medications = Medication.examples

    func fetchMedications(for recipientID: UUID) async throws -> [Medication] {
        medications.filter { $0.recipientID == recipientID }
    }

    func save(_ medication: Medication, updating: Bool) async throws -> Medication {
        if let index = medications.firstIndex(where: { $0.id == medication.id }) {
            medications[index] = medication
        } else {
            medications.append(medication)
        }
        return medication
    }

    func delete(_ medication: Medication) async throws {
        medications.removeAll { $0.id == medication.id }
    }
}

extension Medication {
    nonisolated static let examples: [Medication] = [
        Medication(recipientID: CareRecipient.maria.id, name: "Paracetamol", presentation: "Tableta", dose: "500.00", unit: "mg", frequency: "Cada 8 horas", startDate: MedicationDay.string(from: .now), indication: "Dolor o fiebre"),
        Medication(recipientID: CareRecipient.maria.id, name: "Metformina", dose: "850.00", unit: "mg", frequency: "Cada 12 horas", startDate: MedicationDay.string(from: .now)),
        Medication(recipientID: CareRecipient.maria.id, name: "Atorvastatina", dose: "10.00", unit: "mg", startDate: "2020-01-01", endDate: "2020-01-02"),
        Medication(recipientID: CareRecipient.jose.id, name: "Losartán", dose: "50.00", unit: "mg", frequency: "Cada 24 horas", startDate: MedicationDay.string(from: .now))
    ]
}
