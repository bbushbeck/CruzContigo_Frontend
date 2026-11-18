//
//  FichaMedicaViewModel.swift
//  CruzContigo
//

import Foundation
import Observation

@Observable
final class FichaMedicaViewModel {
    enum Estado: Equatable {
        case cargando, sinFicha, lista, error(String)
        /// El servidor respondió 403: el acceso fue retirado o venció.
        case sinAcceso(String)
    }

    let familiarID: UUID
    private(set) var ficha: FichaMedica?
    private(set) var estado: Estado = .cargando

    private let repositorio: FichaMedicaRepository

    init(familiarID: UUID, repositorio: FichaMedicaRepository = Repositorios.fichasMedicas()) {
        self.familiarID = familiarID
        self.repositorio = repositorio
    }

    func cargar() async {
        estado = .cargando
        do {
            ficha = try await repositorio.obtener(familiarID: familiarID)
            estado = ficha == nil ? .sinFicha : .lista
        } catch APIError.sinAcceso(let mensaje) {
            perderAcceso(mensaje)
        } catch {
            estado = .error(error.localizedDescription)
        }
    }

    var borrador: FichaMedica {
        ficha ?? FichaMedica(familiarID: familiarID)
    }

    func guardar(_ nueva: FichaMedica) async -> String? {
        guard nueva.esValida else { return nueva.errores.joined(separator: "\n") }
        var ficha = nueva
        ficha.ultimaActualizacion = Date()
        do {
            self.ficha = try await repositorio.guardar(ficha)
            estado = .lista
            return nil
        } catch APIError.sinAcceso(let mensaje) {
            perderAcceso(mensaje)
            return mensaje
        } catch {
            return error.localizedDescription
        }
    }

    /// Sin permiso no se conservan en memoria los datos que ya se habían descargado.
    private func perderAcceso(_ mensaje: String) {
        ficha = nil
        estado = .sinAcceso(mensaje)
    }
}
