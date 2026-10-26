//
//  ModuloViews.swift
//  CruzContigo
//

import SwiftUI

struct ModuloPendienteView: View {
    let modulo: Modulo
    let familiarID: UUID?
    var mostrarAtras = true

    @Environment(FamiliaresStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var familiar: Familiar? {
        familiarID.flatMap { id in store.familiares.first { $0.id == id } }
    }

    var body: some View {
        VStack(spacing: 0) {
            if mostrarAtras {
                HStack {
                    BrandBackButton { dismiss() }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }

            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.clear)
                        .frame(width: 96, height: 96)
                    Image(systemName: modulo.icono)
                        .icono(.destacado)
                        .foregroundColor(.brandRed)
                }
                .accessibilityHidden(true)
                Text(modulo.titulo)
                    .font(.app(.title).weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                if let familiar {
                    Text("de \(familiar.nombreCompleto)")
                        .font(.app(.headline))
                        .foregroundColor(.textoSuave)
                }
                Text(modulo.subtitulo)
                    .font(.app(.body))
                    .foregroundColor(.textoSuave)
                    .multilineTextAlignment(.center)
                InfoChip(texto: "Próximamente · Sprint \(modulo.sprint)", icono: "hammer.fill")
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}

struct ElegirFamiliarView: View {
    let modulo: Modulo

    @Environment(FamiliaresStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BrandBackButton { dismiss() }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(modulo.titulo.uppercased())
                            .font(.app(.caption))
                            .fontWeight(.bold)
                            .foregroundColor(.brandRed)
                        Text("¿De quién?")
                            .font(.app(.largeTitle).weight(.bold))
                        Text("Elige a la persona cuya información quieres consultar.")
                            .foregroundColor(.textoSuave)
                    }

                    VStack(spacing: 12) {
                        ForEach(store.familiares) { familiar in
                            NavigationLink(value: Ruta.modulo(modulo, familiarID: familiar.id)) {
                                FamiliarCard(familiar: familiar)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
    }
}
