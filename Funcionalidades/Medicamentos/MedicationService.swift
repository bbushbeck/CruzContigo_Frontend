import Foundation

protocol MedicationService {
    func fetchMedications() async throws -> [Medication]
    func save(_ medication: Medication) async throws
    func delete(_ medication: Medication) async throws
}

/// Persistencia local para probar el módulo sin backend. PRUEBA. NO UTILIZAR COMO SUSTITUTO DE BACKEND o lo que sea no se
actor DemoMedicationService: MedicationService {
    /// Instancia compartida para que los cambios sobrevivan al navegar entre pantallas.
    static let compartido = DemoMedicationService()

    private var medications = Medication.examples

    func fetchMedications() async throws -> [Medication] { medications }

    func save(_ medication: Medication) async throws {
        if let index = medications.firstIndex(where: { $0.id == medication.id }) {
            medications[index] = medication
        } else {
            medications.append(medication)
        }
    }

    func delete(_ medication: Medication) async throws {
        medications.removeAll { $0.id == medication.id }
    }
}

// GET    /family-members/{recipientID}/medications
// POST   /family-members/{recipientID}/medications
// PATCH  /medications/{medicationID}
// DELETE /medications/{medicationID}
