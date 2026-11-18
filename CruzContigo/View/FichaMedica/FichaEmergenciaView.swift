//
//  FichaEmergenciaView.swift
//  CruzContigo
//
//  HU-19 (RF-28): resumen para mostrar a paramédicos. Abre sin conexión con la copia
//  guardada y, solo si la persona titular lo permitió, como código QR.
//

import SwiftUI

struct FichaEmergenciaView: View {
    let familiarID: UUID

    @Environment(FamiliaresStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var viewModel: FichaEmergenciaViewModel
    @State private var llamada: ContactoEmergencia?
    @State private var mostrandoQR = false
    @State private var pidiendoConsentimiento = false

    init(familiarID: UUID) {
        self.familiarID = familiarID
        _viewModel = State(initialValue: FichaEmergenciaViewModel(familiarID: familiarID))
    }

    private var familiar: Familiar? {
        store.familiares.first { $0.id == familiarID }
    }

    private static let numerosFijos = [
        ContactoEmergencia(nombre: "Emergencias", detalle: "911", telefono: "911"),
        ContactoEmergencia(nombre: "Cruz Roja", detalle: "065 · Ambulancias", telefono: "065"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BrandBackButton { dismiss() }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            switch viewModel.estado {
            case .cargando:
                Spacer()
                ProgressView("Abriendo ficha…")
                Spacer()
            case .sinDatos:
                mensaje(
                    icono: "wifi.slash",
                    titulo: "No hay una ficha guardada",
                    texto: "Abre esta ficha una vez con internet para tenerla disponible sin conexión."
                )
            case .sinAcceso(let texto):
                mensaje(icono: "lock.fill", titulo: "Ya no tienes acceso a esta ficha", texto: texto)
            case .lista:
                if let ficha = viewModel.ficha {
                    contenido(ficha)
                }
            }
        }
        .task { await viewModel.cargar(familiar: familiar) }
        .sheet(isPresented: $mostrandoQR) {
            if let ficha = viewModel.ficha {
                CodigoQRSheet(ficha: ficha)
            }
        }
        .sheet(isPresented: $pidiendoConsentimiento) {
            ConsentimientoQRSheet(nombre: familiar?.nombre ?? "") {
                await viewModel.cambiarQR(true, familiar: familiar)
            }
        }
        .confirmationDialog(
            "¿Llamar a \(llamada?.nombre ?? "")?",
            isPresented: Binding(get: { llamada != nil }, set: { if !$0 { llamada = nil } }),
            titleVisibility: .visible,
            presenting: llamada
        ) { contacto in
            Button("Llamar al \(contacto.telefono)") {
                if let url = URL(string: "tel://\(contacto.telefono.filter(\.isNumber))") {
                    openURL(url)
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .alert("No se pudo cambiar el código QR", isPresented: Binding(
            get: { viewModel.errorQR != nil },
            set: { if !$0 { viewModel.errorQR = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(viewModel.errorQR ?? "")
        }
        .vibracion(.warning, trigger: llamada?.id)
    }

    private func contenido(_ ficha: FichaEmergencia) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("FICHA DE EMERGENCIA")
                        .font(.app(.caption).weight(.bold))
                        .foregroundColor(.brandRed)
                    Text(ficha.nombre)
                        .font(.app(.title).weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    if let edad = ficha.edad {
                        Text("\(edad) años")
                            .font(.app(.title3))
                            .foregroundColor(.textoSuave)
                    }
                }

                if viewModel.sinConexion {
                    Label(
                        "Sin conexión. Datos guardados el \(ficha.actualizada.formatted(date: .abbreviated, time: .shortened)).",
                        systemImage: "wifi.slash"
                    )
                    .font(.app(.footnote).weight(.semibold))
                    .foregroundColor(.textoSuave)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.tintaSuave))
                }

                TarjetaEmergencia(tipoSanguineo: ficha.tipoSanguineo, alergias: ficha.alergias)

                if !ficha.enfermedades.isEmpty {
                    SeccionFicha(titulo: "Enfermedades", icono: "heart.text.square", vacio: "") {
                        ForEach(ficha.enfermedades) { enfermedad in
                            Text(enfermedad.nombre)
                                .font(.app(.body))
                                .padding(.vertical, 4)
                        }
                    } esVacio: { false }
                }

                if !ficha.medicamentos.isEmpty {
                    SeccionFicha(titulo: "Medicamentos que toma", icono: "pills.fill", vacio: "") {
                        ForEach(ficha.medicamentos) { medicamento in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(medicamento.nombre).font(.app(.body).weight(.semibold))
                                if !medicamento.detalle.isEmpty {
                                    Text(medicamento.detalle).font(.app(.caption)).foregroundColor(.textoSuave)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .accessibilityElement(children: .combine)
                        }
                    } esVacio: { false }
                }

                if let observaciones = ficha.observaciones {
                    SeccionFicha(titulo: "Importante", icono: "exclamationmark.bubble.fill", vacio: "") {
                        Text(observaciones).font(.app(.body))
                    } esVacio: { false }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Llamar", systemImage: "phone.fill")
                        .font(.app(.headline))
                    ForEach(ficha.contactos + Self.numerosFijos) { contacto in
                        Button { llamada = contacto } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contacto.nombre).font(.app(.body).weight(.semibold))
                                    Text(contacto.detalle).font(.app(.caption)).foregroundColor(.textoSuave)
                                }
                                Spacer()
                                Image(systemName: "phone.arrow.up.right")
                                    .foregroundColor(.brandRed)
                                    .accessibilityHidden(true)
                            }
                            .padding(14)
                            .frame(minHeight: 56)
                            .tarjetaBorde(radio: 14)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Pide confirmación antes de llamar")
                    }
                }

                seccionQR(ficha)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .refreshable { await viewModel.cargar(familiar: familiar) }
    }

    @ViewBuilder
    private func seccionQR(_ ficha: FichaEmergencia) -> some View {
        let gestiona = familiar?.puedeGestionarAccesos == true && !viewModel.sinConexion
        VStack(alignment: .leading, spacing: 10) {
            if ficha.qrConsentido {
                PrimaryButton(title: "Mostrar código QR") { mostrandoQR = true }
                    .accessibilityHint("Los paramédicos pueden leerlo con la cámara, sin internet")
                if gestiona {
                    Button("Dejar de mostrar el código QR") {
                        Task { _ = await viewModel.cambiarQR(false, familiar: familiar) }
                    }
                    .font(.app(.subheadline).weight(.bold))
                    .foregroundColor(.brandRed)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(viewModel.procesandoQR)
                }
            } else if gestiona {
                Button { pidiendoConsentimiento = true } label: {
                    Label("Permitir código QR", systemImage: "qrcode")
                        .font(.app(.headline))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.tintaSuave))
                }
                .disabled(viewModel.procesandoQR)
            } else {
                Label("El código QR solo aparece si la persona titular lo permite.", systemImage: "qrcode")
                    .font(.app(.footnote))
                    .foregroundColor(.textoSuave)
            }
        }
    }

    private func mensaje(icono: String, titulo: String, texto: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: icono)
                .icono(.destacado)
                .foregroundColor(.brandRed)
                .accessibilityHidden(true)
            Text(titulo)
                .font(.app(.headline))
            Text(texto)
                .font(.app(.subheadline))
                .foregroundColor(.textoSuave)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

private struct CodigoQRSheet: View {
    let ficha: FichaEmergencia

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button("Cerrar") { dismiss() }
                    .foregroundColor(.brandRed)
                    .frame(minHeight: 44)
            }
            Text(ficha.nombre)
                .font(.app(.title2).weight(.bold))
            if let imagen = GeneradorQR.imagen(de: ficha.textoQR) {
                Image(uiImage: imagen)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .accessibilityLabel("Código QR con la ficha de emergencia de \(ficha.nombre)")
            }
            Text("Los paramédicos pueden leerlo con la cámara de su teléfono, sin internet.")
                .font(.app(.body))
                .foregroundColor(.textoSuave)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }
}

private struct ConsentimientoQRSheet: View {
    let nombre: String
    let confirmar: () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var acepta = false
    @State private var guardando = false

    private var persona: String { nombre.isEmpty ? "esta persona" : nombre }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button("Cancelar") { dismiss() }
                    .foregroundColor(.brandRed)
                    .frame(minHeight: 44)
                Spacer()
            }
            Text("¿Permitir el código QR?")
                .font(.app(.title2).weight(.bold))
            Text("El código QR muestra la ficha de emergencia de \(persona) a quien lo lea con su cámara, sin necesidad de la app. Úselo solo con personal de emergencias.")
                .font(.app(.body))
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                Text(AvisoPrivacidad.texto)
                    .font(.app(.footnote))
                    .foregroundColor(.textoSuave)
            }
            .frame(maxHeight: 180)
            Text("Versión \(AvisoPrivacidad.version)")
                .font(.app(.caption))
                .foregroundColor(.textoSuave)
            Toggle(isOn: $acepta) {
                Text("Leí el aviso y permito mostrar el código QR.")
                    .font(.app(.subheadline).weight(.semibold))
            }
            Spacer()
            PrimaryButton(title: guardando ? "Guardando…" : "Permitir código QR") {
                Task {
                    guardando = true
                    let listo = await confirmar()
                    guardando = false
                    if listo { dismiss() }
                }
            }
            .disabled(!acepta || guardando)
            .opacity(!acepta || guardando ? 0.5 : 1)
        }
        .padding(24)
        .tint(.brandRed)
    }
}
