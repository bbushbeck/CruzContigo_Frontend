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

    static let fichaMedicaEnAPI = true
}

enum APIError: LocalizedError {
    case respuestaInvalida
    case http(Int)
    case servidor(String)
    /// 403: la cuenta no tiene (o ya no tiene) permiso sobre el recurso.
    case sinAcceso(String)
    case decodificacion(Error)
    case red(Error)

    var errorDescription: String? {
        switch self {
        case .respuestaInvalida: "El servidor devolvió una respuesta inválida."
        case .http(let codigo): "El servidor respondió con error \(codigo)."
        case .servidor(let mensaje): mensaje
        case .sinAcceso(let mensaje): mensaje
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

    /// GET con parámetros de consulta (`?clave=valor`), que no se pueden poner en `path`.
    func get<T: Decodable>(_ path: String, consulta: [URLQueryItem]) async throws -> T {
        try await enviar(path, metodo: "GET", cuerpo: Optional<Int>.none, consulta: consulta)
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

    private func enviar<B: Encodable, T: Decodable>(_ path: String, metodo: String, cuerpo: B?, consulta: [URLQueryItem] = []) async throws -> T {
        let datos = try await ejecutar(path, metodo: metodo, cuerpo: cuerpo, consulta: consulta)
        do {
            return try Self.decoder.decode(T.self, from: datos)
        } catch {
            throw APIError.decodificacion(error)
        }
    }

    private func ejecutar<B: Encodable>(_ path: String, metodo: String, cuerpo: B?, consulta: [URLQueryItem] = []) async throws -> Data {
        var url = baseURL.appending(path: path)
        if !consulta.isEmpty { url.append(queryItems: consulta) }
        var request = URLRequest(url: url)
        request.httpMethod = metodo
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = token ?? AuthTokenStore.shared.cargar() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
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
            let cuerpo = try? Self.decoder.decode(RespuestaError.self, from: datos)
            if http.statusCode == 403 {
                throw APIError.sinAcceso(cuerpo?.mensaje ?? "Ya no tienes acceso a esta información.")
            }
            if let cuerpo {
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
