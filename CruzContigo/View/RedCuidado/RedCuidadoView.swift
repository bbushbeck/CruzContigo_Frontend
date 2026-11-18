//
//  RedCuidadoView.swift
//  CruzContigo
//
//  HU-17: quién cuida a cada persona, invitaciones pendientes e invitaciones recibidas.
//

import SwiftUI

struct RedCuidadoView: View {
    let familiarIDInicial: UUID?

    @Environment(FamiliaresStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = RedCuidadoViewModel()
    @State private var seleccion: UUID?
    @State private var invitando = false
    @State private var canjeando = false
    @State private var administrandoAccesos = false
    @State private var viendoContactos = false
    @State private var porCancelar: InvitacionEnviada?
    @State private var aceptada: ResultadoAceptacion?

    init(familiarID: UUID? = nil) {
        familiarIDInicial = familiarID
        _seleccion = State(initialValue: familiarID)
    }

    /// Un acceso temporal o profesional no ve la red (minimización por rol).
    private var personas: [Familiar] { store.familiares.filter(\.veRedDeCuidado) }

    private var seleccionada: Familiar? {
        personas.first { $0.id == seleccion } ?? personas.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BrandBackButton { dismiss() }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Red de cuidado")
                            .font(.app(.largeTitle).weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                        Text("Reparte el cuidado con tu familia. Cada quien ve solo lo que su rol permite.")
                            .font(.app(.body))
                            .foregroundColor(.textoSuave)
                    }

                    if !viewModel.recibidas.isEmpty {
                        invitacionesRecibidas
                    }

                    Button { canjeando = true } label: {
                        Label("Tengo un código de invitación", systemImage: "ticket.fill")
                            .font(.app(.headline))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.tintaSuave))
                    }

                    if personas.isEmpty {
                        Text("Cuando agregues a una persona o aceptes una invitación, aquí verás quién más la cuida.")
                            .font(.app(.subheadline))
                            .foregroundColor(.textoSuave)
                    } else {
                        if personas.count > 1 {
                            ChipSelector(
                                opciones: personas,
                                seleccion: Binding(get: { seleccionada }, set: { seleccion = $0?.id }),
                                titulo: \.nombre
                            )
                        }
                        if let persona = seleccionada {
                            red(de: persona)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .refreshable { await recargar() }
        }
        .task { await recargar() }
        .onChange(of: seleccion) {
            Task { await cargarRed() }
        }
        .sheet(isPresented: $invitando) {
            if let persona = seleccionada {
                InvitarView(nombre: persona.nombre) { solicitud in
                    try await viewModel.invitar(solicitud, familiarID: persona.id)
                }
            }
        }
        .sheet(isPresented: $canjeando, onDismiss: { Task { await recargar() } }) {
            AceptarInvitacionView(codigoInicial: nil)
        }
        .sheet(isPresented: $administrandoAccesos, onDismiss: { Task { await cargarRed() } }) {
            if let persona = seleccionada {
                AccesosFichaView(familiarID: persona.id, nombre: persona.nombre)
            }
        }
        .sheet(isPresented: $viendoContactos) {
            if let persona = seleccionada {
                ContactosEmergenciaView(familiarID: persona.id, nombre: persona.nombre, puedeEditar: persona.puedeEditar)
            }
        }
        .confirmationDialog(
            "¿Cancelar la invitación?",
            isPresented: Binding(get: { porCancelar != nil }, set: { if !$0 { porCancelar = nil } }),
            titleVisibility: .visible,
            presenting: porCancelar
        ) { invitacion in
            Button("Cancelar invitación", role: .destructive) {
                if let persona = seleccionada {
                    Task { await viewModel.cancelar(invitacion, familiarID: persona.id) }
                }
            }
            Button("Volver", role: .cancel) {}
        } message: { _ in
            Text("El código dejará de funcionar.")
        }
        .alert("Ya formas parte de la red", isPresented: Binding(
            get: { aceptada != nil },
            set: { if !$0 { aceptada = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text("Ahora ayudas a cuidar a \(aceptada?.nombre ?? "esta persona") como \(aceptada?.rol.titulo.lowercased() ?? "integrante").")
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

    private func recargar() async {
        await viewModel.cargarRecibidas()
        await cargarRed()
    }

    private func cargarRed() async {
        if let persona = seleccionada {
            await viewModel.cargarRed(familiarID: persona.id)
        }
    }

    // MARK: - Invitaciones recibidas

    private var invitacionesRecibidas: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Te invitaron", systemImage: "envelope.badge.fill")
                .font(.app(.headline))
            ForEach(viewModel.recibidas) { invitacion in
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(invitacion.invitadaPor) te invita a cuidar a \(invitacion.familiarNombre)")
                        .font(.app(.body).weight(.semibold))
                    Text(invitacion.rol.titulo + (invitacion.accesoHasta.map { " · hasta el \($0.formatted(date: .abbreviated, time: .omitted))" } ?? ""))
                        .font(.app(.subheadline))
                        .foregroundColor(.textoSuave)
                    HStack(spacing: 10) {
                        Button("No, gracias") {
                            Task { await viewModel.rechazar(invitacion) }
                        }
                        .font(.app(.subheadline).weight(.bold))
                        .foregroundColor(.brandRed)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.tintaSuave))

                        Button("Aceptar") {
                            Task {
                                if let resultado = await viewModel.aceptar(invitacion) {
                                    await store.cargar()
                                    seleccion = resultado.familiarID
                                    aceptada = resultado
                                }
                            }
                        }
                        .font(.app(.subheadline).weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.rojoSolido))
                    }
                    .disabled(viewModel.procesando)
                }
                .padding(16)
                .tarjetaBorde(radio: 18)
            }
        }
    }

    // MARK: - Red de la persona seleccionada

    @ViewBuilder
    private func red(de persona: Familiar) -> some View {
        switch viewModel.estadoRed {
        case .cargando:
            ProgressView("Cargando red…")
                .frame(maxWidth: .infinity, minHeight: 120)
        case .error(let mensaje):
            EstadoErrorView(mensaje: mensaje) {
                Task { await cargarRed() }
            }
        case .listo:
            if let red = viewModel.red {
                VStack(alignment: .leading, spacing: 20) {
                    SeccionFicha(titulo: "Quién cuida a \(persona.nombre)", icono: "person.3.fill", vacio: "Solo tú por ahora") {
                        ForEach(Array(red.miembros.enumerated()), id: \.element.id) { indice, miembro in
                            if indice > 0 { Divider() }
                            FilaIntegrante(miembro: miembro)
                        }
                    } esVacio: { red.miembros.isEmpty }

                    Button { viendoContactos = true } label: {
                        Label("Contactos de emergencia", systemImage: "phone.badge.waveform.fill")
                            .font(.app(.headline))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.tintaSuave))
                    }
                    .accessibilityHint("A quién llamar si a \(persona.nombre) le pasa algo")

                    if red.puedeInvitar {
                        if !red.invitaciones.isEmpty {
                            SeccionFicha(titulo: "Invitaciones pendientes", icono: "hourglass", vacio: "") {
                                ForEach(Array(red.invitaciones.enumerated()), id: \.element.id) { indice, invitacion in
                                    if indice > 0 { Divider() }
                                    FilaInvitacion(invitacion: invitacion) { porCancelar = invitacion }
                                }
                            } esVacio: { false }
                        }

                        PrimaryButton(title: "Invitar a alguien") { invitando = true }

                        Button("Retirar o cambiar accesos") { administrandoAccesos = true }
                            .font(.app(.subheadline).weight(.bold))
                            .foregroundColor(.brandRed)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        Label("Solo la persona titular o su responsable puede invitar.", systemImage: "info.circle")
                            .font(.app(.footnote))
                            .foregroundColor(.textoSuave)
                    }
                }
            }
        }
    }
}

private struct FilaIntegrante: View {
    let miembro: MiembroAcceso

    private var detalle: String {
        var partes = [miembro.rol.titulo]
        if let relacion = miembro.relacion, !relacion.isEmpty { partes.append(relacion.capitalized) }
        if let venceEn = miembro.venceEn {
            partes.append(miembro.estado == .vencido
                          ? "venció el \(venceEn.formatted(date: .abbreviated, time: .omitted))"
                          : "hasta el \(venceEn.formatted(date: .abbreviated, time: .omitted))")
        }
        return partes.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(miembro.esTuCuenta ? "\(miembro.nombreVisible) (tú)" : miembro.nombreVisible)
                .font(.app(.body).weight(.semibold))
            Text(detalle)
                .font(.app(.caption))
                .foregroundColor(miembro.estado == .vencido ? .brandRed : .textoSuave)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct FilaInvitacion: View {
    let invitacion: InvitacionEnviada
    let cancelar: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(invitacion.destino)
                    .font(.app(.body).weight(.semibold))
                Text("\(invitacion.rol.titulo) · el código vence el \(invitacion.expiraEn.formatted(date: .abbreviated, time: .omitted))")
                    .font(.app(.caption))
                    .foregroundColor(.textoSuave)
            }
            Spacer()
            Button("Cancelar", action: cancelar)
                .font(.app(.subheadline).weight(.bold))
                .foregroundColor(.brandRed)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Cancelar la invitación a \(invitacion.destino)")
        }
        .padding(.vertical, 8)
    }
}
