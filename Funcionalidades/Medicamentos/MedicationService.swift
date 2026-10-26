import Foundation

protocol MedicationService {
    func fetchMedications(for recipientID: UUID) async throws -> [Medication]
    func save(_ medication: Medication, updating: Bool) async throws -> Medication
    func delete(_ medication: Medication) async throws
}

struct RemoteMedicationService: MedicationService {
    let api: APIClient

    func fetchMedications(for recipientID: UUID) async throws -> [Medication] {
        try await api.get(path(recipientID))
    }

    func save(_ medication: Medication, updating: Bool) async throws -> Medication {
        if updating {
            return try await api.put(path(medication.recipientID) + "/\(medication.id.uuidString)", cuerpo: medication)
        }
        return try await api.post(path(medication.recipientID), cuerpo: medication)
    }

    func delete(_ medication: Medication) async throws {
        try await api.delete(path(medication.recipientID) + "/\(medication.id.uuidString)")
    }

    private func path(_ recipientID: UUID) -> String {
        "familiares/\(recipientID.uuidString)/medicamentos"
    }
}

enum MedicationServices {
    static func live() -> any MedicationService {
        if let url = AppConfig.apiBaseURL {
            return RemoteMedicationService(api: APIClient(baseURL: url))
        }
        return UnconfiguredMedicationService()
    }
}

private struct UnconfiguredMedicationService: MedicationService {
    private var error: APIError { .servidor("Configura CRUZ_API_URL para conectar con la API.") }
    func fetchMedications(for recipientID: UUID) async throws -> [Medication] { throw error }
    func save(_ medication: Medication, updating: Bool) async throws -> Medication { throw error }
    func delete(_ medication: Medication) async throws { throw error }
}

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
