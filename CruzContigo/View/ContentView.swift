
import SwiftUI

struct ContentView: View {
    @AppStorage("onboardingCompletado") private var onboardingCompletado = false
    @State private var familiaresStore = FamiliaresStore()
    @State private var recordatoriosStore = RecordatoriosStore()
    @State private var preferencias = Preferencias.compartidas

    var body: some View {
        Group {
            if onboardingCompletado {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlowView {
                    withAnimation {
                        onboardingCompletado = true
                    }
                }
                .transition(.opacity)
            }
        }
        .environment(familiaresStore)
        .environment(recordatoriosStore)
        .environment(preferencias)
        .aplicarPreferencias(preferencias)
        .environment(\.locale, Locale(identifier: "es_MX"))
    }
}

enum PasoOnboarding: Hashable {
    case seleccionarRol
}

struct OnboardingFlowView: View {
    let terminar: () -> Void

    @State private var ruta: [PasoOnboarding] = []

    var body: some View {
        NavigationStack(path: $ruta) {
            VerifyPhoneView(
                onVerificado: {
                    ruta.append(.seleccionarRol)
                }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PasoOnboarding.self) { paso in
                switch paso {
                case .seleccionarRol:
                    OnboardingRoleView {
                        terminar()
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
            }
        }
        .tint(.brandRed)
    }
}

#Preview {
   // ContentView()
}
