
import SwiftUI

struct ContentView: View {
    @AppStorage("onboardingCompletado") private var onboardingCompletado = false
    @State private var auth = AuthViewModel()
    @State private var familiaresStore = FamiliaresStore()
    @State private var preferencias = Preferencias.compartidas
    /// Código recibido por enlace `cruzcontigo://invitacion/CODIGO` (HU-17). Si aún no hay
    /// sesión, se conserva y se muestra al terminar de entrar.
    @State private var enlaceInvitacion: EnlaceInvitacion?

    struct EnlaceInvitacion: Identifiable {
        let id = UUID()
        let codigo: String
    }

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
        .onOpenURL { url in
            if let codigo = CodigoInvitacion.desdeEnlace(url) {
                enlaceInvitacion = EnlaceInvitacion(codigo: codigo)
            }
        }
        .sheet(item: Binding(
            get: { auth.estaAutenticado && onboardingCompletado ? enlaceInvitacion : nil },
            set: { enlaceInvitacion = $0 }
        )) { enlace in
            AceptarInvitacionView(codigoInicial: enlace.codigo)
        }
        .environment(auth)
        .environment(familiaresStore)
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
