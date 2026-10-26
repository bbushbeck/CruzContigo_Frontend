//
//  APIClient.swift
//  CruzContigo
//

import Foundation

enum AppConfig {
    static var apiBaseURL: URL? {
        if let valor = ProcessInfo.processInfo.environment["CRUZ_API_URL"] {
            return valor.isEmpty ? nil : URL(string: valor)
        }
        #if DEBUG
        return URL(string: "http://localhost:3000")
        #else
        return nil
        #endif
    }

    static let fichaMedicaEnAPI = false
}

enum APIError: LocalizedError {
    case respuestaInvalida
    case http(Int)
    case servidor(String)
    case decodificacion(Error)
    case red(Error)

    var errorDescription: String? {
        switch self {
        case .respuestaInvalida: "El servidor devolvió una respuesta inválida."
        case .http(let codigo): "El servidor respondió con error \(codigo)."
        case .servidor(let mensaje): mensaje
        case .decodificacion: "No se pudieron leer los datos recibidos."
        case .red: "No hay conexión con el servidor."
        }
    }
}

struct APIClient {
    let baseURL: URL
    var session: URLSession = .shared
    var token: String? = nil

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await enviar(path, metodo: "GET", cuerpo: Optional<Int>.none)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, cuerpo: B) async throws -> T {
        try await enviar(path, metodo: "POST", cuerpo: cuerpo)
    }

    func put<B: Encodable, T: Decodable>(_ path: String, cuerpo: B) async throws -> T {
        try await enviar(path, metodo: "PUT", cuerpo: cuerpo)
    }

    func delete(_ path: String) async throws {
        _ = try await ejecutar(path, metodo: "DELETE", cuerpo: Optional<Int>.none)
    }

    private func enviar<B: Encodable, T: Decodable>(_ path: String, metodo: String, cuerpo: B?) async throws -> T {
        let datos = try await ejecutar(path, metodo: metodo, cuerpo: cuerpo)
        do {
            return try Self.decoder.decode(T.self, from: datos)
        } catch {
            throw APIError.decodificacion(error)
        }
    }

    private func ejecutar<B: Encodable>(_ path: String, metodo: String, cuerpo: B?) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = metodo
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let cuerpo {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder.encode(cuerpo)
        }

        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await session.data(for: request)
        } catch {
            throw APIError.red(error)
        }
        guard let http = respuesta as? HTTPURLResponse else { throw APIError.respuestaInvalida }
        guard (200..<300).contains(http.statusCode) else {
            if let cuerpo = try? Self.decoder.decode(RespuestaError.self, from: datos) {
                throw APIError.servidor(cuerpo.mensaje)
            }
            throw APIError.http(http.statusCode)
        }
        return datos
    }

    private struct RespuestaError: Decodable {
        let error: String
        let detalles: [String: [String]]?

        var mensaje: String {
            let primero = detalles?.values.compactMap(\.first).first
            return primero ?? error
        }
    }
}

struct LocalJSONStore<T: Codable> {
    let archivo: String

    private var url: URL {
        URL.documentsDirectory.appending(path: archivo)
    }

    func cargar() throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path()) else { return nil }
        let datos = try Data(contentsOf: url)
        return try APIClient.decoder.decode(T.self, from: datos)
    }

    func guardar(_ valor: T) throws {
        let datos = try APIClient.encoder.encode(valor)
        try datos.write(to: url, options: [.atomic, .completeFileProtection])
    }
}
