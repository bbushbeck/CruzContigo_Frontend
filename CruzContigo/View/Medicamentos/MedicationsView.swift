import SwiftUI

/// Pantalla principal de medicamentos: elegir familiar, ver tratamientos actuales o anteriores, y agregar.
struct MedicationsView: View {
    @StateObject private var model: MedicationViewModel
    @State private var selectedRecipientID: UUID?
    @State private var status: MedicationStatus = .active
    @State private var showingAdd = false
    @Environment(\.dismiss) private var dismiss

    private let recipients: [CareRecipient]

    private var recipient: CareRecipient? {
        recipients.first { $0.id == selectedRecipientID } ?? recipients.first
    }

    init(recipients: [CareRecipient],
         selectedRecipient: CareRecipient? = nil,
         service: any MedicationService) {
        self.recipients = recipients
        _selectedRecipientID = State(initialValue: selectedRecipient?.id ?? recipients.first?.id)
        _model = StateObject(wrappedValue: MedicationViewModel(service: service))
    }

    var body: some View {
        Group {
            if let recipient {
                content(for: recipient)
            } else {
                VStack {
                    BrandBackButton { dismiss() }
                    ContentUnavailableView("Sin familiares", systemImage: "person.crop.circle.badge.plus",
                        description: Text("Registra un familiar para agregar sus medicamentos."))
                }
            }
        }
    }

    private func content(for recipient: CareRecipient) -> some View {
        let visible = model.medications(for: recipient.id, status: status)

        return VStack(spacing: 0) {
            HStack {
                BrandBackButton { dismiss() }
                Spacer()
                Text("Medicamentos").font(.app(.headline))
                Spacer()
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                        .icono(.navegacion)
                        .foregroundColor(.brandRed)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Agregar medicamento")
                .disabled(model.isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Menu {
                        ForEach(recipients) { person in
                            Button(person.name) { selectedRecipientID = person.id }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 45))
                                .foregroundStyle(MedicalStyle.red.opacity(0.35))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipient.name).font(.app(.headline))
                                Text("\(recipient.age) años · Seleccionar familiar")
                                    .font(.app(.subheadline)).foregroundStyle(Color.textoSuave)
                            }
                            Spacer()
                            Image(systemName: "chevron.down").foregroundStyle(MedicalStyle.red)
                        }
                        .padding(14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                    Picker("Tratamientos", selection: $status) {
                        Text("Actuales").tag(MedicationStatus.active)
                        Text("Anteriores").tag(MedicationStatus.discontinued)
                    }
                    .pickerStyle(.segmented)

                    if model.isLoading {
                        ProgressView("Cargando medicamentos...")
                            .frame(maxWidth: .infinity)
                    } else if visible.isEmpty {
                        ContentUnavailableView("Sin medicamentos", systemImage: "pills",
                            description: Text("No hay tratamientos en esta categoría."))
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(visible) { medication in
                                NavigationLink {
                                    MedicationDetailView(medicationID: medication.id, model: model)
                                } label: {
                                    MedicationRow(medication: medication)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button("Actualizar medicamentos") {
                        Task { await model.load(for: recipient.id) }
                    }
                    .disabled(model.isLoading)
                }
                .padding()
            }
        }
        .background(Color.fondoApp)
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                MedicationFormView(recipientID: recipient.id, model: model)
            }
        }
        .task(id: recipient.id) { await model.load(for: recipient.id) }
        .alert("Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .tint(MedicalStyle.red)
    }
}

/// Fila de un tratamiento en la lista.
private struct MedicationRow: View {
    let medication: Medication

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pills.fill")
                .icono(.mediano)
                .foregroundStyle(MedicalStyle.red)
                .frame(width: 48, height: 48)
                .background(MedicalStyle.pale, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(medication.name).font(.app(.headline)).foregroundStyle(.primary)
                Text(medication.doseLabel).foregroundStyle(Color.textoSuave)
                Text(medication.status == .active ? (medication.frequency ?? "Frecuencia no indicada") : "Tratamiento anterior")
                    .font(.app(.caption)).foregroundStyle(Color.textoSuave)
            }
            Spacer()
            Image(systemName: "chevron.right").icono(.flecha).foregroundStyle(Color.textoSuave)
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        MedicationsView(recipients: CareRecipient.examples, service: DemoMedicationService())
    }
}
