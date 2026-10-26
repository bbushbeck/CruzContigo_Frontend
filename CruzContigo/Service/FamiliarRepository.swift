//
//  FamiliarRepository.swift
//  CruzContigo
//

import Foundation

protocol FamiliarRepository {
    func listar() async throws -> [Familiar]
    func crear(_ familiar: Familiar) async throws -> Familiar
    func eliminar(id: UUID) async throws
}

struct RemoteFamiliarRepository: FamiliarRepository {
    let api: APIClient

    func listar() async throws -> [Familiar] {
        try await api.get("familiares")
    }

    func crear(_ familiar: Familiar) async throws -> Familiar {
        try await api.post("familiares", cuerpo: familiar)
    }

    func eliminar(id: UUID) async throws {
        try await api.delete("familiares/\(id.uuidString)")
    }
}

struct LocalFamiliarRepository: FamiliarRepository {
    private let store = LocalJSONStore<[Familiar]>(archivo: "familiares.json")

    func listar() async throws -> [Familiar] {
        try store.cargar() ?? []
    }

    func crear(_ familiar: Familiar) async throws -> Familiar {
        var todos = try store.cargar() ?? []
        todos.append(familiar)
        try store.guardar(todos)
        return familiar
    }

    func eliminar(id: UUID) async throws {
        var todos = try store.cargar() ?? []
        todos.removeAll { $0.id == id }
        try store.guardar(todos)
    }
}

enum Repositorios {
    static func familiares() -> FamiliarRepository {
        if let url = AppConfig.apiBaseURL {
            return RemoteFamiliarRepository(api: APIClient(baseURL: url))
        }
        return LocalFamiliarRepository()
    }
}
