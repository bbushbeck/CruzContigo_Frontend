//
//  AccesibilidadView.swift
//  CruzContigo
//

import SwiftUI

struct AccesibilidadView: View {
    @Environment(Preferencias.self) private var prefs
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorSchemeContrast) private var contrasteSistema
    @Environment(\.accessibilityReduceMotion) private var movimientoSistema
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.openURL) private var openURL
    @State private var confirmarRestablecer = false

    var body: some View {
        @Bindable var prefs = prefs

        VStack(spacing: 0) {
            HStack {
                BrandBackButton { dismiss() }
                    .accessibilityLabel("Regresar")
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accesibilidad")
                            .font(.app(.largeTitle).weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                        Text("Ajusta la app a tu manera. Los cambios se ven al instante.")
                            .font(.app(.body))
                            .foregroundColor(.textoSuave)
                    }

                    vistaPrevia

                    Seccion(titulo: "Lectura") {
                        FilaInterruptor(
                            icono: "textformat",
                            titulo: "Letra para dislexia",
                            detalle: "Usa la tipografía OpenDyslexic, con letras de base más pesada que evitan confusiones como b/d o p/q.",
                            valor: $prefs.dislexia
                        )
                        Divider().padding(.leading, 60)
                        FilaInterruptor(
                            icono: "bold",
                            titulo: "Texto en negritas",
                            detalle: "Hace todas las letras más gruesas y fáciles de distinguir.",
                            valor: $prefs.textoEnNegritas
                        )
                        Divider().padding(.leading, 60)
                        tamanoTexto
                    }

                    Seccion(titulo: "Apariencia") {
                        VStack(alignment: .leading, spacing: 12) {
                            EtiquetaFila(icono: "circle.lefthalf.filled", titulo: "Modo de color", detalle: "«Automática» sigue el ajuste de tu iPhone.")
                            selectorApariencia
                        }
                        .padding(16)
                        Divider().padding(.leading, 60)
                        FilaInterruptor(
                            icono: "circle.righthalf.filled.inverse",
                            titulo: "Más contraste",
                            detalle: contrasteSistema == .increased
                                ? "Ya está activo desde los ajustes de tu iPhone."
                                : "Bordes y textos más marcados para ver mejor.",
                            valor: $prefs.masContraste
                        )
                    }

                    Seccion(titulo: "Movimiento y sensaciones") {
                        FilaInterruptor(
                            icono: "figure.walk.motion",
                            titulo: "Reducir movimiento",
                            detalle: movimientoSistema
                                ? "Ya está activo desde los ajustes de tu iPhone."
                                : "Quita animaciones y deslizamientos entre pantallas.",
                            valor: $prefs.reducirMovimiento
                        )
                        Divider().padding(.leading, 60)
                        FilaInterruptor(
                            icono: "iphone.radiowaves.left.and.right",
                            titulo: "Vibraciones",
                            detalle: "Una vibración suave confirma cuando eliges, guardas o hay un error.",
                            valor: $prefs.vibraciones
                        )
                    }

                    Seccion(titulo: "Lector de pantalla") {
                        VStack(alignment: .leading, spacing: 12) {
                            EtiquetaFila(
                                icono: "speaker.wave.2.fill",
                                titulo: voiceOver ? "VoiceOver está activo" : "VoiceOver",
                                detalle: "Toda la app tiene etiquetas para que VoiceOver lea botones, opciones y avisos. Se activa en Ajustes › Accesibilidad › VoiceOver, o diciendo «Oye Siri, activa VoiceOver»."
                            )
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            } label: {
                                Label("Abrir Ajustes", systemImage: "gear")
                                    .font(.app(.headline))
                                    .foregroundColor(.brandRed)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.tintaSuave))
                            }
                        }
                        .padding(16)
                    }

                    Button {
                        confirmarRestablecer = true
                    } label: {
                        Text("Restablecer ajustes")
                            .font(.app(.headline))
                            .foregroundColor(.brandRed)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .confirmationDialog("¿Restablecer los ajustes de accesibilidad?", isPresented: $confirmarRestablecer, titleVisibility: .visible) {
            Button("Restablecer", role: .destructive) { prefs.restablecer() }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var vistaPrevia: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vista previa")
                .font(.app(.caption).weight(.bold))
                .foregroundColor(.brandRed)
            Text("Rosa toma su medicamento a las 8:00")
                .font(.app(.headline))
            Text("Paracetamol 500 mg · 1 tableta después del desayuno.")
                .font(.app(.body))
                .foregroundColor(.textoSuave)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.tintaSuave))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.brandRed.opacity(0.3), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vista previa del texto: Rosa toma su medicamento a las 8:00. Paracetamol 500 miligramos, 1 tableta después del desayuno.")
    }

    private var tamanoTexto: some View {
        @Bindable var prefs = prefs
        return VStack(alignment: .leading, spacing: 14) {
            FilaInterruptor(
                icono: "textformat.size",
                titulo: "Usar tamaño de mi iPhone",
                detalle: "Desactívalo para elegir un tamaño solo para esta app.",
                valor: $prefs.tamanoDelSistema,
                conRelleno: false
            )
            if !prefs.tamanoDelSistema {
                HStack(spacing: 12) {
                    Text("A").font(.system(size: 15, weight: .semibold)).accessibilityHidden(true)
                    Slider(
                        value: Binding(
                            get: { Double(prefs.indiceTamano) },
                            set: { prefs.indiceTamano = Int($0.rounded()) }
                        ),
                        in: 0...Double(Preferencias.tamanos.count - 1),
                        step: 1
                    )
                    .tint(.brandRed)
                    .accessibilityLabel("Tamaño del texto")
                    .accessibilityValue(nombreTamano)
                    Text("A").font(.system(size: 28, weight: .semibold)).accessibilityHidden(true)
                }
                Text(nombreTamano)
                    .font(.app(.footnote))
                    .foregroundColor(.textoSuave)
                    .accessibilityHidden(true)
            }
        }
        .padding(16)
    }

    private var nombreTamano: String {
        ["Normal", "Grande", "Más grande", "Muy grande", "Enorme", "Extra enorme", "Máximo"][prefs.indiceTamano]
    }

    private var selectorApariencia: some View {
        @Bindable var prefs = prefs
        return HStack(spacing: 10) {
            ForEach(Apariencia.allCases) { opcion in
                let activa = prefs.apariencia == opcion
                Button {
                    prefs.apariencia = opcion
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: opcion.icono)
                            .icono(.grande)
                        Text(opcion.titulo)
                            .font(.app(.footnote).weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundColor(activa ? .white : .primary)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(RoundedRectangle(cornerRadius: 14).fill(activa ? Color.rojoSolido : Color.rellenoSuave))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(activa ? Color.rojoSolido : Color.borderGray, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Apariencia \(opcion.titulo)")
                .accessibilityAddTraits(activa ? [.isButton, .isSelected] : .isButton)
            }
        }
        .vibracion(.selection, trigger: prefs.apariencia)
    }
}

private struct Seccion<Contenido: View>: View {
    let titulo: String
    @ViewBuilder let contenido: Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titulo)
                .font(.app(.title3).weight(.bold))
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                contenido
            }
            .tarjetaBorde()
        }
    }
}

private struct EtiquetaFila: View {
    let icono: String
    let titulo: String
    let detalle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
                    .frame(width: 34, height: 34)
                Image(systemName: icono)
                    .icono(.mediano)
                    .foregroundColor(.brandRed)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(titulo)
                    .font(.app(.headline))
                Text(detalle)
                    .font(.app(.subheadline))
                    .foregroundColor(.textoSuave)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FilaInterruptor: View {
    let icono: String
    let titulo: String
    let detalle: String
    @Binding var valor: Bool
    var conRelleno = true

    var body: some View {
        Toggle(isOn: $valor) {
            EtiquetaFila(icono: icono, titulo: titulo, detalle: detalle)
        }
        .tint(.brandRed)
        .padding(conRelleno ? 16 : 0)
        .vibracion(.selection, trigger: valor)
        .accessibilityHint(detalle)
    }
}
