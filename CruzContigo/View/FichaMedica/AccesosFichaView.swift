//
//  AccesosFichaView.swift
//  CruzContigo
//
//  HU-08: la persona titular (o su responsable) autoriza y retira accesos a la ficha.
//

import SwiftUI

struct AccesosFichaView: View {
    let nombre: String

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AccesosFichaViewModel
    @State private var autorizando = false
    @State private var porRevocar: MiembroAcceso?

    init(familiarID: UUID, nombre: String) {
        self.nombre = nombre
        _viewModel = State(initialValue: AccesosFichaViewModel(familiarID: familiarID))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cerrar") { dismiss() }
                    .foregroundColor(.brandRed)
                    .frame(minHeight: 44)
                Spacer()
                Text("Accesos").font(.app(.headline))
                Spacer()
                Button("Cerrar") {}.hidden()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            switch viewModel.estado {
            case .cargando:
                Spacer()
                ProgressView("Cargando accesos…")
                Spacer()
            case .error(let mensaje):
                Spacer()
                EstadoErrorView(mensaje: mensaje) {
                    Task { await viewModel.cargar() }
                }
                Spacer()
            case .listo:
                contenido
            }
        }
        .tint(.brandRed)
        .task { await viewModel.cargar() }
        .sheet(isPresented: $autorizando) {
            AutorizarAccesoView(nombre: nombre) { solicitud in
                await viewModel.autorizar(solicitud)
            }
        }
        .confirmationDialog(
            "¿Retirar el acceso de \(porRevocar?.nombreVisible ?? "esta persona")?",
            isPresented: Binding(
                get: { porRevocar != nil },
                set: { if !$0 { porRevocar = nil } }
            ),
            titleVisibility: .visible,
            presenting: porRevocar
        ) { miembro in
            Button("Retirar acceso", role: .destructive) {
                Task { await viewModel.revocar(miembro) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { _ in
            Text("Dejará de ver la información de \(nombre) desde su siguiente consulta. Quedará registrado.")
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

    private var contenido: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("¿Quién puede ver los datos médicos de \(nombre)?")
                        .font(.app(.title2).weight(.bold))
                    Text("Tú decides quién accede. Puedes retirar un acceso en cualquier momento y se aplica de inmediato.")
                        .font(.app(.subheadline))
                        .foregroundColor(.textoSuave)
                }

                SeccionFicha(titulo: "Con acceso", icono: "person.2.fill", vacio: "Nadie más tiene acceso") {
                    ForEach(Array(viewModel.activos.enumerated()), id: \.element.id) { indice, miembro in
                        if indice > 0 { Divider() }
                        FilaMiembro(miembro: miembro) { porRevocar = miembro }
                    }
                } esVacio: { viewModel.activos.isEmpty }

                if !viewModel.vencidos.isEmpty {
                    SeccionFicha(titulo: "Vencidos", icono: "clock.badge.xmark", vacio: "") {
                        ForEach(Array(viewModel.vencidos.enumerated()), id: \.element.id) { indice, miembro in
                            if indice > 0 { Divider() }
                            FilaMiembro(miembro: miembro) { porRevocar = miembro }
                        }
                    } esVacio: { false }
                }

                if viewModel.avisoDesactualizado {
                    Label("El aviso de privacidad cambió. Actualiza la app para autorizar nuevos accesos.", systemImage: "exclamationmark.triangle.fill")
                        .font(.app(.footnote))
                        .foregroundColor(.brandRed)
                } else {
                    PrimaryButton(title: "Autorizar a alguien") { autorizando = true }
                        .disabled(viewModel.procesando)
                        .opacity(viewModel.procesando ? 0.7 : 1)
                }

                SeccionFicha(titulo: "Historial de consentimientos", icono: "checkmark.seal.fill", vacio: "Aún no hay movimientos") {
                    ForEach(Array(viewModel.historial.enumerated()), id: \.element.id) { indice, registro in
                        if indice > 0 { Divider() }
                        FilaConsentimiento(registro: registro)
                    }
                } esVacio: { viewModel.historial.isEmpty }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .refreshable { await viewModel.cargar() }
    }
}

private struct FilaMiembro: View {
    let miembro: MiembroAcceso
    let revocar: () -> Void

    private var detalle: String {
        var partes = [miembro.rol.titulo]
        if let relacion = miembro.relacion, !relacion.isEmpty { partes.append(relacion.capitalized) }
        if miembro.estado == .invitado { partes.append("Invitación pendiente") }
        return partes.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(miembro.esTuCuenta ? "\(miembro.nombreVisible) (tú)" : miembro.nombreVisible)
                    .font(.app(.body).weight(.semibold))
                Text(detalle)
                    .font(.app(.caption))
                    .foregroundColor(.textoSuave)
                if let venceEn = miembro.venceEn {
                    Text(miembro.estado == .vencido
                         ? "Venció el \(venceEn.formatted(date: .abbreviated, time: .omitted))"
                         : "Vence el \(venceEn.formatted(date: .abbreviated, time: .shortened))")
                        .font(.app(.caption))
                        .foregroundColor(miembro.estado == .vencido ? .brandRed : .textoSuave)
                }
            }
            Spacer()
            if miembro.revocable {
                Button("Retirar", action: revocar)
                    .font(.app(.subheadline).weight(.bold))
                    .foregroundColor(.brandRed)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Retirar el acceso de \(miembro.nombreVisible)")
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }
}

private struct FilaConsentimiento: View {
    let registro: RegistroConsentimiento

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: registro.accion == .autorizar ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(registro.accion == .autorizar ? .green : .brandRed)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(registro.descripcion)
                    .font(.app(.subheadline))
                Text("\(registro.fecha.formatted(date: .abbreviated, time: .shortened)) · Aviso \(registro.versionAviso)")
                    .font(.app(.caption))
                    .foregroundColor(.textoSuave)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
