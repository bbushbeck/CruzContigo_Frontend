import Foundation

struct SolicitudCodigo: Encodable {
    let phoneNumber: String
}

struct RespuestaSolicitud: Decodable {
    let challengeId: String
}

struct VerificacionCodigo: Encodable {
    let challengeId: String
    let code: String
}

struct RespuestaAuth: Decodable {
    let token: String
}
