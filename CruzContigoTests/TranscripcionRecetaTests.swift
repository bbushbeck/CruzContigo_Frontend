import Foundation
import Testing
import UIKit
@testable import CruzContigo

@MainActor
struct TranscripcionRecetaTests {
    // MARK: - RecetaTextoParser

    @Test func extraeUnMedicamentoConSuIndicacion() {
        let lineas = [
            "Hospital General Cruz Roja",
            "Paciente: Juan Pérez López",
            "Fecha: 18/11/2026",
            "Paracetamol 500 mg tabletas",
            "Tomar 1 tableta cada 8 horas por 5 días",
            "Dra. Ana Ruiz  Cédula 1234567",
        ]
        let medicamentos = RecetaTextoParser.medicamentos(en: lineas)

        #expect(medicamentos.count == 1)
        let paracetamol = medicamentos.first
        #expect(paracetamol?.nombre == "Paracetamol")
        #expect(paracetamol?.dosis == "500")
        #expect(paracetamol?.unidad == "mg")
        #expect(paracetamol?.presentacion == "tabletas")
        #expect(paracetamol?.frecuencia == "cada 8 horas")
        #expect(paracetamol?.duracionDias == 5)
        #expect(paracetamol?.indicacion == "Tomar 1 tableta cada 8 horas por 5 días")
    }

    @Test func separaVariosMedicamentosNumerados() {
        let lineas = [
            "1. Amoxicilina 250 mg/5 ml suspensión",
            "Tomar 5 ml cada 12 horas durante 7 días",
            "2) Ibuprofeno 400 mg",
            "1 tableta cada 8 horas por 2 semanas",
        ]
        let medicamentos = RecetaTextoParser.medicamentos(en: lineas)

        #expect(medicamentos.map(\.nombre) == ["Amoxicilina", "Ibuprofeno"])
        #expect(medicamentos[0].dosis == "250")
        #expect(medicamentos[0].presentacion == "suspensión")
        #expect(medicamentos[0].frecuencia == "cada 12 horas")
        #expect(medicamentos[0].duracionDias == 7)
        #expect(medicamentos[1].frecuencia == "cada 8 horas")
        #expect(medicamentos[1].duracionDias == 14)
    }

    @Test func usaElNombreDeLaLineaAnteriorSiLaDosisVaSola() {
        let medicamentos = RecetaTextoParser.medicamentos(en: ["Omeprazol", "20 mg cápsulas", "Una vez al día en ayunas"])

        #expect(medicamentos.count == 1)
        #expect(medicamentos.first?.nombre == "Omeprazol")
        #expect(medicamentos.first?.dosis == "20")
        #expect(medicamentos.first?.presentacion == "cápsulas")
    }

    @Test func noConfundeEncabezadosConMedicamentos() {
        // "Tel" y "Dra" son encabezados, pero no deben descartar "Telmisartán" ni "Dramamine".
        let medicamentos = RecetaTextoParser.medicamentos(en: [
            "Tel: 55 1234 5678",
            "Telmisartán 40 mg",
            "Dramamine 50 mg tabletas",
        ])

        #expect(medicamentos.map(\.nombre) == ["Telmisartán", "Dramamine"])
    }

    @Test func sinMedicamentosDevuelveListaVacia() {
        #expect(RecetaTextoParser.medicamentos(en: ["Paciente: Ana", "Diagnóstico: faringitis"]).isEmpty)
    }

    // MARK: - MedicationDraft.aplicar

    @Test func aplicarLlenaElFormularioYCalculaLaFechaDeFin() throws {
        var draft = MedicationDraft()
        draft.aplicar(MedicamentoTranscrito(
            nombre: "Paracetamol", dosis: "500 mg", unidad: "mg", presentacion: "tabletas",
            frecuencia: "cada 8 horas", duracionDias: 5, indicacion: "Tomar con alimentos"
        ))

        #expect(draft.name == "Paracetamol")
        #expect(draft.dose == "500")
        #expect(draft.unit == "mg")
        #expect(draft.presentation == "tabletas")
        #expect(draft.frequency == "cada 8 horas")
        #expect(draft.indication == "Tomar con alimentos")
        #expect(draft.hasEndDate)
        let dias = Calendar.current.dateComponents([.day], from: draft.startDate, to: draft.endDate).day
        #expect(dias == 4)
        #expect(draft.isValid)
    }

    @Test func aplicarSinDuracionQuitaLaFechaDeFin() {
        var draft = MedicationDraft()
        draft.hasEndDate = true
        draft.aplicar(MedicamentoTranscrito(nombre: "Loratadina", dosis: "10", unidad: "mg"))

        #expect(!draft.hasEndDate)
        #expect(draft.frequency.isEmpty)
    }

    // MARK: - TranscripcionRecetaViewModel

    private struct TranscriptorFalso: TranscriptorReceta {
        var resultado: Result<RecetaTranscrita, Error>
        func transcribir(_ imagen: UIImage) async throws -> RecetaTranscrita { try resultado.get() }
    }

    private static let imagen = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in }

    @Test func unSoloMedicamentoSeAplicaDeInmediato() async {
        let paracetamol = MedicamentoTranscrito(nombre: "Paracetamol", dosis: "500", unidad: "mg")
        var guardados = 0
        let modelo = TranscripcionRecetaViewModel(
            transcriptor: TranscriptorFalso(resultado: .success(
                RecetaTranscrita(medicamentos: [paracetamol], metodo: .reconocimientoTexto)
            )),
            guardarDocumento: { _, _ in guardados += 1 }
        )

        let aplicado = await modelo.transcribir(Self.imagen, familiarID: UUID())

        #expect(aplicado == paracetamol)
        #expect(modelo.aplicada)
        #expect(modelo.guardadaEnDocumentos)
        #expect(guardados == 1)
        #expect(modelo.metodo == .reconocimientoTexto)
        #expect(!modelo.leyendo)
    }

    @Test func variosMedicamentosQuedanComoCandidatos() async {
        let lista = [MedicamentoTranscrito(nombre: "A"), MedicamentoTranscrito(nombre: "B")]
        let modelo = TranscripcionRecetaViewModel(
            transcriptor: TranscriptorFalso(resultado: .success(
                RecetaTranscrita(medicamentos: lista, metodo: .appleIntelligenceTexto)
            )),
            guardarDocumento: { _, _ in }
        )

        let aplicado = await modelo.transcribir(Self.imagen, familiarID: UUID())
        #expect(aplicado == nil)
        #expect(modelo.candidatos == lista)

        #expect(modelo.elegir(lista[1]) == lista[1])
        #expect(modelo.candidatos.isEmpty)
        #expect(modelo.aplicada)
    }

    @Test func unErrorDeLecturaSeMuestraSinPerderLaCopiaGuardada() async {
        struct FallaGuardar: Error {}
        let modelo = TranscripcionRecetaViewModel(
            transcriptor: TranscriptorFalso(resultado: .failure(RecetaExtractorError.sinTexto)),
            guardarDocumento: { _, _ in throw FallaGuardar() }
        )

        let aplicado = await modelo.transcribir(Self.imagen, familiarID: UUID())

        #expect(aplicado == nil)
        #expect(!modelo.guardadaEnDocumentos)
        #expect(modelo.error?.contains("No se encontró texto") == true)
    }
}
