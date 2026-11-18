import Foundation
import Observation

/// Formulario de la ficha en pasos cortos: una pregunta por pantalla, respuestas de
/// Sí/No y sugerencias para tocar en lugar de escribir.
@MainActor
@Observable
final class EditFichaMedicaViewModel {
    enum Paso: Int, CaseIterable {
        case sangre, alergias, enfermedades, detalles

        var numero: Int { rawValue + 1 }
    }

    static let alergiasComunes = ["Penicilina", "Aspirina", "Ibuprofeno", "Sulfas", "Látex", "Mariscos", "Huevo", "Picadura de abeja"]
    static let enfermedadesComunes = ["Diabetes", "Presión alta", "Problemas del corazón", "Colesterol alto", "Artritis", "Asma o EPOC", "Problemas de riñón", "Alzheimer o demencia"]
    static let instituciones = ["IMSS", "ISSSTE", "IMSS-Bienestar", "Médico privado"]
    static let tiposSangre: [TipoSanguineo] = [.desconocido] + TipoSanguineo.allCases.filter { $0 != .desconocido }

    var ficha: FichaMedica
    var paso: Paso = .sangre
    /// `nil` mientras la pregunta no se ha contestado.
    var tieneAlergias: Bool?
    var tieneEnfermedades: Bool?
    var otraAlergia = ""
    var otraEnfermedad = ""
    var medicoTratante: String
    var institucionSalud: String
    var antecedentes: String
    var observaciones: String
    var mostrarError = false
    var guardando = false
    var errorGuardado: String?

    /// Una ficha guardada siempre tiene tipo sanguíneo (aunque sea «No lo sé»).
    let esNueva: Bool
    private let original: FichaMedica
    private let onGuardar: (FichaMedica) async -> String?

    init(ficha: FichaMedica, onGuardar: @escaping (FichaMedica) async -> String?) {
        self.ficha = ficha
        var base = ficha
        base.tipoSanguineo = ficha.tipoSanguineo ?? .desconocido
        self.original = base
        self.onGuardar = onGuardar
        esNueva = ficha.tipoSanguineo == nil
        tieneAlergias = ficha.alergias.isEmpty ? (esNueva ? nil : false) : true
        tieneEnfermedades = ficha.enfermedades.isEmpty ? (esNueva ? nil : false) : true
        medicoTratante = ficha.medicoTratante ?? ""
        institucionSalud = ficha.institucionSalud ?? ""
        antecedentes = ficha.antecedentes ?? ""
        observaciones = ficha.observaciones ?? ""
    }

    // MARK: - Resultado

    var fichaFinal: FichaMedica {
        var final = ficha
        final.tipoSanguineo = ficha.tipoSanguineo ?? .desconocido
        if tieneAlergias != true { final.alergias = [] }
        if tieneEnfermedades != true { final.enfermedades = [] }
        final.medicoTratante = Self.textoOpcional(medicoTratante)
        final.institucionSalud = Self.textoOpcional(institucionSalud)
        final.antecedentes = Self.textoOpcional(antecedentes)
        final.observaciones = Self.textoOpcional(observaciones)
        return final
    }

    var hayCambios: Bool {
        fichaFinal != original || !Self.limpio(otraAlergia).isEmpty || !Self.limpio(otraEnfermedad).isEmpty
    }

    // MARK: - Pasos

    var esUltimoPaso: Bool { paso == .detalles }
    var progreso: Double { Double(paso.numero) / Double(Paso.allCases.count) }

    /// Error del paso actual; se muestra solo después de intentar avanzar.
    var errorPaso: String? {
        switch paso {
        case .sangre:
            return nil
        case .alergias:
            if tieneAlergias == nil { return "Elija Sí o No." }
            if tieneAlergias == true, ficha.alergias.isEmpty { return "Toque al menos una alergia o elija No." }
            return nil
        case .enfermedades:
            if tieneEnfermedades == nil { return "Elija Sí o No." }
            if tieneEnfermedades == true, ficha.enfermedades.isEmpty { return "Toque al menos una enfermedad o elija No." }
            return nil
        case .detalles:
            return errorMedico ?? errorInstitucion ?? errorAntecedentes ?? errorObservaciones
        }
    }

    var errorMedico: String? { medicoTratante.count > 120 ? "Use 120 letras como máximo." : nil }
    var errorInstitucion: String? { institucionSalud.count > 120 ? "Use 120 letras como máximo." : nil }
    var errorAntecedentes: String? { antecedentes.count > 4000 ? "Use 4000 letras como máximo." : nil }
    var errorObservaciones: String? { observaciones.count > 1000 ? "Use 1000 letras como máximo." : nil }

    /// Avanza si el paso está completo. Devuelve `false` si hay algo que corregir.
    @discardableResult
    func siguiente() -> Bool {
        agregarPendientes()
        guard errorPaso == nil else {
            mostrarError = true
            return false
        }
        mostrarError = false
        if let proximo = Paso(rawValue: paso.rawValue + 1) { paso = proximo }
        return true
    }

    func atras() {
        mostrarError = false
        if let anterior = Paso(rawValue: paso.rawValue - 1) { paso = anterior }
    }

    // MARK: - Alergias

    var opcionesAlergia: [String] { Self.opciones(Self.alergiasComunes, mas: ficha.alergias.map(\.nombre)) }

    func tieneAlergia(_ nombre: String) -> Bool {
        ficha.alergias.contains { Self.igual($0.nombre, nombre) }
    }

    func alternarAlergia(_ nombre: String) {
        if tieneAlergia(nombre) {
            ficha.alergias.removeAll { Self.igual($0.nombre, nombre) }
        } else {
            ficha.alergias.append(Alergia(nombre: nombre, severidad: .leve))
        }
    }

    func agregarOtraAlergia() {
        let nombre = Self.limpio(otraAlergia)
        guard !nombre.isEmpty else { return }
        if !tieneAlergia(nombre) { alternarAlergia(nombre) }
        otraAlergia = ""
    }

    func cambiarSeveridad(de alergia: Alergia, a severidad: Severidad) {
        guard let indice = ficha.alergias.firstIndex(where: { $0.id == alergia.id }) else { return }
        ficha.alergias[indice].severidad = severidad
    }

    // MARK: - Enfermedades

    var opcionesEnfermedad: [String] { Self.opciones(Self.enfermedadesComunes, mas: ficha.enfermedades.map(\.nombre)) }

    func tieneEnfermedad(_ nombre: String) -> Bool {
        ficha.enfermedades.contains { Self.igual($0.nombre, nombre) }
    }

    func alternarEnfermedad(_ nombre: String) {
        if tieneEnfermedad(nombre) {
            ficha.enfermedades.removeAll { Self.igual($0.nombre, nombre) }
        } else {
            ficha.enfermedades.append(Enfermedad(nombre: nombre))
        }
    }

    func agregarOtraEnfermedad() {
        let nombre = Self.limpio(otraEnfermedad)
        guard !nombre.isEmpty else { return }
        if !tieneEnfermedad(nombre) { alternarEnfermedad(nombre) }
        otraEnfermedad = ""
    }

    // MARK: - Guardar

    func guardar() async -> Bool {
        agregarPendientes()
        let final = fichaFinal
        guard final.esValida else {
            mostrarError = true
            errorGuardado = final.errores.first
            return false
        }

        guardando = true
        defer { guardando = false }
        if let error = await onGuardar(final) {
            errorGuardado = error
            return false
        }
        return true
    }

    /// Si escribió una alergia o enfermedad y no tocó «Agregar», se agrega por él.
    private func agregarPendientes() {
        if !Self.limpio(otraAlergia).isEmpty {
            tieneAlergias = true
            agregarOtraAlergia()
        }
        if !Self.limpio(otraEnfermedad).isEmpty {
            tieneEnfermedades = true
            agregarOtraEnfermedad()
        }
    }

    // MARK: - Utilidades

    private static func opciones(_ comunes: [String], mas registradas: [String]) -> [String] {
        let extra = registradas.filter { nombre in !comunes.contains { igual($0, nombre) } }
        return comunes + extra
    }

    private static func igual(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private static func textoOpcional(_ texto: String) -> String? {
        let resultado = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        return resultado.isEmpty ? nil : resultado
    }

    private static func limpio(_ texto: String) -> String {
        texto.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
