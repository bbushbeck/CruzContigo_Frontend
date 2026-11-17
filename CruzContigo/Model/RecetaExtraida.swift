//
//  RecetaExtraida.swift
//  CruzContigo
//
//  Created by Ricardo Gómez on 10/11/26.
//

import FoundationModels

@Generable
struct MedicamentoExtraido {
    @Guide(description: "Nombre del medicamento, exactamente como aparece")
    var nombre: String

    @Guide(description: "Cantidad numérica de la dosis, sin su unidad")
    var dosis: String?

    @Guide(description: "Unidad de la dosis, por ejemplo mg, ml o g")
    var unidad: String?

    @Guide(description: "Presentación, por ejemplo tabletas, cápsulas o solución")
    var presentacion: String?

    @Guide(description: "Frecuencia indicada, por ejemplo cada 8 horas")
    var frecuencia: String?

    @Guide(description: "Indicación escrita explícitamente en la receta")
    var indicacion: String?
}


@Generable
struct RecetaExtraida {
    @Guide(description: "Todos los medicamentos visibles en la receta")
    var medicamentos: [MedicamentoExtraido]
}

extension MedicationDraft {
    mutating func aplicar(_ medicamento: MedicamentoExtraido) {
        name = medicamento.nombre
        dose = medicamento.dosis ?? ""
        unit = medicamento.unidad ?? ""
        presentation = medicamento.presentacion ?? ""
        frequency = medicamento.frecuencia ?? ""
        indication = medicamento.indicacion ?? ""
    }
}
