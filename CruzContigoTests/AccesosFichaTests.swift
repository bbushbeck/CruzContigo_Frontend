import Foundation
import Testing
@testable import CruzContigo

@MainActor
struct AccesosFichaTests {
    @MainActor
    private final class RepositorioFalso: AccesosRepository {
        var miembros: [MiembroAcceso] = []
        var enviadas: [SolicitudAcceso] = []
        var revocados: [UUID] = []

        func listar(familiarID: UUID) async throws -> RespuestaAccesos {
            RespuestaAccesos(versionAviso: AvisoPrivacidad.version, miembros: miembros)
        }

        func autorizar(_ solicitud: SolicitudAcceso, familiarID: UUID) async throws -> MiembroAcceso {
            enviadas.append(solicitud)
            return AccesosFichaTests.miembro(rol: solicitud.rol)
        }

        func revocar(miembroID: UUID, familiarID: UUID) async throws {
            revocados.append(miembroID)
        }

        func consentimientos(familiarID: UUID) async throws -> [RegistroConsentimiento] { [] }

        func estadoQR(familiarID: UUID) async throws -> EstadoQR {
            EstadoQR(consentido: false, fecha: nil, versionAviso: AvisoPrivacidad.version)
        }

        func cambiarQR(_ solicitud: SolicitudQR, familiarID: UUID) async throws -> EstadoQR {
            EstadoQR(consentido: solicitud.consentido, fecha: Date(), versionAviso: AvisoPrivacidad.version)
        }
    }

    static func miembro(rol: RolAcceso, esTuCuenta: Bool = false) -> MiembroAcceso {
        MiembroAcceso(id: UUID(), nombre: "Ana", telefono: "•••• 1234", rol: rol, relacion: nil,
                      estado: .activo, venceEn: nil, esTuCuenta: esTuCuenta)
    }

    private func familiar(rol: String?) -> Familiar {
        var familiar = Familiar(nombre: "Rosa", apellidos: "López", fechaNacimiento: Date(), parentesco: .madre, tipoCuidado: .adultoMayor)
        familiar.rol = rol
        return familiar
    }

    @Test("Autorizar exige teléfono de 10 dígitos y aceptar el aviso")
    func validacionSolicitud() {
        var solicitud = SolicitudAcceso(telefono: "81 1234 5678", rol: .cocuidador)
        #expect(!solicitud.esValida)
        solicitud.aceptaAviso = true
        #expect(solicitud.esValida)
        solicitud.telefono = "811234"
        #expect(!solicitud.esValida)
    }

    @Test("El acceso profesional dura de 1 a 30 días")
    func vigenciaProfesional() {
        var solicitud = SolicitudAcceso(telefono: "8112345678", rol: .profesional, aceptaAviso: true)
        #expect(!solicitud.esValida)
        solicitud.diasVigencia = 31
        #expect(!solicitud.esValida)
        solicitud.diasVigencia = 7
        #expect(solicitud.esValida)
    }

    @Test("No se puede retirar a la persona titular ni la propia cuenta")
    func revocables() {
        #expect(Self.miembro(rol: .cocuidador).revocable)
        #expect(!Self.miembro(rol: .titular).revocable)
        #expect(!Self.miembro(rol: .administrador, esTuCuenta: true).revocable)
    }

    @Test("El profesional solo ve la ficha y no la edita")
    func permisosProfesional() {
        let profesional = familiar(rol: "profesional")
        #expect(profesional.esProfesional)
        #expect(!profesional.puedeEditar)
        #expect(!profesional.puedeGestionarAccesos)
        #expect(profesional.modulosVisibles == [.fichaMedica])
        #expect(familiar(rol: "administrador").puedeGestionarAccesos)
        #expect(!familiar(rol: "cocuidador").puedeGestionarAccesos)
    }

    @Test("Decodifica la respuesta de la API de accesos")
    func decodificacion() throws {
        let json = """
        {"versionAviso":"2026-11","miembros":[{"id":"6f1c2b8e-1d2a-4c3b-9e8f-0a1b2c3d4e5f","nombre":"","telefono":"•••• 5678",
        "rol":"solo_lectura","relacion":null,"estado":"activo","venceEn":"2026-12-01T18:00:00Z","esTuCuenta":false}]}
        """
        let respuesta = try APIClient.decoder.decode(RespuestaAccesos.self, from: Data(json.utf8))
        #expect(respuesta.miembros.first?.rol == .soloLectura)
        #expect(respuesta.miembros.first?.nombreVisible == "•••• 5678")
        #expect(respuesta.miembros.first?.venceEn != nil)
    }

    @Test("Envía el teléfono limpio y la versión del aviso que se mostró")
    func autorizarLimpiaDatos() async {
        let repositorio = RepositorioFalso()
        let viewModel = AccesosFichaViewModel(familiarID: UUID(), repositorio: repositorio)
        let error = await viewModel.autorizar(
            SolicitudAcceso(telefono: "(81) 1234-5678", rol: .cocuidador, relacion: "  ", aceptaAviso: true)
        )
        #expect(error == nil)
        #expect(repositorio.enviadas.first?.telefono == "8112345678")
        #expect(repositorio.enviadas.first?.relacion == nil)
        #expect(repositorio.enviadas.first?.diasVigencia == nil)
        #expect(repositorio.enviadas.first?.versionAviso == AvisoPrivacidad.version)
    }

    @Test("Una solicitud inválida no llega al servidor")
    func autorizarInvalida() async {
        let repositorio = RepositorioFalso()
        let viewModel = AccesosFichaViewModel(familiarID: UUID(), repositorio: repositorio)
        let error = await viewModel.autorizar(SolicitudAcceso(telefono: "8112345678", rol: .cocuidador))
        #expect(error != nil)
        #expect(repositorio.enviadas.isEmpty)
    }

    @Test("Revocar quita el acceso de la lista")
    func revocar() async {
        let repositorio = RepositorioFalso()
        let cuidador = Self.miembro(rol: .cocuidador)
        repositorio.miembros = [Self.miembro(rol: .administrador, esTuCuenta: true), cuidador]
        let viewModel = AccesosFichaViewModel(familiarID: UUID(), repositorio: repositorio)
        await viewModel.cargar()
        await viewModel.revocar(cuidador)
        #expect(repositorio.revocados == [cuidador.id])
        #expect(!viewModel.miembros.contains(cuidador))
    }
}
