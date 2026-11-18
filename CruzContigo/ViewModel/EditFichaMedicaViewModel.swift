import Foundation
import Observation

@MainActor
@Observable
final class EditFichaMedicaViewModel {
    var ficha: FichaMedica
    var medicoTratante: String
    var institucionSalud: String
    var antecedentes: String
    var observaciones: String
    var nuevaAlergia = ""
    var nuevaSeveridad: Severidad? = .leve
    var nuevaEnfermedad = ""
    var intentoGuardar = false
    var guardando = false
    var errorGuardado: String?

    private let onGuardar: (FichaMedica) async -> String?

    var fichaFinal: FichaMedica {
        var ficha = ficha
        ficha.medicoTratante = textoOpcional(medicoTratante)
        ficha.institucionSalud = textoOpcional(institucionSalud)
        ficha.antecedentes = textoOpcional(antecedentes)
        ficha.observaciones = textoOpcional(observaciones)
        return ficha
    }

    var puedeAgregarAlergia: Bool { !limpio(nuevaAlergia).isEmpty }
    var puedeAgregarEnfermedad: Bool { !limpio(nuevaEnfermedad).isEmpty }

    init(ficha: FichaMedica, onGuardar: @escaping (FichaMedica) async -> String?) {
        self.ficha = ficha
        self.onGuardar = onGuardar
        medicoTratante = ficha.medicoTratante ?? ""
        institucionSalud = ficha.institucionSalud ?? ""
        antecedentes = ficha.antecedentes ?? ""
        observaciones = ficha.observaciones ?? ""
    }

    func agregarAlergia() {
        let nombre = limpio(nuevaAlergia)
        guard !nombre.isEmpty else { return }
        ficha.alergias.append(Alergia(nombre: nombre, severidad: nuevaSeveridad ?? .leve))
        nuevaAlergia = ""
    }

    func eliminarAlergia(_ alergia: Alergia) {
        ficha.alergias.removeAll { $0.id == alergia.id }
    }

    func agregarEnfermedad() {
        let nombre = limpio(nuevaEnfermedad)
        guard !nombre.isEmpty else { return }
        ficha.enfermedades.append(Enfermedad(nombre: nombre))
        nuevaEnfermedad = ""
    }

    func eliminarEnfermedad(_ enfermedad: Enfermedad) {
        ficha.enfermedades.removeAll { $0.id == enfermedad.id }
    }

    func guardar() async -> Bool {
        intentoGuardar = true
        agregarAlergia()
        agregarEnfermedad()
        guard fichaFinal.esValida else { return false }

        guardando = true
        defer { guardando = false }
        if let error = await onGuardar(fichaFinal) {
            errorGuardado = error
            return false
        }
        return true
    }

    private func textoOpcional(_ texto: String) -> String? {
        let resultado = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        return resultado.isEmpty ? nil : resultado
    }

    private func limpio(_ texto: String) -> String {
        texto.trimmingCharacters(in: .whitespaces)
    }
}
