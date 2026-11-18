import SwiftUI

struct FridaView: View {
    @Environment(FamiliaresStore.self) private var familiares
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var escribiendo: Bool
    @State private var dictado = DictadoFrida()
    @State private var viewModel: FridaViewModel

    init(familiarSeleccionado: UUID?, abrir: @escaping (Ruta) -> Void) {
        _viewModel = State(initialValue: FridaViewModel(
            familiarSeleccionado: familiarSeleccionado,
            abrir: abrir
        ))
    }

    var body: some View {
        NavigationStack {
            conversacion
                .safeAreaInset(edge: .bottom) { entrada }
                .navigationTitle("Frida")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { dismiss() }
                    }
                }
        }
        .tint(.brandRed)
        .onChange(of: dictado.transcripcion) { _, texto in
            if !texto.isEmpty { viewModel.borrador = texto }
        }
        .onChange(of: scenePhase) { _, fase in
            if fase == .background { dictado.cancelar() }
        }
        .onDisappear {
            dictado.cancelar()
            viewModel.cancelarConsulta()
        }
    }

    private var conversacion: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.mensajes) { mensaje in
                        burbuja(mensaje)
                    }
                    ForEach(viewModel.opciones) { familiar in
                        Button(familiar.nombreCompleto) {
                            viewModel.elegir(familiar, usando: familiares)
                        }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                    }
                    if viewModel.consultaActiva != nil {
                        ProgressView("Consultando la API…")
                    }
                    Color.clear.frame(height: 1).id("fin").accessibilityHidden(true)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.mensajes.count) { _, _ in
                scroll.scrollTo("fin", anchor: .bottom)
            }
        }
    }

    private func burbuja(_ mensaje: FridaViewModel.Mensaje) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if !mensaje.delUsuario {
                    Image("FridaAvatar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)
                }
                Text(mensaje.delUsuario ? "Tú" : "Frida")
                    .font(.app(.caption).weight(.semibold))
                    .foregroundStyle(mensaje.delUsuario ? Color.textoSuave : Color.brandRed)
            }
            Text(mensaje.texto)
                .font(.app(.body))
                .textSelection(.enabled)

            if let destino = mensaje.destino {
                Button {
                    viewModel.abrirDestino(destino)
                } label: {
                    Label(viewModel.titulo(de: destino), systemImage: "arrow.right")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(mensaje.delUsuario ? Color.rellenoSuave : Color.tintaSuave, in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: mensaje.delUsuario ? .trailing : .leading)
    }

    private var entrada: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let mensaje = dictado.mensaje {
                Text(mensaje).font(.app(.footnote)).foregroundStyle(.secondary)
            } else if dictado.estado == .escuchando {
                Text("Escuchando… Toca el micrófono para terminar.")
                    .font(.app(.footnote)).foregroundStyle(Color.brandRed)
            } else if dictado.estado == .terminando {
                Text("Terminando el dictado…").font(.app(.footnote)).foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    if dictado.estado == .escuchando {
                        dictado.terminar()
                    } else {
                        escribiendo = false
                        Task { await dictado.iniciar() }
                    }
                } label: {
                    Image(systemName: dictado.estado == .escuchando ? "stop.circle.fill" : "mic.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(dictado.estado == .escuchando ? "Terminar dictado" : "Dictar consulta")
                .disabled(viewModel.consultaActiva != nil || dictado.estado == .permisos || dictado.estado == .terminando)

                TextField("Escribe o dicta tu consulta", text: $viewModel.borrador, axis: .vertical)
                    .font(.app(.body))
                    .lineLimit(1...4)
                    .focused($escribiendo)
                    .disabled(dictado.estado != .listo)
                    .padding(10)
                    .background(Color.rellenoSuave, in: RoundedRectangle(cornerRadius: 12))

                Button(action: enviar) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Enviar consulta")
                .disabled(viewModel.textoLimpio.isEmpty || viewModel.consultaActiva != nil || dictado.estado != .listo)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private func enviar() {
        escribiendo = false
        viewModel.enviar(usando: familiares)
    }
}
