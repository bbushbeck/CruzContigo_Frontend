//
//  InvitarView.swift
//  CruzContigo
//
//  HU-17: invitar por teléfono o con enlace, con un rol. El acceso temporal
//  vence solo en la fecha elegida (HU-26).
//

import Contacts
import SwiftUI

struct InvitarView: View {
    let nombre: String
    let invitar: (SolicitudInvitacion) async throws -> InvitacionCreada

    @Environment(\.dismiss) private var dismiss
    @State private var porTelefono = true
    @State private var telefono = ""
    @State private var rol: RolAcceso? = .cocuidador
    @State private var relacion = ""
    @State private var accesoHasta = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var permisoFicha = false
    @State private var aceptaAviso = false
    @State private var intentoGuardar = false
    @State private var guardando = false
    @State private var errorServidor: String?
    @State private var creada: InvitacionCreada?

    private var manana: Date { Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date() }
    private var limite: Date { Calendar.current.date(byAdding: .day, value: SolicitudInvitacion.diasMaximos, to: Date()) ?? Date() }

    private var solicitud: SolicitudInvitacion {
        let rolElegido = rol ?? .cocuidador
        // El acceso temporal termina al final del día elegido.
        let finDelDia = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: accesoHasta) ?? accesoHasta
        return SolicitudInvitacion(
            telefono: porTelefono ? telefono : nil,
            rol: rolElegido,
            relacion: relacion,
            accesoHasta: rolElegido == .temporal ? finDelDia : nil,
            permisoFicha: rolElegido == .temporal && permisoFicha,
            aceptaAviso: aceptaAviso
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(creada == nil ? "Cancelar" : "Listo") { dismiss() }
                    .foregroundColor(.brandRed)
                    .frame(minHeight: 44)
                Spacer()
                Text("Invitar").font(.app(.headline))
                Spacer()
                Button("Cancelar") {}.hidden()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            if let creada {
                InvitacionListaView(creada: creada, nombre: nombre) { dismiss() }
            } else {
                formulario
            }
        }
        .tint(.brandRed)
        .interactiveDismissDisabled(guardando)
        .alert("No se pudo invitar", isPresented: Binding(
            get: { errorServidor != nil },
            set: { if !$0 { errorServidor = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(errorServidor ?? "")
        }
    }

    private var formulario: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("¿A quién quieres invitar a cuidar a \(nombre)?")
                        .font(.app(.title2).weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Picker("Cómo invitar", selection: $porTelefono) {
                        Text("Por teléfono").tag(true)
                        Text("Con enlace").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if porTelefono {
                        VStack(alignment: .leading, spacing: 8) {
                            BrandTextField(
                                titulo: "Teléfono",
                                placeholder: "10 dígitos",
                                texto: $telefono,
                                obligatorio: true,
                                error: intentoGuardar && telefono.filter(\.isNumber).count != 10 ? "Escribe un teléfono de 10 dígitos." : nil,
                                teclado: .phonePad
                            )
                            Button {
                                SelectorContactos.presentar { contacto in
                                    if let numero = contacto.phoneNumbers.first?.value.stringValue {
                                        telefono = String(numero.filter(\.isNumber).suffix(10))
                                    }
                                }
                            } label: {
                                Label("Elegir de mis contactos", systemImage: "person.crop.circle.badge.plus")
                                    .font(.app(.subheadline).weight(.bold))
                                    .frame(minHeight: 44)
                            }
                            Text("Verá la invitación al entrar a la app con ese número. También te daremos un código para enviárselo.")
                                .font(.app(.footnote))
                                .foregroundColor(.textoSuave)
                        }
                    } else {
                        Text("Te daremos un código para enviarlo por WhatsApp o mensaje. Lo puede usar una sola persona.")
                            .font(.app(.subheadline))
                            .foregroundColor(.textoSuave)
                    }

                    FormFieldContainer(titulo: "¿Qué podrá hacer?", obligatorio: true) {
                        ChipSelector(opciones: RolAcceso.invitables, seleccion: $rol, titulo: \.titulo)
                        if let rol {
                            Text(rol.descripcion)
                                .font(.app(.footnote))
                                .foregroundColor(.textoSuave)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if rol == .temporal {
                        FormFieldContainer(titulo: "¿Hasta cuándo?", obligatorio: true) {
                            DatePicker("Acceso hasta", selection: $accesoHasta, in: manana...limite, displayedComponents: .date)
                                .font(.app(.body))
                                .frame(minHeight: 44)
                            Text("El acceso termina solo ese día a las 11:59 p. m.")
                                .font(.app(.footnote))
                                .foregroundColor(.textoSuave)
                        }
                        Toggle(isOn: $permisoFicha) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("También puede ver la ficha médica")
                                    .font(.app(.body).weight(.semibold))
                                Text("Tipo de sangre, alergias y enfermedades.")
                                    .font(.app(.footnote))
                                    .foregroundColor(.textoSuave)
                            }
                        }
                    }

                    BrandTextField(
                        titulo: "Relación con \(nombre) (opcional)",
                        placeholder: "Ej. Nieta, hijo, enfermera",
                        texto: $relacion
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Aviso de privacidad", systemImage: "lock.shield.fill")
                            .font(.app(.headline))
                        Text(AvisoPrivacidad.texto)
                            .font(.app(.footnote))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Versión \(AvisoPrivacidad.version)")
                            .font(.app(.caption))
                            .foregroundColor(.textoSuave)
                        Toggle(isOn: $aceptaAviso) {
                            Text("Leí el aviso y autorizo compartir la información de \(nombre).")
                                .font(.app(.subheadline).weight(.semibold))
                        }
                    }
                    .padding(16)
                    .tarjetaBorde(radio: 18)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 10) {
                if intentoGuardar, let error = solicitud.errores.first {
                    Text(error)
                        .font(.app(.footnote))
                        .foregroundColor(.brandRed)
                }
                PrimaryButton(title: guardando ? "Creando invitación…" : "Crear invitación") {
                    Task { await crear() }
                }
                .disabled(guardando)
                .opacity(guardando ? 0.7 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    private func crear() async {
        intentoGuardar = true
        guard solicitud.esValida else { return }
        guardando = true
        defer { guardando = false }
        do {
            creada = try await invitar(solicitud)
        } catch {
            errorServidor = error.localizedDescription
        }
    }
}

/// El código solo se ve aquí: el servidor guarda únicamente su hash.
private struct InvitacionListaView: View {
    let creada: InvitacionCreada
    let nombre: String
    let terminar: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .icono(.destacado)
                    .foregroundColor(.green)
                    .accessibilityHidden(true)
                Text("Invitación lista")
                    .font(.app(.title2).weight(.bold))
                Text("Envíala a quien quieres invitar. Al abrirla podrá ayudar a cuidar a \(nombre) como \(creada.invitacion.rol.titulo.lowercased()).")
                    .font(.app(.body))
                    .foregroundColor(.textoSuave)
                    .multilineTextAlignment(.center)

                VStack(spacing: 6) {
                    Text("Código")
                        .font(.app(.caption).weight(.bold))
                        .foregroundColor(.textoSuave)
                    Text(creada.codigo)
                        .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                        .textSelection(.enabled)
                        .accessibilityLabel("Código \(creada.codigo.map(String.init).joined(separator: " "))")
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .tarjetaBorde(radio: 18)

                ShareLink(item: creada.mensaje(para: nombre)) {
                    Label("Enviar invitación", systemImage: "square.and.arrow.up")
                        .font(.app(.headline))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.rojoSolido))
                }

                Text("Sirve una sola vez y vence el \(creada.invitacion.expiraEn.formatted(date: .long, time: .omitted)). Puedes cancelarla desde Red de cuidado.")
                    .font(.app(.footnote))
                    .foregroundColor(.textoSuave)
                    .multilineTextAlignment(.center)

                Button("Listo", action: terminar)
                    .font(.app(.headline))
                    .frame(minHeight: 44)
            }
            .padding(24)
        }
    }
}
