//
//  CapturaRecetaView.swift
//  CruzContigo
//

import SwiftUI
import UIKit
import VisionKit

/// De dónde viene la imagen de la receta cuando no se elige de Fotos.
enum FuenteCapturaReceta: Identifiable {
    case escaner
    case camara

    var id: Self { self }

    var disponible: Bool {
        switch self {
        case .escaner: VNDocumentCameraViewController.isSupported
        case .camara: UIImagePickerController.isSourceTypeAvailable(.camera)
        }
    }
}

/// Envuelve el escáner de documentos de VisionKit y la cámara para usarlos desde SwiftUI.
/// Llama a `alTerminar` con la imagen capturada, o con `nil` si se canceló.
struct CapturaRecetaView: UIViewControllerRepresentable {
    let fuente: FuenteCapturaReceta
    let alTerminar: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(alTerminar: alTerminar)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        switch fuente {
        case .escaner:
            let escaner = VNDocumentCameraViewController()
            escaner.delegate = context.coordinator
            return escaner
        case .camara:
            let camara = UIImagePickerController()
            camara.sourceType = .camera
            camara.delegate = context.coordinator
            return camara
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate,
                             UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let alTerminar: (UIImage?) -> Void

        init(alTerminar: @escaping (UIImage?) -> Void) {
            self.alTerminar = alTerminar
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            // Las recetas suelen ser de una página; se usa la primera.
            alTerminar(scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            alTerminar(nil)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            alTerminar(nil)
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            alTerminar(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            alTerminar(nil)
        }
    }
}
