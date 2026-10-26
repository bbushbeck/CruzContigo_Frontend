//
//  FichaMedicaRepository.swift
//  CruzContigo
//

import Foundation

protocol FichaMedicaRepository {
    func obtener(familiarID: UUID) async throws -> FichaMedica?
    func guardar(_ ficha: FichaMedica) async throws -> FichaMedica
}

struct RemoteFichaMedicaRepository: FichaMedicaRepository {
    let api: APIClient

    func obtener(familiarID: UUID) async throws -> FichaMedica? {
        do {
            return try await api.get(ruta(familiarID))
        } catch APIError.http(404) {
            return nil
        }
    }

    func guardar(_ ficha: FichaMedica) async throws -> FichaMedica {
        try await api.put(ruta(ficha.familiarID), cuerpo: ficha)
    }

    private func ruta(_ id: UUID) -> String { "familiares/\(id.uuidString)/ficha-medica" }
}

struct LocalFichaMedicaRepository: FichaMedicaRepository {
    private let store = LocalJSONStore<[UUID: FichaMedica]>(archivo: "fichas-medicas.json")

    func obtener(familiarID: UUID) async throws -> FichaMedica? {
        try store.cargar()?[familiarID]
    }

    func guardar(_ ficha: FichaMedica) async throws -> FichaMedica {
        var todas = try store.cargar() ?? [:]
        todas[ficha.familiarID] = ficha
        try store.guardar(todas)
        return ficha
    }

    func eliminar(familiarID: UUID) throws {
        var todas = try store.cargar() ?? [:]
        todas[familiarID] = nil
        try store.guardar(todas)
    }
}

extension Repositorios {
    static func fichasMedicas() -> FichaMedicaRepository {
        if AppConfig.fichaMedicaEnAPI, let url = AppConfig.apiBaseURL {
            return RemoteFichaMedicaRepository(api: APIClient(baseURL: url))
        }
        return LocalFichaMedicaRepository()
    }
}
