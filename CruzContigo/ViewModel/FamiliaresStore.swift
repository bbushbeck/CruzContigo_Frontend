//
//  FamiliaresStore.swift
//  CruzContigo
//

import Foundation
import Observation

@Observable
final class FamiliaresStore {
    enum Estado: Equatable {
        case inicial, cargando, listo, error(String)
    }

    private(set) var familiares: [Familiar] = []
    private(set) var estado: Estado = .inicial

    private let repositorio: FamiliarRepository

    init(repositorio: FamiliarRepository = Repositorios.familiares()) {
        self.repositorio = repositorio
    }

    func cargar() async {
        estado = .cargando
        do {
            familiares = try await repositorio.listar().sorted { $0.fechaRegistro < $1.fechaRegistro }
            estado = .listo
        } catch {
            estado = .error(error.localizedDescription)
        }
    }

    func agregar(_ familiar: Familiar) async -> String? {
        do {
            let creado = try await repositorio.crear(familiar)
            familiares.append(creado)
            estado = .listo
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func eliminar(_ familiar: Familiar) async {
        do {
            try await repositorio.eliminar(id: familiar.id)
            if !AppConfig.fichaMedicaEnAPI || AppConfig.apiBaseURL == nil {
                try LocalFichaMedicaRepository().eliminar(familiarID: familiar.id)
            }
            familiares.removeAll { $0.id == familiar.id }
        } catch {
            estado = .error(error.localizedDescription)
        }
    }
}
