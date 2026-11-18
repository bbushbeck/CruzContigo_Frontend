//
//  SincronizadorFichaEmergencia.swift
//  CruzContigo
//
//  Mantiene al día la copia local de la ficha de emergencia (HU-19) para que
//  abra en modo avión.
//

import Foundation

struct SincronizadorFichaEmergencia {
    var fichas: FichaMedicaRepository = Repositorios.fichasMedicas()
    var medicamentos: any MedicationService = MedicationServices.live()
    var accesos: AccesosRepository = Repositorios.accesos()
    var contactos: ContactosRepository = Repositorios.contactos()

    /// Descarga la ficha, los medicamentos activos y el consentimiento del QR, y
    /// guarda el resumen. Si la cuenta perdió el acceso, borra la copia local.
    @discardableResult
    func sincronizar(_ familiar: Familiar) async throws -> FichaEmergencia {
        // El acceso profesional es acotado y registrado: no se guarda copia.
        guard !familiar.esProfesional else {
            FichasEmergenciaGuardadas.eliminar(familiar.id)
            throw APIError.sinAcceso("El acceso profesional no guarda copias sin conexión.")
        }

        let anterior = FichasEmergenciaGuardadas.obtener(familiar.id)
        let ficha: FichaMedica?
        do {
            ficha = try await fichas.obtener(familiarID: familiar.id)
        } catch APIError.sinAcceso(let mensaje) {
            FichasEmergenciaGuardadas.eliminar(familiar.id)
            throw APIError.sinAcceso(mensaje)
        }

        let listaMedicamentos = try? await medicamentos.fetchMedications(for: familiar.id)
        let qr = try? await accesos.estadoQR(familiarID: familiar.id)
        let registrados = try? await contactos.listar(familiarID: familiar.id)

        var resumen = FichaEmergencia.generar(
            familiar: familiar,
            ficha: ficha,
            medicamentos: listaMedicamentos ?? [],
            qrConsentido: qr?.consentido ?? anterior?.qrConsentido ?? false,
            contactos: registrados ?? []
        )
        // Si los contactos no cargaron, se conservan los de la copia anterior (RF-15).
        if registrados == nil, let anterior {
            let propio = resumen.contactos.first(where: \.esPropio)
            resumen.contactos = anterior.contactos.filter { !$0.esPropio } + (propio.map { [$0] } ?? [])
        }
        // Si los medicamentos no cargaron, se conservan los de la copia anterior.
        if listaMedicamentos == nil, let anterior {
            resumen = FichaEmergencia(
                familiarID: resumen.familiarID, nombre: resumen.nombre, edad: resumen.edad,
                tipoSanguineo: resumen.tipoSanguineo, alergias: resumen.alergias,
                enfermedades: resumen.enfermedades, observaciones: resumen.observaciones,
                medicamentos: anterior.medicamentos, contactos: resumen.contactos,
                qrConsentido: resumen.qrConsentido, actualizada: resumen.actualizada
            )
        }
        FichasEmergenciaGuardadas.guardar(resumen)
        return resumen
    }

    /// Se llama cuando la lista de familiares cargó bien: actualiza cada copia y
    /// elimina las de personas que ya no están en la lista.
    func sincronizarTodas(_ familiares: [Familiar]) async {
        let permitidos = familiares.filter { !$0.esProfesional }
        FichasEmergenciaGuardadas.conservarSolo(Set(permitidos.map(\.id)))
        for familiar in permitidos {
            _ = try? await sincronizar(familiar)
        }
    }
}
