import Foundation
public import Combine

/// Estado de la pantalla de medicamentos. `errorMessage` solo describe fallas al cargar;
/// guardar y eliminar devuelven su propio mensaje para que cada vista lo muestre donde corresponde.
@MainActor
final class MedicationViewModel: ObservableObject {
    @Published private(set) var medications: [Medication] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let service: any MedicationService
    private var recipientID: UUID?
    private var loadID: UUID?

    init(service: any MedicationService) {
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
        } catch {
            guard loadID == requestID, !Task.isCancelled else { return }
            errorMessage = "No se pudieron cargar los medicamentos: \(error.localizedDescription)"
        }
    }

    /// Devuelve `nil` si se guardó; si no, el mensaje de error para mostrar.
    func save(_ medication: Medication, updating: Bool) async -> String? {
        do {
            let saved = try await service.save(medication, updating: updating)
            if recipientID == saved.recipientID {
                medications.removeAll { $0.id == saved.id }
                medications.append(saved)
            }
            return nil
        } catch {
            return "No se pudo guardar: \(error.localizedDescription)"
        }
    }

    /// Devuelve `nil` si se eliminó; si no, el mensaje de error para mostrar.
    func delete(_ medication: Medication) async -> String? {
        do {
            try await service.delete(medication)
            medications.removeAll { $0.id == medication.id }
            return nil
        } catch {
            return "No se pudo eliminar: \(error.localizedDescription)"
        }
    }

    /// Tratamientos de una persona con el estado indicado, ordenados por nombre.
    func medications(for recipientID: UUID, status: MedicationStatus) -> [Medication] {
        medications.filter { $0.recipientID == recipientID && $0.status == status }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
