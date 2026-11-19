import SwiftUI

struct RevisarNotaFridaView: View {
    let relatoOriginal: String
    let personas: [Familiar]
    let alGuardar: (Familiar) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nota: SolicitudNota
    @State private var personaID: UUID?
    @State private var guardando = false
    @State private var error: String?

    init(
        nota: SolicitudNota, relatoOriginal: String, personas: [Familiar], personaInicial: UUID?,
        alGuardar: @escaping (Familiar) -> Void
    ) {
        self.relatoOriginal = relatoOriginal
        self.personas = personas
        self.alGuardar = alGuardar
        _nota = State(initialValue: nota)
        _personaID = State(initialValue: personaInicial)
    }

    private var persona: Familiar? { personas.first { $0.id == personaID } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Diario") {
                    if personas.isEmpty {
                        Text("Esta cuenta no tiene un diario donde pueda escribir.")
                    } else {
                        Picker("Persona", selection: $personaID) {
                            Text("Elige a una persona").tag(nil as UUID?)
                            ForEach(personas) { persona in
                                Text(persona.nombreCompleto).tag(Optional(persona.id))
                            }
                        }
                        if let persona {
                            Text("La red de cuidado de \(persona.nombreCompleto) podrá leer esta nota.")
                                .font(.app(.footnote))
                                .foregroundStyle(Color.textoSuave)
                        }
                    }
                }
                Section("Nota") {
                    Picker("Tema", selection: $nota.categoria) {
                        ForEach(CategoriaNota.allCases) { categoria in
                            Text(categoria.titulo).tag(categoria)
                        }
                    }
                    DatePicker("Cuándo", selection: $nota.fecha, in: ...Date(),
                               displayedComponents: [.date, .hourAndMinute])
                    TextEditor(text: $nota.texto)
                        .font(.app(.body))
                        .frame(minHeight: 132)
                        .accessibilityLabel("Texto de la nota")
                    if let error = nota.errores.first {
                        Text(error).foregroundStyle(Color.brandRed)
                    }
                    if nota.texto != relatoOriginal {
                        DisclosureGroup("Ver relato original") {
                            Text(relatoOriginal).font(.app(.body))
                        }
                    }
                }
            }
            .disabled(guardando)
            .navigationTitle("Revisar nota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Volver al chat") { dismiss() }.disabled(guardando)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar en diario") { Task { await guardar() } }
                        .disabled(!nota.esValida || persona == nil || guardando)
                }
            }
        }
        .tint(.brandRed)
        .interactiveDismissDisabled(guardando)
        .alert("No se pudo guardar", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private func guardar() async {
        guard let persona, nota.esValida, !guardando else { return }
        guardando = true
        defer { guardando = false }
        do {
            _ = try await Repositorios.diario().crear(nota, familiarID: persona.id)
            alGuardar(persona)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
