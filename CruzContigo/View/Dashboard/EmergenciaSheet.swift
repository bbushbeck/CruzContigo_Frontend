//
//  EmergenciaSheet.swift
//  CruzContigo
//

import SwiftUI

struct EmergenciaSheet: View {
    let persona: Familiar?
    let abrirModulo: (Modulo) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var llamadaPendiente: Llamada?

    struct Llamada: Identifiable {
        let id = UUID()
        let pregunta: String
        let numero: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .icono(.navegacion)
                            .foregroundColor(.textoSuave)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.rellenoSuave))
                    }
                    .accessibilityLabel("Cerrar")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("¿Necesitas ayuda?")
                        .font(.app(.largeTitle).weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Elige una opción. Antes de llamar te pediremos confirmar.")
                        .font(.app(.body))
                        .foregroundColor(.textoSuave)
                }

                Button {
                    llamadaPendiente = Llamada(pregunta: "¿Llamar a Cruz Roja (065)?", numero: "065")
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "phone.fill")
                            .icono(.grande)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Llamar a Cruz Roja")
                                .font(.app(.title3).weight(.bold))
                            Text("065 · Ambulancias en Monterrey, N.L.")
                                .font(.app(.subheadline))
                                .opacity(0.9)
                        }
                        .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(20)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.rojoSolido))
                }
                .accessibilityHint("Pide confirmación y abre el marcador del teléfono")

                if let persona, let telefono = persona.telefono {
                    opcion(
                        icono: "phone.arrow.up.right",
                        titulo: "Llamar a \(persona.nombre)",
                        subtitulo: formatear(telefono)
                    ) {
                        llamadaPendiente = Llamada(pregunta: "¿Llamar a \(persona.nombre)?", numero: telefono)
                    }
                }

                opcion(
                    icono: Modulo.emergencia.icono,
                    titulo: persona.map { "Ficha de emergencia de \($0.nombre)" } ?? "Ficha de emergencia",
                    subtitulo: "Alergias, tipo de sangre y contactos para mostrar a paramédicos"
                ) {
                    abrirModulo(.emergencia)
                }

                Label {
                    Text("CruzContigo no envía ambulancias ni llama de forma automática. Siempre eres tú quien confirma la llamada.")
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(.app(.footnote))
                .foregroundColor(.textoSuave)
            }
            .padding(24)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            llamadaPendiente?.pregunta ?? "",
            isPresented: Binding(
                get: { llamadaPendiente != nil },
                set: { if !$0 { llamadaPendiente = nil } }
            ),
            titleVisibility: .visible,
            presenting: llamadaPendiente
        ) { llamada in
            Button("Llamar ahora") {
                if let url = URL(string: "tel://\(llamada.numero)") {
                    openURL(url)
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .vibracion(.warning, trigger: llamadaPendiente?.id)
    }

    private func opcion(icono: String, titulo: String, subtitulo: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 48, height: 48)
                    Image(systemName: icono)
                        .icono(.mediano)
                        .foregroundColor(.brandRed)
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo)
                        .font(.app(.headline))
                        .foregroundColor(.primary)
                    Text(subtitulo)
                        .font(.app(.subheadline))
                        .foregroundColor(.textoSuave)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .icono(.flecha)
                    .foregroundColor(Color.iconoSuave)
            }
            .padding(16)
            .tarjetaBorde()
        }
        .buttonStyle(.plain)
    }

    private func formatear(_ t: String) -> String {
        guard t.count == 10 else { return t }
        return "\(t.prefix(2)) \(t.dropFirst(2).prefix(4)) \(t.suffix(4))"
    }
}
