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
    @Environment(Preferencias.self) private var preferencias
    @Environment(FamiliaresStore.self) private var familiares
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(ClavesApp.personaSeleccionada) private var seleccionID = ""
    @State private var pestana: Pestana = .inicio
    @State private var rutaInicio: [Ruta] = []
    @State private var mostrarFrida = false
    @State private var destinoFrida: Ruta?
    @State private var solicitudFrida: SolicitudDeFrida?
    @State private var solicitudes = SolicitudesDeFrida.compartidas

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
                DashboardView(pestana: $pestana, ruta: $rutaInicio, hablarConFrida: { mostrarFrida = true })
            }
            if !preferencias.lecturaFacil {
                Tab("Personas", systemImage: "person.2.fill", value: .personas) {
                    PersonasView()
                }
                Tab("Recordatorios", systemImage: "bell.fill", value: .recordatorios) {
                    NavigationStack {
                        RecordatoriosView(mostrarAtras: false)
                            .toolbar(.hidden, for: .navigationBar)
                    }
                }
            }
            Tab("Más", systemImage: "line.3.horizontal", value: .mas) {
                MasView()
            }
        }
        .tint(.brandRed)
        .onChange(of: solicitudEnPrimerPlano, initial: true) { _, pendiente in
            guard pendiente != nil, let solicitud = solicitudes.tomarSolicitud() else { return }
            pestana = .inicio
            if solicitud.pregunta != nil { solicitudFrida = solicitud }
            mostrarFrida = true
        }
        .sheet(isPresented: $mostrarFrida, onDismiss: navegarDesdeFrida) {
            FridaView(familiarSeleccionado: familiarSeleccionado, solicitud: $solicitudFrida) { destino in
                destinoFrida = destino
                mostrarFrida = false
            }
        }
    }

    private var familiarSeleccionado: UUID? {
        familiares.familiares.first { $0.id.uuidString == seleccionID }?.id ?? familiares.familiares.first?.id
    }

    private var solicitudEnPrimerPlano: SolicitudDeFrida? {
        scenePhase == .active ? solicitudes.pendiente : nil
    }

    private func navegarDesdeFrida() {
        solicitudFrida = nil
        guard let destinoFrida else { return }
        rutaInicio.append(destinoFrida)
        self.destinoFrida = nil
    }
}
