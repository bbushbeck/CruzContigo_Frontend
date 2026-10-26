//
//  PersonasView.swift
//  CruzContigo
//

import SwiftUI

struct PersonasView: View {
    @Environment(FamiliaresStore.self) private var store
    @State private var ruta: [Ruta] = []

    var body: some View {
        NavigationStack(path: $ruta) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Personas")
                            .font(.app(.largeTitle).weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        NavigationLink(value: Ruta.agregarFamiliar) {
                            EnlaceTexto(titulo: "Agregar", icono: "plus")
                        }
                    }

                    if store.familiares.isEmpty {
                        EstadoVacioFamiliares {
                            ruta.append(.agregarFamiliar)
                        }
                    } else {
                        Text("\(store.familiares.count) persona\(store.familiares.count == 1 ? "" : "s") a tu cuidado")
                            .font(.app(.subheadline))
                            .foregroundColor(.textoSuave)
                        VStack(spacing: 12) {
                            ForEach(store.familiares) { familiar in
                                NavigationLink(value: Ruta.familiar(familiar.id)) {
                                    FamiliarCard(familiar: familiar)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .fondoBarraEstado()
            .refreshable { await store.cargar() }
            .toolbar(.hidden, for: .navigationBar)
            .conDestinos()
        }
    }
}

struct MasView: View {
    @State private var ruta: [Ruta] = []
    @State private var confirmarCierre = false
    @AppStorage("onboardingCompletado") private var onboardingCompletado = true

    var body: some View {
        NavigationStack(path: $ruta) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Más")
                        .font(.app(.largeTitle).weight(.bold))
                        .accessibilityAddTraits(.isHeader)

                    VStack(spacing: 0) {
                        ForEach(Array(Modulo.generales.enumerated()), id: \.element) { indice, modulo in
                            if indice > 0 { Divider().padding(.leading, 72) }
                            NavigationLink(value: Ruta.modulo(modulo, familiarID: nil)) {
                                ModuloFila(modulo: modulo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .tarjetaBorde()

                    Button(role: .destructive) {
                        confirmarCierre = true
                    } label: {
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.app(.headline))
                            .foregroundColor(.brandRed)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .tarjetaBorde(radio: 16)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill").font(.app(.caption))
                        Text("Tu información se mantiene protegida.").font(.app(.footnote))
                    }
                    .foregroundColor(.textoSuave)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .fondoBarraEstado()
            .toolbar(.hidden, for: .navigationBar)
            .conDestinos()
            .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmarCierre, titleVisibility: .visible) {
                Button("Cerrar sesión", role: .destructive) {
                    withAnimation { onboardingCompletado = false }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Tendrás que verificar tu número de nuevo para entrar.")
            }
        }
    }
}
