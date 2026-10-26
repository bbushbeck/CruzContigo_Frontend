//
//  MainTabView.swift
//  CruzContigo
//

import SwiftUI

enum Pestana: Hashable {
    case inicio, personas, recordatorios, mas
}

enum ClavesApp {
    static let personaSeleccionada = "personaSeleccionadaID"
    static let primerosPasosOcultos = "primerosPasosOcultos"
}

struct MainTabView: View {
    @State private var pestana: Pestana = .inicio

    init() {
        let apariencia = UITabBarAppearance()
        apariencia.configureWithOpaqueBackground()
        apariencia.backgroundColor = .systemBackground
        apariencia.shadowColor = .separator
        UITabBar.appearance().standardAppearance = apariencia
        UITabBar.appearance().scrollEdgeAppearance = apariencia
    }

    var body: some View {
        TabView(selection: $pestana) {
            Tab("Inicio", systemImage: "house.fill", value: .inicio) {
                DashboardView(pestana: $pestana)
            }
            Tab("Personas", systemImage: "person.2.fill", value: .personas) {
                PersonasView()
            }
            Tab("Recordatorios", systemImage: "bell.fill", value: .recordatorios) {
                NavigationStack {
                    RecordatoriosView(mostrarAtras: false)
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
            Tab("Más", systemImage: "line.3.horizontal", value: .mas) {
                MasView()
            }
        }
        .tint(.brandRed)
    }
}
