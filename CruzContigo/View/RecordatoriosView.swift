import SwiftUI

struct RecordatoriosView: View {
    var familiarID: UUID? = nil
    var mostrarAtras = true

    @Environment(FamiliaresStore.self) private var familiares
    @Environment(\.dismiss) private var dismiss
    @State private var recordatorios: [Recordatorio] = []
    @State private var cargando = false
    @State private var guardando = false
    @State private var mensajeCarga: String?
    @State private var mensajeOperacion: String?
    @State private var formulario: Formulario?
    @State private var porEliminar: Recordatorio?

    private let servicio = RecordatoriosService()
    private let notificaciones = NotificationHandler()

    private struct Formulario: Identifiable {
        let id = UUID()
        var recordatorio: Recordatorio? = nil
    }

    private var visibles: [Recordatorio] {
        recordatorios.filter { familiarID == nil || $0.familiarID == familiarID }
            .sorted { $0.fecha < $1.fecha }
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

                    if cargando && visibles.isEmpty {
                        ProgressView("Cargando recordatorios…")
                    } else if let mensajeCarga {
                        EstadoErrorView(mensaje: mensajeCarga) {
                            Task { await cargar() }
                        }
                    } else if visibles.isEmpty {
                        ContentUnavailableView("Sin recordatorios", systemImage: "bell")
                    }

                    ForEach(visibles) { recordatorio in
                        fila(recordatorio)
                    }

                    Button {
                        formulario = Formulario()
                    } label: {
                        Label("Agregar recordatorio", systemImage: "plus")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(familiares.familiares.isEmpty || guardando || cargando)
                }
                .padding()
            }
            .refreshable { await cargar() }
        }
        .task {
            if familiares.estado == .inicial { await familiares.cargar() }
            await cargar()
        }
        .sheet(item: $formulario) { formulario in
            EditorRecordatorioView(
                familiares: familiares.familiares,
                familiarInicial: familiarID ?? familiares.familiares.first?.id,
                recordatorio: formulario.recordatorio
            ) { datos in
                try await guardar(datos, id: formulario.recordatorio?.id)
            }
        }
        .confirmationDialog(
            "Eliminar recordatorio",
            isPresented: Binding(get: { porEliminar != nil }, set: { if !$0 { porEliminar = nil } }),
            titleVisibility: .visible,
            presenting: porEliminar
        ) { recordatorio in
            Button("Eliminar", role: .destructive) {
                Task { await eliminar(recordatorio) }
            }
        } message: { recordatorio in
            Text(recordatorio.titulo)
        }
        .alert("No se pudo actualizar", isPresented: Binding(
            get: { mensajeOperacion != nil }, set: { if !$0 { mensajeOperacion = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(mensajeOperacion ?? "")
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
                Task {
                    var datos = recordatorio.datos
                    datos.completado.toggle()
                    do {
                        try await guardar(datos, id: recordatorio.id)
                    } catch {
                        mensajeOperacion = error.localizedDescription
                    }
                }
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
        .disabled(guardando || cargando)
        .padding(12)
        .background(Color.tintaSuave, in: RoundedRectangle(cornerRadius: 15))
    }

    private func cargar() async {
        guard !cargando, !guardando else { return }
        cargando = true
        defer { cargando = false }
        do {
            let respuesta = try await servicio.listar()
            guard !Task.isCancelled else { return }
            recordatorios = respuesta
            mensajeCarga = nil
        } catch {
            if !Task.isCancelled { mensajeCarga = error.localizedDescription }
        }
    }

    private func guardar(_ datos: DatosRecordatorio, id: UUID?) async throws {
        guard !cargando, !guardando else {
            throw APIError.servidor("Espera a que termine la actualización.")
        }
        guardando = true
        defer { guardando = false }
        let guardado = try await servicio.guardar(datos, id: id)
        recordatorios.removeAll { $0.id == guardado.id }
        recordatorios.append(guardado)
        await notificaciones.actualizar(guardado, nombre: nombre(de: guardado.familiarID))
    }

    private func eliminar(_ recordatorio: Recordatorio) async {
        guard !cargando, !guardando else { return }
        guardando = true
        defer { guardando = false }
        do {
            try await servicio.eliminar(id: recordatorio.id)
            recordatorios.removeAll { $0.id == recordatorio.id }
            notificaciones.cancelar(id: recordatorio.id)
        } catch {
            mensajeOperacion = error.localizedDescription
        }
    }
}

private struct EditorRecordatorioView: View {
    @Environment(\.dismiss) private var dismiss

    let familiares: [Familiar]
    let recordatorio: Recordatorio?
    let onGuardar: (DatosRecordatorio) async throws -> Void
    @State private var titulo: String
    @State private var familiarID: UUID?
    @State private var fecha: Date
    @State private var categoriaIA: CategoriaRecordatorio = .general
    @State private var mensajeIA: String?
    @State private var guardando = false
    @State private var error: String?

    init(
        familiares: [Familiar], familiarInicial: UUID?, recordatorio: Recordatorio?,
        onGuardar: @escaping (DatosRecordatorio) async throws -> Void
    ) {
        self.familiares = familiares
        self.recordatorio = recordatorio
        self.onGuardar = onGuardar
        _titulo = State(initialValue: recordatorio?.titulo ?? "")
        _familiarID = State(initialValue: recordatorio?.familiarID ?? familiarInicial)
        _fecha = State(initialValue: recordatorio?.fecha ?? Date().addingTimeInterval(300))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre del recordatorio", text: $titulo)
                Button {
                    let resultado = ClasificadorRecordatorios.clasificar(titulo)
                    categoriaIA = resultado.categoria
                    mensajeIA = resultado.mensaje
                } label: {
                    Label("Sugerir categoría con IA", systemImage: "sparkles")
                }
                .disabled(titulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || guardando)

                Picker("Categoría sugerida", selection: $categoriaIA) {
                    ForEach(CategoriaRecordatorio.allCases) { categoria in
                        Text(categoria.nombre).tag(categoria)
                    }
                }

                if let mensajeIA {
                    Text(mensajeIA)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("Familiar", selection: $familiarID) {
                    ForEach(familiares) { familiar in
                        Text(familiar.nombreCompleto).tag(Optional(familiar.id))
                    }
                }
                if let recordatorio {
                    DatePicker("Fecha y hora", selection: $fecha, in: min(recordatorio.fecha, .now)...)
                } else {
                    DatePicker("Fecha y hora", selection: $fecha, in: Date.now...)
                }
                if let error {
                    Text(error).foregroundStyle(Color.brandRed)
                }
            }
            .disabled(guardando)
            .navigationTitle(recordatorio == nil ? "Nuevo recordatorio" : "Editar recordatorio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.disabled(guardando)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task { await guardar() }
                    }
                    .disabled(guardando || familiarID == nil || tituloLimpio.isEmpty || tituloLimpio.count > 120)
                }
            }
        }
        .interactiveDismissDisabled(guardando)
        .tint(.brandRed)
    }

    private var tituloLimpio: String {
        titulo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func guardar() async {
        guard !guardando, let familiarID else { return }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await onGuardar(DatosRecordatorio(
                titulo: tituloLimpio, familiarID: familiarID, fecha: fecha,
                completado: recordatorio?.completado ?? false
            ))
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
