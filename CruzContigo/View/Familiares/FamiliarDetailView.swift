//
//  FamiliarDetailView.swift
//  CruzContigo
//

import SwiftUI

struct FamiliarDetailView: View {
    let familiarID: UUID

    @Environment(FamiliaresStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = FamiliarDetailViewModel()
    @State private var confirmarEliminar = false
    @State private var editando = false

    private var familiar: Familiar? {
        store.familiares.first { $0.id == familiarID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BrandBackButton { dismiss() }
                Spacer()
                if familiar?.puedeEditar == true {
                    Button("Editar") { editando = true }
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            if let familiar {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        perfil(familiar)
                        datos(familiar)
                        modulos(familiar)
                        eliminarBoton
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            } else {
                Spacer()
                Text("Este perfil ya no existe.")
                    .foregroundColor(.textoSuave)
                Spacer()
            }
        }
        .sheet(isPresented: $editando) {
            if let familiar { EditFamiliarView(familiar: familiar) }
        }
        .confirmationDialog(
            "¿Eliminar a \(familiar?.nombre ?? "este familiar")?",
            isPresented: $confirmarEliminar,
            titleVisibility: .visible
        ) {
            Button("Eliminar perfil", role: .destructive) {
                guard let familiar else { return }
                Task {
                    await viewModel.eliminar(familiar, usando: store) { dismiss() }
                }
            }
        } message: {
            Text("Se borrará su perfil y no se podrá recuperar.")
        }
    }

    private func perfil(_ familiar: Familiar) -> some View {
        VStack(spacing: 12) {
            FamiliarAvatar(familiar: familiar, tamano: 96)
            Text(familiar.nombreCompleto)
                .font(.app(.title).weight(.bold))
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                InfoChip(texto: familiar.parentesco.titulo, icono: "heart.fill")
                InfoChip(texto: familiar.tipoCuidado.titulo, icono: familiar.tipoCuidado.icono)
            }
            if let telefono = familiar.telefono, let url = URL(string: "tel://\(telefono)") {
                Link(destination: url) {
                    Label("Llamar a \(familiar.nombre)", systemImage: "phone.fill")
                        .font(.app(.subheadline).weight(.bold))
                        .foregroundColor(.brandRed)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(Color.tintaSuave))
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func datos(_ familiar: Familiar) -> some View {
        VStack(spacing: 0) {
            FilaDato(icono: "calendar", titulo: "Fecha de nacimiento",
                     valor: "\(familiar.fechaNacimiento.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "es_MX")))) · \(familiar.edad) años")
            Divider().padding(.leading, 52)
            FilaDato(icono: "phone.fill", titulo: "Teléfono",
                     valor: familiar.telefono.map(viewModel.formatearTelefono) ?? "Sin registrar")
            if let notas = familiar.notas {
                Divider().padding(.leading, 52)
                FilaDato(icono: "note.text", titulo: "Notas", valor: notas)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.borderGray, lineWidth: 1)
        )
    }

    private func modulos(_ familiar: Familiar) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SeccionHeader(titulo: "Su cuidado")
            VStack(spacing: 0) {
                ForEach(Array(Modulo.delPerfil.enumerated()), id: \.element) { indice, modulo in
                    if indice > 0 { Divider().padding(.leading, 72) }
                    NavigationLink(value: Ruta.modulo(modulo, familiarID: familiar.id)) {
                        ModuloFila(modulo: modulo)
                    }
                    .buttonStyle(.plain)
                }
            }
            .tarjetaBorde()
        }
    }

    private var eliminarBoton: some View {
        Button(role: .destructive) {
            confirmarEliminar = true
        } label: {
            Label("Eliminar perfil", systemImage: "trash")
                .font(.app(.subheadline).weight(.bold))
                .foregroundColor(.brandRed)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
    }
}

struct FilaDato: View {
    let icono: String
    let titulo: String
    let valor: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icono)
                .icono(.mediano)
                .foregroundColor(.brandRed)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.app(.caption)).foregroundColor(.textoSuave)
                Text(valor).font(.app(.body))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
