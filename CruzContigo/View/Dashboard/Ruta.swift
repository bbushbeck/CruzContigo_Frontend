//
//  Ruta.swift
//  CruzContigo
//

import SwiftUI

enum Ruta: Hashable {
    case agregarFamiliar
    case familiar(UUID)
    case elegirFamiliar(Modulo)
    case modulo(Modulo, familiarID: UUID?)
}

extension View {
    func conDestinos() -> some View {
        navigationDestination(for: Ruta.self) { ruta in
            Group {
                switch ruta {
                case .agregarFamiliar:
                    AltaPersonaView()
                case .familiar(let id):
                    FamiliarDetailView(familiarID: id)
                case .elegirFamiliar(let modulo):
                    ElegirFamiliarView(modulo: modulo)
                case .modulo(let modulo, let familiarID):
                    ModuloDestino(modulo: modulo, familiarID: familiarID)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
        }
    }
}

struct ModuloDestino: View {
    let modulo: Modulo
    let familiarID: UUID?

    @Environment(FamiliaresStore.self) private var store

    var body: some View {
        switch modulo {
        case .fichaMedica:
            if let familiarID {
                FichaMedicaView(familiarID: familiarID)
            } else {
                ModuloPendienteView(
                    modulo: modulo,
                    familiarID: nil
                )
            }

        case .medicamentos:
            let recipients = store.familiares.map(CareRecipient.init(familiar:))
            MedicationsView(
                recipients: recipients,
                selectedRecipient: recipients.first { $0.id == familiarID },
                service: DemoMedicationService.compartido
            )

        case .citas, .recordatorios:
            RecordatoriosView(familiarID: familiarID)

        case .accesibilidad:
            AccesibilidadView()
        default:
            ModuloPendienteView(
                modulo: modulo,
                familiarID: familiarID
            )
        }
    }
}
