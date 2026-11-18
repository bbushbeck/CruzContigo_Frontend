//
//  DiarioView.swift
//  CruzContigo
//
//  HU-13 (RF-13): diario de cuidado. Cada nota indica fecha, autor y persona.
//  Solo quien escribió una nota puede cambiarla o borrarla.
//

import SwiftUI

struct DiarioView: View {
    let familiarID: UUID

    @Environment(FamiliaresStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: DiarioViewModel
    @State private var editando: Edicion?
    @State private var porEliminar: NotaDiario?

    struct Edicion: Identifiable {
        let id = UUID()
        let nota: NotaDiario?
    }

    init(familiarID: UUID) {
        self.familiarID = familiarID
        _viewModel = State(initialValue: DiarioViewModel(familiarID: familiarID))
    }

    private var familiar: Familiar? { store.familiares.first { $0.id == familiarID } }
    private var puedeEscribir: Bool { familiar?.puedeEscribirDiario ?? false }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BrandBackButton { dismiss() }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Diario de cuidado")
                            .font(.app(.largeTitle).weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                        Text(familiar.map { "Cómo está \($0.nombre) día a día. Lo ve toda su red de cuidado." }
                             ?? "Cómo está día a día.")
                            .font(.app(.body))
                            .foregroundColor(.textoSuave)
                    }

                    if puedeEscribir {
                        PrimaryButton(title: "Escribir nota") { editando = Edicion(nota: nil) }
                    }

                    ChipSelector(
                        opciones: CategoriaNota.allCases,
                        seleccion: Binding(get: { viewModel.filtro }, set: { viewModel.filtro = $0 }),
                        titulo: \.titulo,
                        icono: { $0.icono }
                    )
                    .accessibilityLabel("Filtrar por tema")

                    contenido
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .refreshable { await viewModel.cargar() }
        }
        .task { await viewModel.cargar() }
        .onChange(of: viewModel.filtro) {
            Task { await viewModel.cargar() }
        }
        .sheet(item: $editando) { edicion in
            EditarNotaView(nota: edicion.nota, nombre: familiar?.nombre ?? "") { solicitud in
                try await viewModel.guardar(solicitud, id: edicion.nota?.id)
            }
        }
        .confirmationDialog(
            "¿Borrar esta nota?",
            isPresented: Binding(get: { porEliminar != nil }, set: { if !$0 { porEliminar = nil } }),
            titleVisibility: .visible,
            presenting: porEliminar
        ) { nota in
            Button("Borrar nota", role: .destructive) {
                Task { await viewModel.eliminar(nota) }
            }
            Button("Volver", role: .cancel) {}
        } message: { _ in
            Text("Nadie de la red podrá verla.")
        }
        .alert("No se pudo completar", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    @ViewBuilder
    private var contenido: some View {
        switch viewModel.estado {
        case .cargando:
            ProgressView("Cargando notas…")
                .frame(maxWidth: .infinity, minHeight: 120)
        case .error(let mensaje):
            EstadoErrorView(mensaje: mensaje) {
                Task { await viewModel.cargar() }
            }
        case .listo:
            if viewModel.notas.isEmpty {
                Text(viewModel.filtro == nil
                     ? "Aún no hay notas. Anota cómo comió, durmió o se sintió hoy."
                     : "No hay notas de este tema.")
                    .font(.app(.subheadline))
                    .foregroundColor(.textoSuave)
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(viewModel.porDia, id: \.dia) { grupo in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(Self.titulo(dia: grupo.dia))
                                .font(.app(.headline))
                                .accessibilityAddTraits(.isHeader)
                            ForEach(grupo.notas) { nota in
                                TarjetaNota(nota: nota) {
                                    editando = Edicion(nota: nota)
                                } borrar: {
                                    porEliminar = nota
                                }
                            }
                        }
                    }
                    if viewModel.hayMas {
                        Button("Ver notas anteriores") {
                            Task { await viewModel.cargarMas() }
                        }
                        .font(.app(.subheadline).weight(.bold))
                        .foregroundColor(.brandRed)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
        }
    }

    static func titulo(dia: Date) -> String {
        let calendario = Calendar.current
        if calendario.isDateInToday(dia) { return "Hoy" }
        if calendario.isDateInYesterday(dia) { return "Ayer" }
        return dia.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

private struct TarjetaNota: View {
    let nota: NotaDiario
    let editar: () -> Void
    let borrar: () -> Void

    private var autor: String { nota.autor.esTuyo ? "Tú" : nota.autor.nombre }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(nota.categoria.titulo, systemImage: nota.categoria.icono)
                    .font(.app(.subheadline).weight(.bold))
                    .foregroundColor(nota.categoria == .incidencia ? .brandRed : .primary)
                Spacer()
                Text(nota.fecha.formatted(date: .omitted, time: .shortened))
                    .font(.app(.caption))
                    .foregroundColor(.textoSuave)
            }
            Text(nota.texto)
                .font(.app(.body))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Escribió: \(autor)" + (nota.editadoEn == nil ? "" : " · editada"))
                    .font(.app(.caption))
                    .foregroundColor(.textoSuave)
                Spacer()
                if nota.autor.esTuyo {
                    Menu {
                        Button("Editar", systemImage: "pencil", action: editar)
                        Button("Borrar", systemImage: "trash", role: .destructive, action: borrar)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .icono(.seleccion)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Opciones de la nota")
                }
            }
        }
        .padding(16)
        .tarjetaBorde(radio: 18)
        .accessibilityElement(children: .contain)
    }
}

private struct EditarNotaView: View {
    let nota: NotaDiario?
    let nombre: String
    let guardar: (SolicitudNota) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var solicitud: SolicitudNota
    @State private var categoria: CategoriaNota?
    @State private var intento = false
    @State private var guardando = false
    @State private var error: String?

    init(nota: NotaDiario?, nombre: String, guardar: @escaping (SolicitudNota) async throws -> Void) {
        self.nota = nota
        self.nombre = nombre
        self.guardar = guardar
        let inicial = SolicitudNota(
            categoria: nota?.categoria ?? .alimentacion,
            texto: nota?.texto ?? "",
            fecha: nota?.fecha ?? Date()
        )
        _solicitud = State(initialValue: inicial)
        _categoria = State(initialValue: inicial.categoria)
    }

    private var final: SolicitudNota {
        var s = solicitud
        s.categoria = categoria ?? .otro
        return s
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    FormFieldContainer(titulo: "¿De qué trata?", obligatorio: true) {
                        ChipSelector(opciones: CategoriaNota.allCases, seleccion: $categoria, titulo: \.titulo, icono: { $0.icono })
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text((categoria ?? .otro).pregunta)
                            .font(.app(.headline))
                        let sugerencias = (categoria ?? .otro).sugerencias
                        if !sugerencias.isEmpty {
                            ChipSelector(
                                opciones: sugerencias.map(Sugerencia.init),
                                seleccion: Binding(get: { nil }, set: { if let elegida = $0 { agregar(elegida.id) } }),
                                titulo: \.id
                            )
                        }
                        TextEditor(text: $solicitud.texto)
                            .font(.app(.body))
                            .frame(minHeight: 140)
                            .padding(8)
                            .fieldBorder(intento && !final.esValida && final.texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityLabel("Nota")
                        Text("\(solicitud.texto.count) de \(SolicitudNota.largoMaximo)")
                            .font(.app(.caption))
                            .foregroundColor(solicitud.texto.count > SolicitudNota.largoMaximo ? .brandRed : .textoSuave)
                    }

                    DatePicker("Cuándo", selection: $solicitud.fecha, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .font(.app(.body))
                        .frame(minHeight: 44)

                    if !nombre.isEmpty {
                        Label("Nota sobre \(nombre). La verá su red de cuidado.", systemImage: "person.fill")
                            .font(.app(.footnote))
                            .foregroundColor(.textoSuave)
                    }

                    if intento, let mensaje = final.errores.first {
                        Text(mensaje)
                            .font(.app(.footnote))
                            .foregroundColor(.brandRed)
                    }
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(nota == nil ? "Nueva nota" : "Editar nota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await enviar() } }
                        .disabled(guardando)
                }
            }
        }
        .tint(.brandRed)
        .interactiveDismissDisabled(guardando)
        .alert("No se pudo guardar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    /// Una respuesta rápida se suma a lo ya escrito, sin borrarlo.
    private func agregar(_ texto: String) {
        let actual = solicitud.texto.trimmingCharacters(in: .whitespacesAndNewlines)
        solicitud.texto = actual.isEmpty ? texto : actual + ". " + texto
    }

    private func enviar() async {
        intento = true
        guard final.esValida else { return }
        guardando = true
        defer { guardando = false }
        do {
            try await guardar(final)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
