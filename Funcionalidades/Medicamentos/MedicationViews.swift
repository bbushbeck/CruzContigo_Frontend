import SwiftUI

private enum MedicalStyle {
    static let red = Color.brandRed
    static let pale = Color.tintaSuave
}

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
         service: any MedicationService = MedicationServices.live()) {
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
                MedicationFormView(recipient: recipient, model: model)
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
                        MedicationFormView(recipient: CareRecipient(id: medication.recipientID, name: "", age: 0), model: model, editing: medication)
                    }
                }
                .confirmationDialog("¿Eliminar este medicamento?", isPresented: $showingDelete) {
                    Button("Eliminar", role: .destructive) {
                        isDeleting = true
                        Task {
                            let success = await model.delete(medication)
                            isDeleting = false
                            if success {
                                dismiss()
                            } else {
                                deleteError = model.errorMessage
                                model.errorMessage = nil
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

struct MedicationFormView: View {
    let recipient: CareRecipient
    @ObservedObject var model: MedicationViewModel
    var editing: Medication? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var presentation = ""
    @State private var dose = ""
    @State private var unit = ""
    @State private var frequency = ""
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.startOfDay(for: Date())
    @State private var indication = ""
    @State private var stock = ""
    @State private var refillThresholdDays = 5
    @State private var isSaving = false
    @State private var saveError: String?

    private func optionalText(_ value: String) -> String? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func decimalText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
    }

    private func validDecimal(_ value: String, positive: Bool) -> Bool {
        let normalized = decimalText(value)
        guard normalized.range(of: #"^[0-9]{1,8}(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil,
              let number = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else { return false }
        return positive ? number > 0 : number >= 0
    }

    private var valid: Bool {
        optionalText(name) != nil && name.count <= 120 &&
        validDecimal(dose, positive: true) && presentation.count <= 60 &&
        unit.count <= 10 && frequency.count <= 60 && indication.utf8.count <= 65535 &&
        (optionalText(stock) == nil || validDecimal(stock, positive: false)) &&
        (!hasEndDate || MedicationDay.string(from: endDate) >= MedicationDay.string(from: startDate))
    }

    var body: some View {
        Form {
            Section("Medicamento") {
                TextField("Nombre del medicamento", text: $name)
                TextField("Presentación (opcional, ej. tableta)", text: $presentation)
                TextField("Dosis numérica (ej. 500 o 0,5)", text: $dose)
                    .keyboardType(.decimalPad)
                TextField("Unidad (opcional, ej. mg o ml)", text: $unit)
                TextField("Frecuencia (opcional)", text: $frequency)
                Text("La dosis debe ser mayor que cero y tener como máximo dos decimales.")
                    .font(.app(.footnote)).foregroundStyle(Color.textoSuave)
            }
            Section("Fechas") {
                DatePicker("Fecha de inicio", selection: $startDate, displayedComponents: .date)
                Toggle("Tiene fecha de fin", isOn: $hasEndDate)
                if hasEndDate {
                    DatePicker("Fecha de fin", selection: $endDate,
                               in: Calendar.current.startOfDay(for: startDate)..., displayedComponents: .date)
                }
                Text("Los tratamientos cuya fecha de fin ya pasó aparecen en Anteriores.")
                    .font(.app(.footnote)).foregroundStyle(Color.textoSuave)
            }
            Section("Información adicional") {
                TextField("Indicación (opcional)", text: $indication, axis: .vertical)
                TextField("Existencias (opcional)", text: $stock)
                    .keyboardType(.decimalPad)
                Stepper("Umbral de resurtido: \(refillThresholdDays) días",
                        value: $refillThresholdDays, in: 0...32767)
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
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    let medication = Medication(
                        id: editing?.id ?? UUID(),
                        recipientID: editing?.recipientID ?? recipient.id,
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        presentation: optionalText(presentation),
                        dose: decimalText(dose),
                        unit: optionalText(unit),
                        frequency: optionalText(frequency),
                        startDate: MedicationDay.string(from: startDate),
                        endDate: hasEndDate ? MedicationDay.string(from: endDate) : nil,
                        indication: optionalText(indication),
                        stock: optionalText(stock) == nil ? nil : decimalText(stock),
                        refillThresholdDays: refillThresholdDays
                    )
                    isSaving = true
                    Task {
                        let success = await model.save(medication, updating: editing != nil)
                        isSaving = false
                        if success {
                            dismiss()
                        } else {
                            saveError = model.errorMessage
                            model.errorMessage = nil
                        }
                    }
                }
                .disabled(!valid || isSaving)
            }
        }
        .interactiveDismissDisabled(isSaving)
        .alert("No se pudo guardar", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Aceptar", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }
        .tint(MedicalStyle.red)
        .onAppear {
            guard let editing else { return }
            name = editing.name
            presentation = editing.presentation ?? ""
            dose = editing.dose
            unit = editing.unit ?? ""
            frequency = editing.frequency ?? ""
            startDate = MedicationDay.date(from: editing.startDate) ?? startDate
            hasEndDate = editing.endDate != nil
            endDate = editing.endDate.flatMap { MedicationDay.date(from: $0) } ?? startDate
            indication = editing.indication ?? ""
            stock = editing.stock ?? ""
            refillThresholdDays = editing.refillThresholdDays
        }
    }
}

#Preview {
    NavigationStack {
        MedicationsView(recipients: CareRecipient.examples, service: DemoMedicationService())
    }
}
