import Testing
@testable import CruzContigo

@MainActor
struct AuthTests {
    @Test("Solo se puede solicitar código con un teléfono de al menos 10 dígitos")
    func puedeSolicitarCodigo() {
        let viewModel = AuthViewModel()

        viewModel.telefono = "81 12"
        #expect(viewModel.puedeSolicitarCodigo == false)

        viewModel.telefono = "81 1234 5678"
        #expect(viewModel.puedeSolicitarCodigo == true)
    }
}
