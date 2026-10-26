import Foundation
public import Combine

@MainActor
final class MedicationViewModel: ObservableObject {
    @Published private(set) var medications: [Medication] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let service: any MedicationService

    init(service: any MedicationService = DemoMedicationService()) {
        self.service = service
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            medications = try await service.fetchMedications()
            errorMessage = nil
        } catch {
            errorMessage = "No se pudieron cargar los medicamentos: \(error.localizedDescription)"
        }
    }

    func save(_ medication: Medication) async -> Bool {
        do {
            try await service.save(medication)
            await load()
            return true
        } catch {
            errorMessage = "No se pudo guardar: \(error.localizedDescription)"
            return false
        }
    }

    func delete(_ medication: Medication) async -> Bool {
        do {
            try await service.delete(medication)
            await load()
            return true
        } catch {
            errorMessage = "No se pudo eliminar: \(error.localizedDescription)"
            return false
        }
    }

    func medications(for recipient: CareRecipient, status: MedicationStatus) -> [Medication] {
        medications.filter { $0.recipientID == recipient.id && $0.status == status }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
