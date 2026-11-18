//
//  GeneradorQR.swift
//  CruzContigo
//

import CoreImage.CIFilterBuiltins
import UIKit

enum GeneradorQR {
    /// Genera el código en el teléfono, sin conexión.
    static func imagen(de texto: String, escala: CGFloat = 10) -> UIImage? {
        let filtro = CIFilter.qrCodeGenerator()
        filtro.message = Data(texto.utf8)
        filtro.correctionLevel = "M"
        guard let salida = filtro.outputImage?.transformed(by: CGAffineTransform(scaleX: escala, y: escala)),
              let imagen = CIContext().createCGImage(salida, from: salida.extent) else { return nil }
        return UIImage(cgImage: imagen)
    }
}
