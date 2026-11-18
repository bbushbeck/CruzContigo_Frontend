//
//  ContactosEmergenciaViewModel.swift
//  CruzContigo
//
//  RF-15: contactos de emergencia en orden de prioridad.
//

import Foundation
import Observation

@MainActor
@Observable
final class ContactosEmergenciaViewModel {
    enum Estado: Equatable {
        case cargando, listo, error(String)
    }

    private(set) var contactos: [ContactoRegistrado] = []
    private(set) var estado: Estado = .cargando
    var error: String?

    static let maximo = 10

    let familiarID: UUID
    private let repositorio: ContactosRepository

    init(familiarID: UUID, repositorio: ContactosRepository = Repositorios.contactos()) {
        self.familiarID = familiarID
        self.repositorio = repositorio
    }

    var puedeAgregar: Bool { contactos.count < Self.maximo }

    func cargar() async {
        if contactos.isEmpty { estado = .cargando }
        do {
            contactos = try await repositorio.listar(familiarID: familiarID)
            estado = .listo
        } catch {
            estado = .error(error.localizedDescription)
        }
    }

    /// Crea o actualiza; lanza el error para que el formulario lo muestre.
    func guardar(_ solicitud: SolicitudContacto, id: UUID?) async throws {
        if let id {
            let actualizado = try await repositorio.actualizar(solicitud, id: id, familiarID: familiarID)
            if let indice = contactos.firstIndex(where: { $0.id == id }) { contactos[indice] = actualizado }
        } else {
            contactos.append(try await repositorio.crear(solicitud, familiarID: familiarID))
        }
        await actualizarCopiaSinConexion()
    }

    func eliminar(_ contacto: ContactoRegistrado) async {
        do {
            try await repositorio.eliminar(id: contacto.id, familiarID: familiarID)
            await cargar()
            await actualizarCopiaSinConexion()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func mover(desde origen: IndexSet, hacia destino: Int) async {
        let anterior = contactos
        contactos.move(fromOffsets: origen, toOffset: destino)
        do {
            contactos = try await repositorio.ordenar(contactos.map(\.id), familiarID: familiarID)
            await actualizarCopiaSinConexion()
        } catch {
            contactos = anterior
            self.error = error.localizedDescription
        }
    }

    /// Los contactos también salen en la ficha de emergencia guardada (HU-19).
    private func actualizarCopiaSinConexion() async {
        guard var copia = FichasEmergenciaGuardadas.obtener(familiarID) else { return }
        copia.contactos = FichaEmergencia.contactos(de: contactos, propio: copia.contactos.first(where: \.esPropio))
        FichasEmergenciaGuardadas.guardar(copia)
    }
}
