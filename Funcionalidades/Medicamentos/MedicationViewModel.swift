import Foundation
public import Combine

@MainActor
final class MedicationViewModel: ObservableObject {
    @Published private(set) var medications: [Medication] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let service: any MedicationService
    private var recipientID: UUID?
    private var loadID: UUID?

    init(service: any MedicationService = MedicationServices.live()) {
        self.service = service
    }

    func load(for recipientID: UUID) async {
        let requestID = UUID()
        loadID = requestID
        if self.recipientID != recipientID { medications = [] }
        self.recipientID = recipientID
        errorMessage = nil
        isLoading = true
        defer { if loadID == requestID { isLoading = false } }
        do {
            let received = try await service.fetchMedications(for: recipientID)
            guard loadID == requestID, !Task.isCancelled else { return }
            medications = received
            errorMessage = nil
        } catch {
            guard loadID == requestID, !Task.isCancelled else { return }
            errorMessage = "No se pudieron cargar los medicamentos: \(error.localizedDescription)"
        }
    }

    func save(_ medication: Medication, updating: Bool = false) async -> Bool {
        do {
            let saved = try await service.save(medication, updating: updating)
            if recipientID == saved.recipientID {
                medications.removeAll { $0.id == saved.id }
                medications.append(saved)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "No se pudo guardar: \(error.localizedDescription)"
            return false
        }
    }

    func delete(_ medication: Medication) async -> Bool {
        do {
            try await service.delete(medication)
            medications.removeAll { $0.id == medication.id }
            errorMessage = nil
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
