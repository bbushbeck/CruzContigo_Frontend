import SwiftUI

private enum MedicalStyle {
    static let red = Color.brandRed
    static let pale = Color.tintaSuave
}

struct MedicationsView: View {
    @StateObject private var model: MedicationViewModel
    @State private var recipient: CareRecipient
    @State private var status: MedicationStatus = .active
    @State private var showingAdd = false
    @Environment(\.dismiss) private var dismiss

    private let recipients: [CareRecipient]

    init(recipients: [CareRecipient] = CareRecipient.examples,
         selectedRecipient: CareRecipient? = nil,
         service: any MedicationService = DemoMedicationService()) {
        self.recipients = recipients
        _recipient = State(initialValue: selectedRecipient ?? recipients.first ?? CareRecipient.maria)
        _model = StateObject(wrappedValue: MedicationViewModel(service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
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
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Menu {
                        ForEach(recipients) { person in
                            Button(person.name) { recipient = person }
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
                    } else if model.medications(for: recipient, status: status).isEmpty {
                        ContentUnavailableView("Sin medicamentos", systemImage: "pills",
                            description: Text("No hay tratamientos en esta categoría."))
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(model.medications(for: recipient, status: status)) { medication in
                                NavigationLink {
                                    MedicationDetailView(medicationID: medication.id, model: model)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "pills.fill")
                                            .icono(.mediano)
                                            .foregroundStyle(MedicalStyle.red)
                                            .frame(width: 48, height: 48)
                                            .background(MedicalStyle.pale, in: RoundedRectangle(cornerRadius: 12))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(medication.name).font(.app(.headline)).foregroundStyle(.primary)
                                            Text(medication.dose).foregroundStyle(Color.textoSuave)
                                            Text(medication.status == .active ? medication.frequency : "Tratamiento anterior")
                                                .font(.app(.caption)).foregroundStyle(Color.textoSuave)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").icono(.flecha).foregroundStyle(Color.textoSuave)
                                    }
                                    .padding(14)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Label("Los cambios se guardan solo durante esta sesión de demostración.", systemImage: "info.circle")
                        .font(.app(.footnote)).foregroundStyle(Color.textoSuave)
                }
                .padding()
            }
        }
        .background(Color.fondoApp)
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                MedicationFormView(recipient: recipient, model: model)
            }
        }
        .task { await model.load() }
        .alert("Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .tint(MedicalStyle.red)
    }
}

struct MedicationDetailView: View {
    let medicationID: UUID
    @ObservedObject var model: MedicationViewModel
    @State private var showingEdit = false
    @State private var showingDelete = false
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
                        LabeledContent("Dosis", value: medication.dose)
                        LabeledContent("Frecuencia", value: medication.frequency)
                        LabeledContent("Vía", value: medication.route)
                        LabeledContent("Inicio", value: medication.startDate.formatted(date: .abbreviated, time: .omitted))
                        if let end = medication.endDate {
                            LabeledContent("Fin", value: end.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                    Section("Información adicional") {
                        LabeledContent("Indicación", value: medication.indication.isEmpty ? "No especificada" : medication.indication)
                        LabeledContent("Médico", value: medication.prescribingDoctor.isEmpty ? "No especificado" : medication.prescribingDoctor)
                    }
                    Section {
                        Button("Eliminar medicamento", role: .destructive) { showingDelete = true }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.fondoApp)
                .navigationTitle("Detalle")
                .toolbar(.visible, for: .navigationBar)
                .toolbar {
                    Button("Editar") { showingEdit = true }
                }
                .sheet(isPresented: $showingEdit) {
                    NavigationStack {
                        MedicationFormView(recipient: CareRecipient(id: medication.recipientID, name: "", age: 0), model: model, editing: medication)
                    }
                }
                .confirmationDialog("¿Eliminar este medicamento?", isPresented: $showingDelete) {
                    Button("Eliminar", role: .destructive) {
                        Task { if await model.delete(medication) { dismiss() } }
                    }
                } message: { Text("Esta acción elimina el registro de la lista.") }
            } else {
                ContentUnavailableView("Medicamento no disponible", systemImage: "pills")
            }
        }
    }
}

struct MedicationFormView: View {
    let recipient: CareRecipient
    @ObservedObject var model: MedicationViewModel
    var editing: Medication? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var dose = ""
    @State private var frequency = "Cada 24 horas"
    @State private var route = "Oral"
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var indication = ""
    @State private var doctor = ""
    @State private var status: MedicationStatus = .active
    @State private var isSaving = false

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !dose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!hasEndDate || endDate >= Calendar.current.startOfDay(for: startDate))
    }

    var body: some View {
        Form {
            Section("Medicamento") {
                TextField("Nombre del medicamento", text: $name)
                TextField("Dosis (ej. 500 mg)", text: $dose)
                Picker("Frecuencia", selection: $frequency) {
                    ForEach(["Cada 4 horas", "Cada 6 horas", "Cada 8 horas", "Cada 12 horas", "Cada 24 horas", "Según indicación médica"], id: \.self) { Text($0) }
                }
                Picker("Vía de administración", selection: $route) {
                    ForEach(["Oral", "Tópica", "Inhalada", "Oftálmica", "Otra"], id: \.self) { Text($0) }
                }
                Picker("Estado", selection: $status) {
                    ForEach(MedicationStatus.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            Section("Fechas") {
                DatePicker("Fecha de inicio", selection: $startDate, displayedComponents: .date)
                Toggle("Tiene fecha de fin", isOn: $hasEndDate)
                if hasEndDate {
                    DatePicker("Fecha de fin", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }
            Section("Opcional") {
                TextField("Indicación", text: $indication)
                TextField("Médico que lo recetó", text: $doctor)
            }
            Section {
                Text("Registra únicamente indicaciones confirmadas por un profesional de salud. Esta app no calcula ni recomienda dosis.")
                    .font(.app(.footnote)).foregroundStyle(Color.textoSuave)
            }
        }
        .navigationTitle(editing == nil ? "Agregar medicamento" : "Editar medicamento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    let medication = Medication(
                        id: editing?.id ?? UUID(),
                        recipientID: editing?.recipientID ?? recipient.id,
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        dose: dose.trimmingCharacters(in: .whitespacesAndNewlines),
                        frequency: frequency,
                        route: route,
                        startDate: startDate,
                        endDate: hasEndDate ? endDate : nil,
                        indication: indication,
                        prescribingDoctor: doctor,
                        status: status
                    )
                    isSaving = true
                    Task {
                        let success = await model.save(medication)
                        isSaving = false
                        if success { dismiss() }
                    }
                }
                .disabled(!valid || isSaving)
            }
        }
        .tint(MedicalStyle.red)
        .onAppear {
            guard let editing else { return }
            name = editing.name
            dose = editing.dose
            frequency = editing.frequency
            route = editing.route
            startDate = editing.startDate
            hasEndDate = editing.endDate != nil
            endDate = editing.endDate ?? Date()
            indication = editing.indication
            doctor = editing.prescribingDoctor
            status = editing.status
        }
    }
}

#Preview {
    NavigationStack {
        MedicationsView()
    }
}
