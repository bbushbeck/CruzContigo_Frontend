//
//  Recordatorio.swift
//  Recordatorio
//
//  Created by María Fernanda Espinosa Vásquez on 20/10/26.
//

import SwiftUI
import Observation

private let rojo = Color.brandRed
private let rosa = Color.tintaSuave

struct Recordatorio: Identifiable {
    let id = UUID()
    var titulo: String
    var familiarID: UUID
    var fecha: Date
    var completado = false
}

/// Recordatorios de la sesión, compartidos entre pantallas.
@Observable
final class RecordatoriosStore {
    var recordatorios: [Recordatorio] = []

    func agregar(_ recordatorio: Recordatorio) {
        recordatorios.append(recordatorio)
        recordatorios.sort { $0.fecha < $1.fecha }
    }
}

struct RecordatoriosView: View {
    /// Si se indica, solo se muestran los recordatorios de ese familiar.
    var familiarID: UUID? = nil
    var mostrarAtras = true

    @Environment(FamiliaresStore.self) private var familiares
    @Environment(RecordatoriosStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var mostrarFormulario = false

    private var familiar: Familiar? {
        familiarID.flatMap { id in familiares.familiares.first { $0.id == id } }
    }

    private func nombre(de id: UUID) -> String {
        familiares.familiares.first { $0.id == id }?.nombre ?? "Familiar"
    }

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            if mostrarAtras {
                HStack {
                    BrandBackButton { dismiss() }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    Text("Mis recordatorios")
                        .font(.app(.title2).bold())

                    Text(familiar.map { "Organiza el cuidado de \($0.nombre)." } ?? "Organiza el cuidado de tus familiares.")
                        .font(.app(.subheadline))
                        .foregroundStyle(Color.textoSuave)

                    Text("Próximos recordatorios")
                        .font(.app(.headline))

                    if !store.recordatorios.contains(where: { familiarID == nil || $0.familiarID == familiarID }) {
                        ContentUnavailableView("Sin recordatorios", systemImage: "bell",
                            description: Text("Agrega uno para recibir una notificación."))
                    }

                    ForEach($store.recordatorios) { $recordatorio in
                        if familiarID == nil || recordatorio.familiarID == familiarID {
                            HStack(spacing: 12) {
                                Image(systemName: "bell.fill")
                                    .icono(.mediano)
                                    .foregroundStyle(rojo)
                                    .padding(12)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(recordatorio.titulo)
                                        .font(.app(.subheadline).bold())
                                        .strikethrough(recordatorio.completado)

                                    Text(nombre(de: recordatorio.familiarID))
                                        .font(.app(.caption))
                                        .foregroundStyle(Color.textoSuave)

                                    Text(recordatorio.fecha,
                                         format: .dateTime
                                            .day()
                                            .month()
                                            .hour()
                                            .minute())
                                        .font(.app(.caption))
                                        .foregroundStyle(rojo)
                                }

                                Spacer()

                                Button {
                                    recordatorio.completado.toggle()
                                } label: {
                                    Image(systemName:
                                        recordatorio.completado
                                        ? "checkmark.circle.fill"
                                        : "circle"
                                    )
                                    .icono(.seleccion)
                                    .foregroundStyle(rojo)
                                }
                            }
                            .padding()
                            .background(rosa)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                    }

                    Button {
                        mostrarFormulario = true
                    } label: {
                        Label("Agregar recordatorio", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.rojoSolido)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(familiares.familiares.isEmpty)
                }
                .padding()
            }
        }
        .sheet(isPresented: $mostrarFormulario) {
            NuevoRecordatorioView(
                familiares: familiares.familiares,
                familiarInicial: familiarID ?? familiares.familiares.first?.id
            ) { nuevo in
                store.agregar(nuevo)
            }
        }
    }
}

struct NuevoRecordatorioView: View {
    @Environment(\.dismiss) private var dismiss

    let familiares: [Familiar]
    var onGuardar: (Recordatorio) -> Void
    let notify = NotificationHandler()

    @State private var titulo = ""
    @State private var familiarID: UUID?
    @State private var fecha = Date().addingTimeInterval(300)

    init(familiares: [Familiar], familiarInicial: UUID?, onGuardar: @escaping (Recordatorio) -> Void) {
        self.familiares = familiares
        self.onGuardar = onGuardar
        _familiarID = State(initialValue: familiarInicial)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre del recordatorio", text: $titulo)

                Picker("Familiar", selection: $familiarID) {
                    ForEach(familiares) { familiar in
                        Text(familiar.nombre).tag(Optional(familiar.id))
                    }
                }

                DatePicker(
                    "Fecha y hora",
                    selection: $fecha,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
            .navigationTitle("Nuevo recordatorio")
            .onAppear {
                notify.askPermission()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guard let familiarID else { return }
                        let nuevo = Recordatorio(
                            titulo: titulo,
                            familiarID: familiarID,
                            fecha: fecha
                        )
                        let nombre = familiares.first { $0.id == familiarID }?.nombre ?? ""

                        notify.sendNotification(
                            date: fecha,
                            type: "date",
                            title: "CruzContigo ❤️",
                            body: "\(nombre): \(titulo)"
                        )

                        onGuardar(nuevo)
                        dismiss()
                    }

                    .disabled(familiarID == nil || titulo.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty)
                }
            }
        }
        .tint(rojo)
    }
}

#Preview {
    NavigationStack {
        RecordatoriosView()
    }
    .environment(FamiliaresStore())
    .environment(RecordatoriosStore())
}
