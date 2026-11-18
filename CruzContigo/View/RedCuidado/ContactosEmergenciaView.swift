//
//  ContactosEmergenciaView.swift
//  CruzContigo
//
//  RF-15: a quién llamar en una emergencia, en orden. Se ven en la ficha de
//  emergencia, también sin conexión.
//

import SwiftUI
import Contacts

struct ContactosEmergenciaView: View {
    let nombre: String
    let puedeEditar: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ContactosEmergenciaViewModel
    @State private var editando: Edicion?
    @State private var porEliminar: ContactoRegistrado?

    struct Edicion: Identifiable {
        let id = UUID()
        let contacto: ContactoRegistrado?
    }

    init(familiarID: UUID, nombre: String, puedeEditar: Bool) {
        self.nombre = nombre
        self.puedeEditar = puedeEditar
        _viewModel = State(initialValue: ContactosEmergenciaViewModel(familiarID: familiarID))
    }

    var body: some View {
        NavigationStack {
            contenido
                .navigationTitle("Contactos de emergencia")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { dismiss() }
                    }
                    if puedeEditar, viewModel.contactos.count > 1 {
                        ToolbarItem(placement: .primaryAction) { EditButton() }
                    }
                }
        }
        .tint(.brandRed)
        .task { await viewModel.cargar() }
        .sheet(item: $editando) { edicion in
            EditarContactoView(contacto: edicion.contacto) { solicitud in
                try await viewModel.guardar(solicitud, id: edicion.contacto?.id)
            }
        }
        .confirmationDialog(
            "¿Quitar este contacto?",
            isPresented: Binding(get: { porEliminar != nil }, set: { if !$0 { porEliminar = nil } }),
            titleVisibility: .visible,
            presenting: porEliminar
        ) { contacto in
            Button("Quitar a \(contacto.nombre)", role: .destructive) {
                Task { await viewModel.eliminar(contacto) }
            }
            Button("Volver", role: .cancel) {}
        }
        .alert("No se pudo completar", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    @ViewBuilder
    private var contenido: some View {
        switch viewModel.estado {
        case .cargando:
            ProgressView("Cargando contactos…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let mensaje):
            EstadoErrorView(mensaje: mensaje) {
                Task { await viewModel.cargar() }
            }
        case .listo:
            List {
                Section {
                    Text("A quién avisar si a \(nombre) le pasa algo. El primero es a quien se llama primero.")
                        .font(.app(.subheadline))
                        .foregroundColor(.textoSuave)
                        .listRowBackground(Color.clear)
                }
                Section {
                    if viewModel.contactos.isEmpty {
                        Text("Aún no hay contactos.")
                            .font(.app(.body))
                            .foregroundColor(.textoSuave)
                    }
                    ForEach(viewModel.contactos) { contacto in
                        FilaContacto(contacto: contacto)
                            .contentShape(Rectangle())
                            .onTapGesture { if puedeEditar { editando = Edicion(contacto: contacto) } }
                            .swipeActions {
                                if puedeEditar {
                                    Button("Quitar", role: .destructive) { porEliminar = contacto }
                                }
                            }
                    }
                    .onMove { origen, destino in
                        Task { await viewModel.mover(desde: origen, hacia: destino) }
                    }
                    .moveDisabled(!puedeEditar)
                }
                if puedeEditar, viewModel.puedeAgregar {
                    Section {
                        Button {
                            editando = Edicion(contacto: nil)
                        } label: {
                            Label("Agregar contacto", systemImage: "plus.circle.fill")
                                .font(.app(.headline))
                                .frame(minHeight: 44)
                        }
                    }
                }
            }
            .refreshable { await viewModel.cargar() }
        }
    }
}

private struct FilaContacto: View {
    let contacto: ContactoRegistrado

    var body: some View {
        HStack(spacing: 14) {
            Text("\(contacto.prioridad)")
                .font(.app(.headline))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.rojoSolido))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(contacto.nombre)
                    .font(.app(.body).weight(.semibold))
                Text([contacto.parentesco, contacto.telefono].compactMap { $0 }.joined(separator: " · "))
                    .font(.app(.subheadline))
                    .foregroundColor(.textoSuave)
            }
            Spacer()
            if let url = URL(string: "tel:\(contacto.telefono)") {
                Link(destination: url) {
                    Image(systemName: "phone.fill")
                        .icono(.seleccion)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Llamar a \(contacto.nombre)")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Contacto \(contacto.prioridad): \(contacto.nombre)")
    }
}

private struct EditarContactoView: View {
    let contacto: ContactoRegistrado?
    let guardar: (SolicitudContacto) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var solicitud: SolicitudContacto
    @State private var parentesco: String
    @State private var intento = false
    @State private var guardando = false
    @State private var error: String?

    init(contacto: ContactoRegistrado?, guardar: @escaping (SolicitudContacto) async throws -> Void) {
        self.contacto = contacto
        self.guardar = guardar
        _solicitud = State(initialValue: SolicitudContacto(
            nombre: contacto?.nombre ?? "", telefono: contacto?.telefono ?? "", parentesco: contacto?.parentesco
        ))
        _parentesco = State(initialValue: contacto?.parentesco ?? "")
    }

    private var final: SolicitudContacto {
        var s = solicitud
        s.parentesco = parentesco
        return s
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Button {
                        SelectorContactos.presentar { elegido in
                            solicitud.nombre = [elegido.givenName, elegido.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                            if let numero = elegido.phoneNumbers.first?.value.stringValue {
                                solicitud.telefono = String(numero.filter(\.isNumber).suffix(10))
                            }
                        }
                    } label: {
                        Label("Elegir de mis contactos", systemImage: "person.crop.circle.badge.plus")
                            .font(.app(.headline))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.tintaSuave))
                    }

                    BrandTextField(
                        titulo: "Nombre", placeholder: "Ej. Laura", texto: $solicitud.nombre, obligatorio: true,
                        error: intento && solicitud.nombre.trimmingCharacters(in: .whitespaces).count < 2 ? "Escribe el nombre." : nil
                    )
                    BrandTextField(
                        titulo: "Teléfono", placeholder: "10 dígitos", texto: $solicitud.telefono, obligatorio: true,
                        error: intento && final.errores.contains { $0.contains("teléfono") } ? "Escribe un teléfono de 10 dígitos." : nil,
                        teclado: .phonePad
                    )
                    FormFieldContainer(titulo: "¿Quién es? (opcional)", obligatorio: false) {
                        ChipSelector(
                            opciones: SolicitudContacto.parentescosSugeridos.map(Sugerencia.init),
                            seleccion: Binding(
                                get: { parentesco.isEmpty ? nil : Sugerencia(id: parentesco) },
                                set: { parentesco = $0?.id ?? "" }
                            ),
                            titulo: \.id
                        )
                        TextField("Otro", text: $parentesco)
                            .font(.app(.body))
                            .padding(12)
                            .fieldBorder(false)
                    }
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(contacto == nil ? "Nuevo contacto" : "Editar contacto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await enviar() } }
                        .disabled(guardando)
                }
            }
        }
        .tint(.brandRed)
        .interactiveDismissDisabled(guardando)
        .alert("No se pudo guardar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private func enviar() async {
        intento = true
        guard final.esValida else { return }
        guardando = true
        defer { guardando = false }
        do {
            try await guardar(final)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Envoltorio para usar textos sugeridos con ChipSelector.
struct Sugerencia: Identifiable, Hashable {
    let id: String
}
