import SwiftUI

struct RecordatoriosView: View {
    var familiarID: UUID?
    var mostrarAtras: Bool

    @Environment(FamiliaresStore.self) private var familiares
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RecordatoriosViewModel
    @State private var formulario: Formulario?
    @State private var porEliminar: Recordatorio?

    private struct Formulario: Identifiable {
        let id = UUID()
        var recordatorio: Recordatorio? = nil
    }

    init(familiarID: UUID? = nil, mostrarAtras: Bool = true) {
        self.familiarID = familiarID
        self.mostrarAtras = mostrarAtras
        _viewModel = State(initialValue: RecordatoriosViewModel(familiarID: familiarID))
    }

    private func nombre(de id: UUID) -> String {
        familiares.familiares.first { $0.id == id }?.nombreCompleto ?? "Familiar"
    }

    var body: some View {
        VStack(spacing: 0) {
            if mostrarAtras {
                HStack {
                    BrandBackButton { dismiss() }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Mis recordatorios")
                        .font(.app(.title2).bold())
                        .accessibilityAddTraits(.isHeader)
                    if let familiarID {
                        Text(nombre(de: familiarID))
                            .font(.app(.subheadline))
                            .foregroundStyle(Color.textoSuave)
                    }

                    if viewModel.cargando && viewModel.visibles.isEmpty {
                        ProgressView("Cargando recordatorios…")
                    } else if let mensajeCarga = viewModel.mensajeCarga {
                        EstadoErrorView(mensaje: mensajeCarga) {
                            Task { await viewModel.cargar() }
                        }
                    } else if viewModel.visibles.isEmpty {
                        ContentUnavailableView("Sin recordatorios", systemImage: "bell")
                    }

                    ForEach(viewModel.visibles) { recordatorio in
                        fila(recordatorio)
                    }

                    Button {
                        formulario = Formulario()
                    } label: {
                        Label("Agregar recordatorio", systemImage: "plus")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(familiares.familiares.isEmpty || viewModel.guardando || viewModel.cargando)
                }
                .padding()
            }
            .refreshable { await viewModel.cargar() }
        }
        .task {
            if familiares.estado == .inicial { await familiares.cargar() }
            await viewModel.cargar()
        }
        .sheet(item: $formulario) { formulario in
            EditorRecordatorioView(
                familiares: familiares.familiares,
                familiarInicial: familiarID ?? familiares.familiares.first?.id,
                recordatorio: formulario.recordatorio
            ) { datos in
                try await viewModel.guardar(
                    datos,
                    id: formulario.recordatorio?.id,
                    familiares: familiares.familiares
                )
            }
        }
        .confirmationDialog(
            "Eliminar recordatorio",
            isPresented: Binding(get: { porEliminar != nil }, set: { if !$0 { porEliminar = nil } }),
            titleVisibility: .visible,
            presenting: porEliminar
        ) { recordatorio in
            Button("Eliminar", role: .destructive) {
                Task { await viewModel.eliminar(recordatorio) }
            }
        } message: { recordatorio in
            Text(recordatorio.titulo)
        }
        .alert("No se pudo actualizar", isPresented: Binding(
            get: { viewModel.mensajeOperacion != nil }, set: { if !$0 { viewModel.mensajeOperacion = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(viewModel.mensajeOperacion ?? "")
        }
    }

    private func fila(_ recordatorio: Recordatorio) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(recordatorio.titulo)
                    .font(.app(.subheadline).bold())
                    .strikethrough(recordatorio.completado)
                Text(nombre(de: recordatorio.familiarID))
                    .font(.app(.caption))
                    .foregroundStyle(Color.textoSuave)
                Text(recordatorio.fechaCorta)
                    .font(.app(.caption))
                    .foregroundStyle(Color.brandRed)
            }
            Spacer()
            Button {
                Task { await viewModel.alternarCompletado(recordatorio, familiares: familiares.familiares) }
            } label: {
                Image(systemName: recordatorio.completado ? "checkmark.circle.fill" : "circle")
                    .icono(.seleccion)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(recordatorio.completado ? "Marcar como pendiente" : "Marcar como completado")
            .buttonStyle(.borderless)
            Menu {
                Button("Editar", systemImage: "pencil") {
                    formulario = Formulario(recordatorio: recordatorio)
                }
                Button("Eliminar", systemImage: "trash", role: .destructive) {
                    porEliminar = recordatorio
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Opciones de \(recordatorio.titulo)")
        }
        .disabled(viewModel.guardando || viewModel.cargando)
        .padding(12)
        .background(Color.tintaSuave, in: RoundedRectangle(cornerRadius: 15))
    }
}

private struct EditorRecordatorioView: View {
    @Environment(\.dismiss) private var dismiss

    let familiares: [Familiar]
    let recordatorio: Recordatorio?
    @State private var viewModel: EditorRecordatorioViewModel

    init(
        familiares: [Familiar], familiarInicial: UUID?, recordatorio: Recordatorio?,
        onGuardar: @escaping (DatosRecordatorio) async throws -> Void
    ) {
        self.familiares = familiares
        self.recordatorio = recordatorio
        _viewModel = State(initialValue: EditorRecordatorioViewModel(
            familiarInicial: familiarInicial,
            recordatorio: recordatorio,
            onGuardar: onGuardar
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre del recordatorio", text: $viewModel.titulo)
                Picker("Familiar", selection: $viewModel.familiarID) {
                    ForEach(familiares) { familiar in
                        Text(familiar.nombreCompleto).tag(Optional(familiar.id))
                    }
                }
                if let recordatorio {
                    DatePicker("Fecha y hora", selection: $viewModel.fecha, in: min(recordatorio.fecha, .now)...)
                } else {
                    DatePicker("Fecha y hora", selection: $viewModel.fecha, in: Date.now...)
                }
                if let error = viewModel.error {
                    Text(error).foregroundStyle(Color.brandRed)
                }
            }
            .disabled(viewModel.guardando)
            .navigationTitle(recordatorio == nil ? "Nuevo recordatorio" : "Editar recordatorio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.disabled(viewModel.guardando)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            if await viewModel.guardar() { dismiss() }
                        }
                    }
                    .disabled(!viewModel.puedeGuardar)
                }
            }
        }
        .interactiveDismissDisabled(viewModel.guardando)
        .tint(.brandRed)
    }
}
