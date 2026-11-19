import Foundation

struct InterpretacionFrida {
    enum Intencion: String {
        case medicamentos, recordatorios, contactosEmergencia
        case relato, prepararDiario, consejoMedico, otro
    }

    let intencion: Intencion
    let periodo: ConsultaFrida.Periodo?
    let pendientes: Bool
    let accion: Accion?
    let familiar: String?
    let orientacion: SugerenciaNotaFrida

    enum Accion: String {
        case consultar, abrir
    }

    init?(
        intencion: String, periodo: String, pendientes: Bool, accion: String, familiar: String?,
        orientacion: SugerenciaNotaFrida
    ) {
        guard let intencion = Intencion(rawValue: intencion) else { return nil }
        self.intencion = intencion
        self.periodo = ConsultaFrida.Periodo(rawValue: ConsultaFrida.palabras(periodo).joined(separator: " "))
        self.pendientes = pendientes
        self.accion = Accion(rawValue: accion)
        self.familiar = familiar?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.orientacion = orientacion
    }

    func consulta(para texto: String, contandoRelato: Bool) -> ConsultaFrida? {
        guard let tema = ConsultaFrida.Tema(rawValue: intencion.rawValue),
              let periodo, let accion,
              !BorradorDiarioFrida.esRelatoCotidiano(texto),
              !contandoRelato || BorradorDiarioFrida.esConsultaExplicita(texto) else { return nil }

        guard BorradorDiarioFrida.esConsultaExplicita(texto) || ConsultaFrida(texto)?.tema == tema else {
            return nil
        }
        if tema == .contactosEmergencia, !ConsultaFrida.autorizaContactos(texto) { return nil }

        // La referencia del modelo jamás elige un UUID. Si mencionó a alguien,
        // el chat busca coincidencias en el mensaje o pide elegir a la persona.
        return ConsultaFrida(
            tema: tema, periodo: periodo, pendientes: tema == .recordatorios && pendientes,
            abrirPantalla: accion == .abrir, mencionaPersona: familiar?.isEmpty == false
        )
    }

    static func resolverConsulta(
        _ modelo: InterpretacionFrida?, texto: String, contandoRelato: Bool
    ) -> ConsultaFrida? {
        guard !BorradorDiarioFrida.esRelatoCotidiano(texto),
              !contandoRelato || BorradorDiarioFrida.esConsultaExplicita(texto),
              modelo?.intencion != .consejoMedico, modelo?.intencion != .prepararDiario else { return nil }

        if let consulta = modelo?.consulta(para: texto, contandoRelato: contandoRelato) {
            return consulta
        }
        guard modelo?.intencion != .relato else { return nil }
        return ConsultaFrida(texto)
    }

    func autorizaRevision(_ texto: String) -> Bool {
        guard intencion == .prepararDiario, !BorradorDiarioFrida.esRelatoCotidiano(texto) else { return false }
        let palabras = ConsultaFrida.palabras(texto)
        guard !palabras.contains("no") else { return false }
        let unPedido: Set<String> = ["resume", "resumir", "hazme", "prepara", "puedes", "quiero"]
        let unResumen: Set<String> = ["resume", "resumir", "resumen", "nota", "diario"]
        let terminos = Set(palabras)
        return !terminos.isDisjoint(with: unPedido) && !terminos.isDisjoint(with: unResumen)
    }
}
