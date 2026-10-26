//
//  Familiar.swift
//  CruzContigo
//

import Foundation

enum Parentesco: String, Codable, CaseIterable, Identifiable {
    case madre, padre, abuela, abuelo, hijo, hija, pareja, hermano, hermana, otro

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .madre: "Madre"
        case .padre: "Padre"
        case .abuela: "Abuela"
        case .abuelo: "Abuelo"
        case .hijo: "Hijo"
        case .hija: "Hija"
        case .pareja: "Pareja"
        case .hermano: "Hermano"
        case .hermana: "Hermana"
        case .otro: "Otro"
        }
    }
}

enum TipoCuidado: String, Codable, CaseIterable, Identifiable {
    case adultoMayor, discapacidad, enfermedadCronica, recuperacion, menorNecesidades, otro

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .adultoMayor: "Adulto mayor"
        case .discapacidad: "Discapacidad"
        case .enfermedadCronica: "Enfermedad crónica"
        case .recuperacion: "En recuperación"
        case .menorNecesidades: "Menor con necesidades especiales"
        case .otro: "Otro"
        }
    }

    var icono: String {
        switch self {
        case .adultoMayor: "figure.walk"
        case .discapacidad: "figure.roll"
        case .enfermedadCronica: "heart.text.square"
        case .recuperacion: "bandage"
        case .menorNecesidades: "figure.and.child.holdinghands"
        case .otro: "person"
        }
    }

    var descripcion: String {
        switch self {
        case .adultoMayor: "Necesita apoyo por su edad."
        case .discapacidad: "Motriz, visual, auditiva, intelectual u otra."
        case .enfermedadCronica: "Diabetes, hipertensión u otra condición de largo plazo."
        case .recuperacion: "Se recupera de una cirugía, accidente o enfermedad."
        case .menorNecesidades: "Niña, niño o adolescente que requiere cuidados especiales."
        case .otro: "Otra situación que no aparece aquí."
        }
    }
}

struct Familiar: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var nombre: String
    var apellidos: String
    var fechaNacimiento: Date
    var parentesco: Parentesco
    var tipoCuidado: TipoCuidado
    var telefono: String?
    var notas: String?
    var fechaRegistro: Date = Date()

    var nombreCompleto: String { "\(nombre) \(apellidos)" }

    var iniciales: String {
        let n = nombre.first.map(String.init) ?? ""
        let a = apellidos.first.map(String.init) ?? ""
        return (n + a).uppercased()
    }

    var indiceColor: Int { Int(id.uuid.0) }

    var edad: Int {
        Calendar.current.dateComponents([.year], from: fechaNacimiento, to: Date()).year ?? 0
    }
}

struct FamiliarDraft {
    var nombre = ""
    var apellidos = ""
    var dia = ""
    var mes: Int? = nil
    var anio = ""
    var parentesco: Parentesco? = nil
    var tipoCuidado: TipoCuidado? = nil
    var telefono = ""
    var notas = ""

    enum Campo: Hashable {
        case nombre, apellidos, dia, mes, anio, parentesco, tipoCuidado, telefono, notas
    }

    enum Paso: Int, CaseIterable, Comparable {
        case nombre, relacion, nacimiento, cuidado, contacto, revision

        static let preguntas: [Paso] = [.nombre, .relacion, .nacimiento, .cuidado, .contacto]

        var campos: [Campo] {
            switch self {
            case .nombre: [.nombre, .apellidos]
            case .relacion: [.parentesco]
            case .nacimiento: [.dia, .mes, .anio]
            case .cuidado: [.tipoCuidado]
            case .contacto: [.telefono, .notas]
            case .revision: []
            }
        }

        static func < (a: Paso, b: Paso) -> Bool { a.rawValue < b.rawValue }
    }

    static let meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    var nombreCorto: String {
        let limpio = nombre.trimmingCharacters(in: .whitespaces)
        return limpio.split(separator: " ").first.map(String.init) ?? ""
    }

    var telefonoDigitos: String {
        let digitos = telefono.filter(\.isNumber)
        if digitos.count == 12, digitos.hasPrefix("52") { return String(digitos.dropFirst(2)) }
        return digitos
    }

    var fechaNacimiento: Date? {
        guard let d = Int(dia), let mes, let a = Int(anio) else { return nil }
        let componentes = DateComponents(year: a, month: mes, day: d, hour: 12)
        guard componentes.isValidDate(in: Calendar.current) else { return nil }
        return Calendar.current.date(from: componentes)
    }

    var edad: Int? {
        guard let fechaNacimiento, fechaNacimiento <= Date() else { return nil }
        return Calendar.current.dateComponents([.year], from: fechaNacimiento, to: Date()).year
    }

    var tieneDatos: Bool {
        !nombre.isEmpty || !apellidos.isEmpty || !dia.isEmpty || mes != nil || !anio.isEmpty
            || parentesco != nil || tipoCuidado != nil || !telefono.isEmpty || !notas.isEmpty
    }

    var errores: [Campo: String] {
        var e: [Campo: String] = [:]
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespaces)
        let apellidosLimpios = apellidos.trimmingCharacters(in: .whitespaces)

        if nombreLimpio.isEmpty { e[.nombre] = "Escribe su nombre." }
        else if nombreLimpio.count < 2 { e[.nombre] = "El nombre debe tener al menos 2 letras." }
        if apellidosLimpios.isEmpty { e[.apellidos] = "Escribe al menos un apellido." }

        let anioActual = Calendar.current.component(.year, from: Date())
        if dia.isEmpty { e[.dia] = "Falta el día." }
        else if let d = Int(dia), !(1...31).contains(d) { e[.dia] = "El día debe estar entre 1 y 31." }
        if mes == nil { e[.mes] = "Elige el mes." }
        if anio.isEmpty { e[.anio] = "Falta el año." }
        else if anio.count != 4 { e[.anio] = "Escribe el año con 4 cifras, por ejemplo 1955." }
        else if let a = Int(anio), a < anioActual - 120 { e[.anio] = "Revisa el año: parece demasiado antiguo." }
        if e[.dia] == nil, e[.mes] == nil, e[.anio] == nil {
            if fechaNacimiento == nil { e[.dia] = "Esa fecha no existe. Revisa el día y el mes." }
            else if let f = fechaNacimiento, f > Date() { e[.anio] = "La fecha no puede ser futura." }
        }

        if parentesco == nil { e[.parentesco] = "Elige una opción para continuar." }
        if tipoCuidado == nil { e[.tipoCuidado] = "Elige una opción para continuar." }

        if !telefono.isEmpty && telefonoDigitos.count != 10 {
            e[.telefono] = "El teléfono debe tener 10 dígitos, por ejemplo 81 1234 5678."
        }
        return e
    }

    func errores(en paso: Paso) -> [Campo: String] {
        errores.filter { paso.campos.contains($0.key) }
    }

    var esValido: Bool { errores.isEmpty }

    func construir() -> Familiar? {
        guard esValido, let parentesco, let tipoCuidado, let fechaNacimiento else { return nil }
        let notasLimpias = notas.trimmingCharacters(in: .whitespacesAndNewlines)
        return Familiar(
            nombre: nombre.trimmingCharacters(in: .whitespaces),
            apellidos: apellidos.trimmingCharacters(in: .whitespaces),
            fechaNacimiento: fechaNacimiento,
            parentesco: parentesco,
            tipoCuidado: tipoCuidado,
            telefono: telefono.isEmpty ? nil : telefonoDigitos,
            notas: notasLimpias.isEmpty ? nil : notasLimpias
        )
    }
}
