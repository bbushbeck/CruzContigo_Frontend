//
//  AutorizarAccesoView.swift
//  CruzContigo
//
//  Formulario para autorizar un acceso. Exige aceptar el aviso de privacidad vigente,
//  cuya versión queda guardada como evidencia del consentimiento (RF-31).
//

import SwiftUI

struct AutorizarAccesoView: View {
    let nombre: String
    let onAutorizar: (SolicitudAcceso) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var solicitud = SolicitudAcceso(diasVigencia: 7)
    @State private var rol: RolAcceso? = .cocuidador
    @State private var relacion = ""
    @State private var intentoGuardar = false
    @State private var guardando = false
    @State private var errorServidor: String?

    private var solicitudFinal: SolicitudAcceso {
        var final = solicitud
        final.rol = rol ?? .cocuidador
        final.relacion = relacion
        return final
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancelar") { dismiss() }
                    .foregroundColor(.brandRed)
                    .frame(minHeight: 44)
                Spacer()
                Text("Autorizar acceso").font(.app(.headline))
                Spacer()
                Button("Cancelar") {}.hidden()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("La persona debe tener una cuenta de CruzContigo con este número.")
                        .font(.app(.subheadline))
                        .foregroundColor(.textoSuave)

                    BrandTextField(
                        titulo: "Teléfono",
                        placeholder: "10 dígitos",
                        texto: $solicitud.telefono,
                        obligatorio: true,
                        error: intentoGuardar && solicitud.telefono.filter(\.isNumber).count != 10 ? "Escribe un teléfono de 10 dígitos." : nil,
                        teclado: .phonePad
                    )

                    FormFieldContainer(titulo: "Tipo de acceso", obligatorio: true) {
                        ChipSelector(opciones: RolAcceso.autorizables, seleccion: $rol, titulo: \.titulo)
                        if let rol {
                            Text(rol.descripcion)
                                .font(.app(.footnote))
                                .foregroundColor(.textoSuave)
                        }
                    }

                    if rol == .profesional {
                        FormFieldContainer(titulo: "Duración del acceso", obligatorio: true) {
                            Stepper(value: diasVigencia, in: SolicitudAcceso.diasProfesional) {
                                Text(diasVigencia.wrappedValue == 1 ? "1 día" : "\(diasVigencia.wrappedValue) días")
                                    .font(.app(.body))
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                            .fieldBorder(false)
                        }
                    } else {
                        BrandTextField(
                            titulo: "Relación con \(nombre) (opcional)",
                            placeholder: "Ej. Hija, vecino, enfermera",
                            texto: $relacion
                        )
                    }

                    aviso
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 10) {
                if intentoGuardar, let primerError = solicitudFinal.errores.first {
                    Text(primerError)
                        .font(.app(.footnote))
                        .foregroundColor(.brandRed)
                }
                PrimaryButton(title: guardando ? "Autorizando…" : "Autorizar acceso") {
                    Task { await autorizar() }
                }
                .disabled(guardando)
                .opacity(guardando ? 0.7 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .tint(.brandRed)
        .interactiveDismissDisabled(guardando)
        .alert("No se pudo autorizar", isPresented: Binding(
            get: { errorServidor != nil },
            set: { if !$0 { errorServidor = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(errorServidor ?? "")
        }
    }

    private var diasVigencia: Binding<Int> {
        Binding(
            get: { solicitud.diasVigencia ?? 7 },
            set: { solicitud.diasVigencia = $0 }
        )
    }

    private var aviso: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Aviso de privacidad", systemImage: "lock.shield.fill")
                .font(.app(.headline))
            Text(AvisoPrivacidad.texto)
                .font(.app(.footnote))
                .fixedSize(horizontal: false, vertical: true)
            Text("Versión \(AvisoPrivacidad.version)")
                .font(.app(.caption))
                .foregroundColor(.textoSuave)
            Toggle(isOn: $solicitud.aceptaAviso) {
                Text("Leí el aviso y autorizo compartir los datos médicos de \(nombre).")
                    .font(.app(.subheadline).weight(.semibold))
            }
            if intentoGuardar && !solicitud.aceptaAviso {
                Label("Debes aceptar el aviso para continuar.", systemImage: "exclamationmark.circle.fill")
                    .font(.app(.caption))
                    .foregroundColor(.brandRed)
            }
        }
        .padding(16)
        .tarjetaBorde(radio: 18)
    }

    private func autorizar() async {
        intentoGuardar = true
        guard solicitudFinal.esValida else { return }
        guardando = true
        defer { guardando = false }
        if let error = await onAutorizar(solicitudFinal) {
            errorServidor = error
        } else {
            dismiss()
        }
    }
}
