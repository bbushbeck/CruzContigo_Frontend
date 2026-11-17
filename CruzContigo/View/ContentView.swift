
import SwiftUI

struct ContentView: View {
    @AppStorage("onboardingCompletado") private var onboardingCompletado = false
    @State private var auth = AuthViewModel()
    @State private var familiaresStore = FamiliaresStore()
    @State private var recordatoriosStore = RecordatoriosStore()
    @State private var preferencias = Preferencias.compartidas

    var body: some View {
        Group {
            if auth.estaAutenticado && onboardingCompletado {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlowView(auth: auth) {
                    withAnimation {
                        onboardingCompletado = true
                    }
                }
                .transition(.opacity)
            }
        }
        .environment(auth)
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
    @Bindable var auth: AuthViewModel
    let terminar: () -> Void

    @State private var ruta: [PasoOnboarding] = []

    var body: some View {
        NavigationStack(path: $ruta) {
            VerifyPhoneView(
                viewModel: auth,
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
