//
//  DiarioViewModel.swift
//  CruzContigo
//
//  HU-13 (RF-13): notas del día compartidas por la red de cuidado.
//

import Foundation
import Observation

@MainActor
@Observable
final class DiarioViewModel {
    enum Estado: Equatable {
        case cargando, listo, error(String)
    }

    private(set) var notas: [NotaDiario] = []
    private(set) var estado: Estado = .cargando
    private(set) var hayMas = false
    var filtro: CategoriaNota?
    var error: String?

    static let porPagina = 50

    let familiarID: UUID
    private let repositorio: DiarioRepository

    init(familiarID: UUID, repositorio: DiarioRepository = Repositorios.diario()) {
        self.familiarID = familiarID
        self.repositorio = repositorio
    }

    /// Notas agrupadas por día, del más reciente al más antiguo.
    var porDia: [(dia: Date, notas: [NotaDiario])] {
        let calendario = Calendar.current
        let grupos = Dictionary(grouping: notas) { calendario.startOfDay(for: $0.fecha) }
        return grupos.keys.sorted(by: >).map { dia in
            (dia, grupos[dia, default: []].sorted { $0.fecha > $1.fecha })
        }
    }

    func cargar() async {
        if notas.isEmpty { estado = .cargando }
        do {
            let pagina = try await repositorio.listar(familiarID: familiarID, categoria: filtro, antes: nil)
            notas = pagina
            hayMas = pagina.count >= Self.porPagina
            estado = .listo
        } catch {
            estado = .error(error.localizedDescription)
        }
    }

    func cargarMas() async {
        guard hayMas, let ultima = notas.last else { return }
        do {
            let pagina = try await repositorio.listar(familiarID: familiarID, categoria: filtro, antes: ultima.fecha)
            notas.append(contentsOf: pagina.filter { nueva in !notas.contains { $0.id == nueva.id } })
            hayMas = pagina.count >= Self.porPagina
        } catch {
            self.error = error.localizedDescription
        }
    }

    func guardar(_ solicitud: SolicitudNota, id: UUID?) async throws {
        let nota: NotaDiario
        if let id {
            nota = try await repositorio.actualizar(solicitud, id: id, familiarID: familiarID)
            notas.removeAll { $0.id == id }
        } else {
            nota = try await repositorio.crear(solicitud, familiarID: familiarID)
        }
        if filtro == nil || filtro == nota.categoria {
            notas.append(nota)
            notas.sort { $0.fecha > $1.fecha }
        }
    }

    func eliminar(_ nota: NotaDiario) async {
        do {
            try await repositorio.eliminar(id: nota.id, familiarID: familiarID)
            notas.removeAll { $0.id == nota.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
