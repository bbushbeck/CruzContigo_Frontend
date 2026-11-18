//
//  AceptarInvitacionView.swift
//  CruzContigo
//
//  HU-17: la persona invitada escribe el código (o abre el enlace), ve a quién
//  cuidará y con qué rol, y acepta.
//

import SwiftUI

struct AceptarInvitacionView: View {
    let codigoInicial: String?

    @Environment(FamiliaresStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var codigo: String
    @State private var vistaPrevia: InvitacionRecibida?
    @State private var aceptada: ResultadoAceptacion?
    @State private var cargando = false
    @State private var error: String?

    private let repositorio: RedCuidadoRepository

    init(codigoInicial: String?, repositorio: RedCuidadoRepository = Repositorios.redCuidado()) {
        self.codigoInicial = codigoInicial
        self.repositorio = repositorio
        _codigo = State(initialValue: CodigoInvitacion.formatear(codigoInicial ?? ""))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(aceptada == nil ? "Cancelar" : "Listo") { dismiss() }
                    .foregroundColor(.brandRed)
                    .frame(minHeight: 44)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let aceptada {
                        listo(aceptada)
                    } else if let vistaPrevia {
                        previa(vistaPrevia)
                    } else {
                        escribirCodigo
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .tint(.brandRed)
        .task {
            if codigoInicial != nil, CodigoInvitacion.esCompleto(codigo) { await consultar() }
        }
        .alert("No se pudo abrir la invitación", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private var escribirCodigo: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Escribe el código de invitación")
                .font(.app(.title2).weight(.bold))
            Text("Son 10 letras y números que te enviaron por mensaje.")
                .font(.app(.body))
                .foregroundColor(.textoSuave)
            TextField("ABCDE-FGHJK", text: $codigo)
                .font(.system(.title, design: .monospaced).weight(.bold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(16)
                .fieldBorder(false)
                .onChange(of: codigo) { _, nuevo in
                    let formateado = CodigoInvitacion.formatear(nuevo)
                    if formateado != nuevo { codigo = formateado }
                }
                .accessibilityLabel("Código de invitación")
            PrimaryButton(title: cargando ? "Buscando…" : "Ver invitación") {
                Task { await consultar() }
            }
            .disabled(!CodigoInvitacion.esCompleto(codigo) || cargando)
            .opacity(!CodigoInvitacion.esCompleto(codigo) || cargando ? 0.5 : 1)
        }
    }

    private func previa(_ invitacion: InvitacionRecibida) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("\(invitacion.invitadaPor) te invita a cuidar a \(invitacion.familiarNombre)")
                .font(.app(.title2).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text(invitacion.rol.titulo)
                    .font(.app(.headline))
                Text(invitacion.rol.descripcion)
                    .font(.app(.subheadline))
                    .foregroundColor(.textoSuave)
                    .fixedSize(horizontal: false, vertical: true)
                if let hasta = invitacion.accesoHasta {
                    Label("Tu acceso termina el \(hasta.formatted(date: .long, time: .shortened))", systemImage: "clock")
                        .font(.app(.subheadline))
                }
                if invitacion.rol == .temporal {
                    Label(invitacion.permisoFicha ? "Incluye la ficha médica" : "No incluye la ficha médica",
                          systemImage: invitacion.permisoFicha ? "checkmark.circle" : "xmark.circle")
                        .font(.app(.subheadline))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tarjetaBorde(radio: 18)

            Text("Al aceptar, verás información de salud de \(invitacion.familiarNombre). Úsala solo para su cuidado.")
                .font(.app(.footnote))
                .foregroundColor(.textoSuave)

            PrimaryButton(title: cargando ? "Aceptando…" : "Aceptar invitación") {
                Task { await aceptar() }
            }
            .disabled(cargando)
            Button("No, gracias") { dismiss() }
                .font(.app(.headline))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func listo(_ resultado: ResultadoAceptacion) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .icono(.destacado)
                .foregroundColor(.brandRed)
                .accessibilityHidden(true)
            Text("Ya formas parte de la red")
                .font(.app(.title2).weight(.bold))
            Text("Ahora ayudas a cuidar a \(resultado.nombre). La encontrarás en Inicio.")
                .font(.app(.body))
                .foregroundColor(.textoSuave)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Listo") { dismiss() }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func consultar() async {
        cargando = true
        defer { cargando = false }
        do {
            vistaPrevia = try await repositorio.consultar(codigo: codigo)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func aceptar() async {
        cargando = true
        defer { cargando = false }
        do {
            aceptada = try await repositorio.aceptar(codigo: codigo)
            await store.cargar()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
