import SwiftUI

/// Detalle de un tratamiento, con opciones para editarlo o eliminarlo.
struct MedicationDetailView: View {
    let medicationID: UUID
    @ObservedObject var model: MedicationViewModel
    @State private var showingEdit = false
    @State private var showingDelete = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @Environment(\.dismiss) private var dismiss

    private var medication: Medication? { model.medications.first { $0.id == medicationID } }

    var body: some View {
        Group {
            if let medication {
                List {
                    Section {
                        Label(medication.name, systemImage: "pills.fill")
                            .font(.app(.title2).bold())
                            .foregroundStyle(MedicalStyle.red)
                        LabeledContent("Estado", value: medication.status.rawValue)
                    }
                    Section("Tratamiento") {
                        LabeledContent("Presentación", value: medication.presentation ?? "No especificada")
                        LabeledContent("Dosis", value: medication.doseLabel)
                        LabeledContent("Frecuencia", value: medication.frequency ?? "No indicada")
                        LabeledContent("Inicio", value: MedicationDay.label(medication.startDate))
                        if let end = medication.endDate {
                            LabeledContent("Fin", value: MedicationDay.label(end))
                        }
                    }
                    Section("Información adicional") {
                        LabeledContent("Indicación", value: medication.indication ?? "No especificada")
                        LabeledContent("Existencias", value: medication.stock ?? "No registradas")
                        LabeledContent("Umbral de resurtido", value: "\(medication.refillThresholdDays) días")
                    }
                    Section {
                        Button("Eliminar medicamento", role: .destructive) { showingDelete = true }
                            .disabled(isDeleting)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.fondoApp)
                .navigationTitle("Detalle")
                .toolbar(.visible, for: .navigationBar)
                .toolbar {
                    Button("Editar") { showingEdit = true }
                        .disabled(isDeleting)
                }
                .sheet(isPresented: $showingEdit) {
                    NavigationStack {
                        MedicationFormView(recipientID: medication.recipientID, model: model, editing: medication)
                    }
                }
                .confirmationDialog("¿Eliminar este medicamento?", isPresented: $showingDelete) {
                    Button("Eliminar", role: .destructive) {
                        isDeleting = true
                        Task {
                            let error = await model.delete(medication)
                            isDeleting = false
                            if let error {
                                deleteError = error
                            } else {
                                dismiss()
                            }
                        }
                    }
                } message: { Text("Esta acción elimina el registro de la lista.") }
                .alert("No se pudo eliminar", isPresented: Binding(
                    get: { deleteError != nil },
                    set: { if !$0 { deleteError = nil } }
                )) {
                    Button("Aceptar", role: .cancel) { deleteError = nil }
                } message: { Text(deleteError ?? "") }
            } else {
                ContentUnavailableView("Medicamento no disponible", systemImage: "pills")
            }
        }
    }
}
