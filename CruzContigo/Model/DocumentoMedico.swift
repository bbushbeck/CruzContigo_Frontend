import Foundation

enum TipoDocumento: String, Codable, CaseIterable, Identifiable {
    case receta, estudio
    var id: String { rawValue }
    var titulo: String { self == .receta ? "Receta" : "Estudio" }
}

struct DocumentoMedico: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var familiarID: UUID
    var titulo: String
    var archivo: String
    var tipo: TipoDocumento
    var fecha: Date = Date()

    var url: URL {
        DocumentosMedicosRepository.directorio.appending(path: archivo)
    }
}

enum DocumentoMedicoError: LocalizedError {
    case formato, tamano

    var errorDescription: String? {
        switch self {
        case .formato: "Solo se admiten fotos JPG, PNG o HEIC y archivos PDF."
        case .tamano: "El archivo no puede superar 15 MB."
        }
    }
}

enum DocumentosMedicosRepository {
    private static let store = LocalJSONStore<[DocumentoMedico]>(archivo: "documentos-medicos.json")
    static let directorio = URL.documentsDirectory.appending(path: "documentos-medicos", directoryHint: .isDirectory)

    static func listar(familiarID: UUID) throws -> [DocumentoMedico] {
        try (store.cargar() ?? [])
            .filter { $0.familiarID == familiarID }
            .sorted { $0.fecha > $1.fecha }
    }

    static func guardar(_ datos: Data, titulo: String, extensionArchivo: String, tipo: TipoDocumento, familiarID: UUID) throws {
        let ext = extensionArchivo.lowercased()
        guard ["jpg", "jpeg", "png", "heic", "pdf"].contains(ext) else { throw DocumentoMedicoError.formato }
        guard !datos.isEmpty && datos.count <= 15 * 1024 * 1024 else { throw DocumentoMedicoError.tamano }

        let documento = DocumentoMedico(
            familiarID: familiarID,
            titulo: titulo,
            archivo: "\(UUID().uuidString).\(ext)",
            tipo: tipo
        )

        try FileManager.default.createDirectory(at: directorio, withIntermediateDirectories: true)
        try datos.write(to: documento.url, options: [.atomic, .completeFileProtection])
        var todos = try store.cargar() ?? []
        todos.append(documento)
        try store.guardar(todos)
    }

    static func eliminar(_ documento: DocumentoMedico) throws {
        try? FileManager.default.removeItem(at: documento.url)
        var todos = try store.cargar() ?? []
        todos.removeAll { $0.id == documento.id }
        try store.guardar(todos)
    }
}
