import SwiftUI

struct EditFamiliarView: View {
    @Environment(FamiliaresStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditFamiliarViewModel

    init(familiar: Familiar) {
        _viewModel = State(initialValue: EditFamiliarViewModel(familiar: familiar))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos personales") {
                    TextField("Nombre(s)", text: $viewModel.draft.nombre)
                    TextField("Apellidos", text: $viewModel.draft.apellidos)
                    DatePicker("Fecha de nacimiento", selection: $viewModel.fecha, in: rangoFechas, displayedComponents: .date)
                }
                Section("Cuidado") {
                    Picker("Parentesco", selection: $viewModel.draft.parentesco) {
                        ForEach(Parentesco.allCases) { Text($0.titulo).tag(Optional($0)) }
                    }
                    Picker("Tipo de cuidado", selection: $viewModel.draft.tipoCuidado) {
                        ForEach(TipoCuidado.allCases) { Text($0.titulo).tag(Optional($0)) }
                    }
                    TextField("Teléfono (10 dígitos)", text: $viewModel.draft.telefono)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.disabled(viewModel.guardando)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            if await viewModel.guardar(usando: store) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.guardando)
                }
            }
            .interactiveDismissDisabled(viewModel.guardando)
            .alert("No se pudo guardar", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    private var rangoFechas: ClosedRange<Date> {
        let actual = Date()
        let inicio = Calendar.current.date(byAdding: .year, value: -120, to: actual) ?? actual
        return inicio...actual
    }
}
