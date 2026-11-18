import SwiftUI
import PhotosUI
import QuickLook
import UniformTypeIdentifiers

struct DocumentosMedicosView: View {
    let puedeEditar: Bool

    @State private var viewModel: DocumentosMedicosViewModel
    @State private var foto: PhotosPickerItem?
    @State private var mostrarArchivos = false
    @State private var urlAbierta: URL?
    @Environment(\.dismiss) private var dismiss

    init(familiarID: UUID, puedeEditar: Bool) {
        self.puedeEditar = puedeEditar
        _viewModel = State(initialValue: DocumentosMedicosViewModel(familiarID: familiarID))
    }

    var body: some View {
        NavigationStack {
            List {
                if puedeEditar {
                    Section("Agregar documento") {
                        Picker("Clasificar como", selection: $viewModel.tipoNuevo) {
                            ForEach(TipoDocumento.allCases) { Text($0.titulo).tag($0) }
                        }
                        PhotosPicker(selection: $foto, matching: .images) {
                            Label("Elegir foto", systemImage: "photo")
                        }
                        Button { mostrarArchivos = true } label: {
                            Label("Elegir PDF", systemImage: "doc")
                        }
                        Text("Tamaño máximo: 15 MB. Los archivos se guardan protegidos en este dispositivo.")
                            .font(.app(.footnote))
                            .foregroundColor(.textoSuave)
                    }
                    .disabled(viewModel.guardando)
                }

                Section {
                    Picker("Filtrar por tipo", selection: $viewModel.filtro) {
                        Text("Todos").tag(TipoDocumento?.none)
                        ForEach(TipoDocumento.allCases) { Text($0.titulo + "s").tag(Optional($0)) }
                    }
                }

                Section("Documentos") {
                    if viewModel.filtrados.isEmpty {
                        Text("No hay documentos en esta categoría.")
                            .foregroundColor(.textoSuave)
                    }
                    ForEach(viewModel.filtrados) { documento in
                        Button { urlAbierta = documento.url } label: {
                            HStack(spacing: 12) {
                                Image(systemName: documento.archivo.hasSuffix(".pdf") ? "doc.fill" : "photo.fill")
                                    .foregroundColor(.brandRed)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(documento.titulo).foregroundColor(.primary)
                                    Text("\(documento.tipo.titulo) · \(documento.fecha.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.app(.caption))
                                        .foregroundColor(.textoSuave)
                                }
                            }
                            .frame(minHeight: 44)
                        }
                        .accessibilityHint("Abre el documento")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if puedeEditar {
                                Button("Eliminar", role: .destructive) { viewModel.eliminar(documento) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Documentos médicos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Cerrar") { dismiss() } }
            .overlay { if viewModel.guardando { ProgressView("Guardando…") } }
            .onAppear(perform: viewModel.cargar)
            .onChange(of: foto) { _, item in
                guard let item else { return }
                Task {
                    await viewModel.guardarFoto(item)
                    foto = nil
                }
            }
            .fileImporter(isPresented: $mostrarArchivos, allowedContentTypes: [.pdf]) { resultado in
                viewModel.guardarArchivo(resultado)
            }
            .quickLookPreview($urlAbierta)
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
}
