import Foundation
import Observation
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class DocumentosMedicosViewModel {
    private let familiarID: UUID

    private(set) var documentos: [DocumentoMedico] = []
    var tipoNuevo: TipoDocumento = .receta
    var filtro: TipoDocumento?
    var guardando = false
    var error: String?

    var filtrados: [DocumentoMedico] {
        documentos.filter { filtro == nil || $0.tipo == filtro }
    }

    init(familiarID: UUID) {
        self.familiarID = familiarID
    }

    func cargar() {
        do {
            documentos = try DocumentosMedicosRepository.listar(familiarID: familiarID)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func guardarFoto(_ item: PhotosPickerItem) async {
        guardando = true
        defer { guardando = false }
        do {
            guard let datos = try await item.loadTransferable(type: Data.self) else {
                throw DocumentoMedicoError.formato
            }
            let ext = item.supportedContentTypes.first(where: { $0.conforms(to: .image) })?.preferredFilenameExtension ?? "jpg"
            try guardar(datos, titulo: tipoNuevo.titulo, extensionArchivo: ext)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func guardarArchivo(_ resultado: Result<URL, Error>) {
        do {
            let url = try resultado.get()
            let acceso = url.startAccessingSecurityScopedResource()
            defer { if acceso { url.stopAccessingSecurityScopedResource() } }
            try guardar(
                Data(contentsOf: url),
                titulo: url.deletingPathExtension().lastPathComponent,
                extensionArchivo: url.pathExtension
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func eliminar(_ documento: DocumentoMedico) {
        do {
            try DocumentosMedicosRepository.eliminar(documento)
            cargar()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func guardar(_ datos: Data, titulo: String, extensionArchivo: String) throws {
        try DocumentosMedicosRepository.guardar(
            datos,
            titulo: titulo,
            extensionArchivo: extensionArchivo,
            tipo: tipoNuevo,
            familiarID: familiarID
        )
        cargar()
    }
}
