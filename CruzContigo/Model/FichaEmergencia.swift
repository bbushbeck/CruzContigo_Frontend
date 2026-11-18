//
//  FichaEmergencia.swift
//  CruzContigo
//
//  HU-19 (RF-28): resumen que se guarda en el teléfono para abrirlo sin conexión.
//

import Foundation

struct MedicamentoEmergencia: Codable, Hashable, Identifiable {
    let nombre: String
    let dosis: String
    let frecuencia: String?

    var id: String { "\(nombre)|\(dosis)" }

    var detalle: String {
        [dosis, frecuencia].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct ContactoEmergencia: Codable, Hashable, Identifiable {
    let nombre: String
    let detalle: String
    let telefono: String

    var id: String { "\(nombre)|\(telefono)" }

    static let detallePropio = "Su teléfono"
    var esPropio: Bool { detalle == Self.detallePropio }
}

struct FichaEmergencia: Codable, Hashable, Identifiable {
    let familiarID: UUID
    let nombre: String
    let edad: Int?
    let tipoSanguineo: TipoSanguineo?
    let alergias: [Alergia]
    let enfermedades: [Enfermedad]
    let observaciones: String?
    let medicamentos: [MedicamentoEmergencia]
    /// Primero los contactos de emergencia en su orden (RF-15) y al final su propio teléfono.
    var contactos: [ContactoEmergencia]
    /// Copia del consentimiento de la persona titular al momento de sincronizar.
    let qrConsentido: Bool
    let actualizada: Date

    var id: UUID { familiarID }

    static func generar(
        familiar: Familiar,
        ficha: FichaMedica?,
        medicamentos: [Medication],
        qrConsentido: Bool,
        contactos registrados: [ContactoRegistrado] = [],
        fecha: Date = Date()
    ) -> FichaEmergencia {
        let propio = familiar.telefono.flatMap { $0.isEmpty ? nil : ContactoEmergencia(nombre: familiar.nombre, detalle: ContactoEmergencia.detallePropio, telefono: $0) }
        let contactos = Self.contactos(de: registrados, propio: propio)
        return FichaEmergencia(
            familiarID: familiar.id,
            nombre: familiar.nombreCompleto,
            edad: familiar.edad,
            tipoSanguineo: ficha?.tipoSanguineo,
            alergias: ficha?.alergias ?? [],
            enfermedades: ficha?.enfermedades ?? [],
            observaciones: ficha?.observaciones,
            medicamentos: medicamentos
                .filter { $0.status == .active }
                .map { MedicamentoEmergencia(nombre: $0.name, dosis: $0.doseLabel, frecuencia: $0.frequency) },
            contactos: contactos,
            qrConsentido: qrConsentido,
            actualizada: fecha
        )
    }

    static func contactos(de registrados: [ContactoRegistrado], propio: ContactoEmergencia?) -> [ContactoEmergencia] {
        let ordenados = registrados.sorted { $0.prioridad < $1.prioridad }.map {
            ContactoEmergencia(nombre: $0.nombre, detalle: $0.parentesco ?? "Contacto \($0.prioridad)", telefono: $0.telefono)
        }
        return ordenados + (propio.map { [$0] } ?? [])
    }

    /// Texto plano para el QR: se lee con la cámara de cualquier teléfono, sin la app
    /// ni internet. Se limita para que el código siga siendo legible.
    var textoQR: String {
        let textoEdad = edad.map { " (\($0) años)" } ?? ""
        var lineas = ["CRUZCONTIGO · FICHA DE EMERGENCIA", "Nombre: " + nombre + textoEdad]
        lineas.append("Sangre: \(tipoSanguineo?.titulo ?? "No lo sé")")
        let listaAlergias = alergias.map { $0.severidad == .grave ? "\($0.nombre) (PELIGROSA)" : $0.nombre }
        lineas.append("Alergias: \(listaAlergias.isEmpty ? "Ninguna conocida" : listaAlergias.joined(separator: ", "))")
        if !enfermedades.isEmpty {
            lineas.append("Enfermedades: \(enfermedades.map(\.nombre).joined(separator: ", "))")
        }
        if !medicamentos.isEmpty {
            let listaMedicamentos = medicamentos.map { $0.nombre + " " + $0.detalle }
            lineas.append("Medicamentos: " + listaMedicamentos.joined(separator: "; "))
        }
        if let observaciones {
            lineas.append("Notas: \(observaciones)")
        }
        for contacto in contactos {
            lineas.append("Contacto: \(contacto.nombre) \(contacto.telefono)")
        }
        lineas.append("Actualizada: \(actualizada.formatted(date: .numeric, time: .omitted))")
        return String(lineas.joined(separator: "\n").prefix(1200))
    }
}

/// Copias locales de las fichas de emergencia. `LocalJSONStore` escribe con
/// `.completeFileProtection`: el archivo queda cifrado mientras el teléfono está bloqueado.
enum FichasEmergenciaGuardadas {
    private static let store = LocalJSONStore<[UUID: FichaEmergencia]>(archivo: "fichas-emergencia.json")

    private static var todasPorID: [UUID: FichaEmergencia] {
        (try? store.cargar()) ?? [:]
    }

    static func todas() -> [FichaEmergencia] {
        todasPorID.values.sorted { $0.nombre.localizedCompare($1.nombre) == .orderedAscending }
    }

    static func obtener(_ familiarID: UUID) -> FichaEmergencia? {
        todasPorID[familiarID]
    }

    static func guardar(_ ficha: FichaEmergencia) {
        var todas = todasPorID
        todas[ficha.familiarID] = ficha
        try? store.guardar(todas)
    }

    static func eliminar(_ familiarID: UUID) {
        var todas = todasPorID
        guard todas.removeValue(forKey: familiarID) != nil else { return }
        try? store.guardar(todas)
    }

    /// Quita las de personas a las que ya no se tiene acceso.
    static func conservarSolo(_ ids: Set<UUID>) {
        let todas = todasPorID
        let filtradas = todas.filter { ids.contains($0.key) }
        guard filtradas.count != todas.count else { return }
        try? store.guardar(filtradas)
    }

    /// Al cerrar sesión no deben quedar datos médicos en el teléfono.
    static func eliminarTodas() {
        try? store.guardar([:])
    }
}
