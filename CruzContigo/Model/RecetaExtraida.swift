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

    @Guide(description: "Duración del tratamiento en días, solo si está escrita explícitamente. Por ejemplo 'por 7 días' es 7 y 'por 2 semanas' es 14")
    var duracionDias: Int?

    @Guide(description: "Indicación escrita explícitamente en la receta")
    var indicacion: String?
}


@Generable
struct RecetaExtraida {
    @Guide(description: "Todos los medicamentos visibles en la receta")
    var medicamentos: [MedicamentoExtraido]
}

extension MedicamentoExtraido {
    var transcrito: MedicamentoTranscrito {
        MedicamentoTranscrito(
            nombre: nombre,
            dosis: dosis,
            unidad: unidad,
            presentacion: presentacion,
            frecuencia: frecuencia,
            duracionDias: duracionDias,
            indicacion: indicacion
        )
    }
}
