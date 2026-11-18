import Foundation
import Testing
@testable import CruzContigo

@MainActor
struct RedCuidadoTests {
    private func familiar(rol: String?, permisoFicha: Bool? = nil) -> Familiar {
        var familiar = Familiar(nombre: "Rosa", apellidos: "López", fechaNacimiento: Date(), parentesco: .madre, tipoCuidado: .adultoMayor)
        familiar.rol = rol
        familiar.permisoFicha = permisoFicha
        return familiar
    }

    // MARK: - Invitaciones (HU-17)

    @Test("El código se escribe en dos bloques y se compara sin guiones")
    func codigo() {
        #expect(CodigoInvitacion.formatear("abcde fghjk") == "ABCDE-FGHJK")
        #expect(CodigoInvitacion.normalizar("ABCDE-FGHJK") == "ABCDEFGHJK")
        #expect(CodigoInvitacion.esCompleto("abcde-fghjk"))
        #expect(!CodigoInvitacion.esCompleto("ABCDE"))
    }

    @Test("Solo los enlaces de invitación de la app abren una invitación")
    func enlace() throws {
        #expect(CodigoInvitacion.desdeEnlace(try #require(URL(string: "cruzcontigo://invitacion/ABCDEFGHJK"))) == "ABCDEFGHJK")
        #expect(CodigoInvitacion.desdeEnlace(try #require(URL(string: "cruzcontigo://otra/ABCDEFGHJK"))) == nil)
        #expect(CodigoInvitacion.desdeEnlace(try #require(URL(string: "https://invitacion/ABCDEFGHJK"))) == nil)
        #expect(CodigoInvitacion.desdeEnlace(try #require(URL(string: "cruzcontigo://invitacion/ABC"))) == nil)
    }

    @Test("Una invitación temporal exige una fecha futura de máximo un año")
    func temporal() {
        var solicitud = SolicitudInvitacion(rol: .temporal, aceptaAviso: true)
        #expect(!solicitud.esValida)
        solicitud.accesoHasta = Date().addingTimeInterval(-60)
        #expect(!solicitud.esValida)
        solicitud.accesoHasta = Date().addingTimeInterval(400 * 86_400)
        #expect(!solicitud.esValida)
        solicitud.accesoHasta = Date().addingTimeInterval(3 * 86_400)
        #expect(solicitud.esValida)
    }

    @Test("Sin aceptar el aviso o con teléfono incompleto no se invita")
    func validaciones() {
        #expect(!SolicitudInvitacion(aceptaAviso: false).esValida)
        #expect(!SolicitudInvitacion(telefono: "81123", aceptaAviso: true).esValida)
        #expect(SolicitudInvitacion(telefono: "81 1234 5678", aceptaAviso: true).esValida)
        #expect(SolicitudInvitacion(telefono: nil, aceptaAviso: true).esValida)
    }

    @Test("Fuera del rol temporal no se envía vencimiento ni permiso de ficha")
    func limpia() {
        let solicitud = SolicitudInvitacion(telefono: "(81) 1234-5678", rol: .cocuidador, relacion: "  ",
                                            accesoHasta: Date(), permisoFicha: true, aceptaAviso: true)
        let limpia = RedCuidadoViewModel.limpia(solicitud)
        #expect(limpia.telefono == "8112345678")
        #expect(limpia.relacion == nil)
        #expect(limpia.accesoHasta == nil)
        #expect(!limpia.permisoFicha)
    }

    @Test("Decodifica la invitación creada con su código y enlace")
    func decodificaCreada() throws {
        let json = """
        {"invitacion":{"id":"6f1c2b8e-1d2a-4c3b-9e8f-0a1b2c3d4e5f","telefono":"•••• 5678","rol":"temporal","relacion":null,
        "accesoHasta":"2026-12-01T23:59:00Z","permisoFicha":false,"expiraEn":"2026-11-24T18:00:00Z"},
        "codigo":"ABCDE-FGHJK","enlace":"cruzcontigo://invitacion/ABCDEFGHJK"}
        """
        let creada = try APIClient.decoder.decode(InvitacionCreada.self, from: Data(json.utf8))
        #expect(creada.invitacion.rol == .temporal)
        #expect(creada.mensaje(para: "Rosa").contains("ABCDE-FGHJK"))
        #expect(creada.mensaje(para: "Rosa").contains(creada.enlace))
    }

    // MARK: - Lo que ve cada rol (HU-17, HU-26)

    @Test("El acceso temporal no ve la ficha salvo que se le permita, ni la red")
    func modulosTemporal() {
        let sinFicha = familiar(rol: "temporal")
        #expect(!sinFicha.modulosVisibles.contains(.fichaMedica))
        #expect(!sinFicha.modulosVisibles.contains(.emergencia))
        #expect(sinFicha.modulosVisibles.contains(.diario))
        #expect(!sinFicha.veRedDeCuidado)
        #expect(sinFicha.puedeEscribirDiario)
        #expect(familiar(rol: "temporal", permisoFicha: true).modulosVisibles.contains(.fichaMedica))
    }

    @Test("Solo lectura ve todo pero no escribe en el diario")
    func soloLectura() {
        let lectura = familiar(rol: "solo_lectura")
        #expect(lectura.modulosVisibles == Modulo.delPerfil)
        #expect(!lectura.puedeEscribirDiario)
        #expect(lectura.veRedDeCuidado)
    }

    // MARK: - Contactos de emergencia (RF-15)

    @Test("La ficha de emergencia lista los contactos por prioridad y al final su teléfono")
    func contactosEnFicha() {
        var persona = familiar(rol: "titular")
        persona.telefono = "8100000000"
        let registrados = [
            ContactoRegistrado(id: UUID(), nombre: "Pedro", telefono: "8122222222", parentesco: nil, prioridad: 2),
            ContactoRegistrado(id: UUID(), nombre: "Laura", telefono: "8111111111", parentesco: "Hija", prioridad: 1),
        ]
        let resumen = FichaEmergencia.generar(familiar: persona, ficha: nil, medicamentos: [], qrConsentido: false, contactos: registrados)
        #expect(resumen.contactos.map(\.nombre) == ["Laura", "Pedro", "Rosa"])
        #expect(resumen.contactos[0].detalle == "Hija")
        #expect(resumen.contactos[1].detalle == "Contacto 2")
        #expect(resumen.contactos.last?.esPropio == true)
    }

    @Test("Un contacto necesita nombre y teléfono; se limpia antes de enviarlo")
    func contacto() {
        #expect(!SolicitudContacto(nombre: "L", telefono: "8111111111").esValida)
        #expect(!SolicitudContacto(nombre: "Laura", telefono: "123").esValida)
        let limpia = SolicitudContacto(nombre: " Laura ", telefono: "(81) 1111-1111", parentesco: " ").limpia
        #expect(limpia.nombre == "Laura")
        #expect(limpia.telefono == "8111111111")
        #expect(limpia.parentesco == nil)
    }

    // MARK: - Diario (HU-13)

    @Test("Una nota vacía o con fecha futura no se guarda")
    func nota() {
        #expect(!SolicitudNota(texto: "   ").esValida)
        #expect(!SolicitudNota(texto: "Comió bien", fecha: Date().addingTimeInterval(3600)).esValida)
        #expect(SolicitudNota(categoria: .animo, texto: "Contenta").esValida)
        #expect(!SolicitudNota(texto: String(repeating: "a", count: 2001)).esValida)
    }

    @Test("Decodifica una nota con su autor")
    func decodificaNota() throws {
        let json = """
        {"id":"6f1c2b8e-1d2a-4c3b-9e8f-0a1b2c3d4e5f","familiarID":"7f1c2b8e-1d2a-4c3b-9e8f-0a1b2c3d4e5f","categoria":"sueno",
        "texto":"Durmió bien","fecha":"2026-11-17T08:00:00Z","creadoEn":"2026-11-17T08:01:00Z","editadoEn":null,
        "autor":{"nombre":"Ana","esTuyo":false}}
        """
        let nota = try APIClient.decoder.decode(NotaDiario.self, from: Data(json.utf8))
        #expect(nota.categoria == .sueno)
        #expect(nota.autor.nombre == "Ana")
        #expect(!nota.autor.esTuyo)
    }

    @Test("El diario agrupa las notas por día, el más reciente primero")
    func agrupaPorDia() async {
        let familiarID = UUID()
        let ahora = Date()
        let ayer = ahora.addingTimeInterval(-86_400)
        let autor = NotaDiario.Autor(nombre: "Ana", esTuyo: true)
        let notas = [ayer, ahora, ahora.addingTimeInterval(-60)].map {
            NotaDiario(id: UUID(), familiarID: familiarID, categoria: .otro, texto: "x", fecha: $0, creadoEn: $0, editadoEn: nil, autor: autor)
        }
        let viewModel = DiarioViewModel(familiarID: familiarID, repositorio: DiarioFalso(notas: notas))
        await viewModel.cargar()
        #expect(viewModel.porDia.count == 2)
        #expect(viewModel.porDia.first?.notas.count == 2)
        #expect(viewModel.porDia.first?.notas.first?.fecha == ahora)
    }
}

private struct DiarioFalso: DiarioRepository {
    let notas: [NotaDiario]

    func listar(familiarID: UUID, categoria: CategoriaNota?, antes: Date?) async throws -> [NotaDiario] { notas }
    func crear(_ nota: SolicitudNota, familiarID: UUID) async throws -> NotaDiario { throw APIError.servidor("") }
    func actualizar(_ nota: SolicitudNota, id: UUID, familiarID: UUID) async throws -> NotaDiario { throw APIError.servidor("") }
    func eliminar(id: UUID, familiarID: UUID) async throws {}
}
