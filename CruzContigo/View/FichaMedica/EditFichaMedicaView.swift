//
//  EditFichaMedicaView.swift
//  CruzContigo
//

import SwiftUI

struct EditFichaMedicaView: View {
    let nombre: String
    let onGuardar: (FichaMedica) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var ficha: FichaMedica
    @State private var observaciones: String
    @State private var nuevaAlergia = ""
    @State private var nuevaSeveridad: Severidad? = .leve
    @State private var nuevaEnfermedad = ""
    @State private var intentoGuardar = false
    @State private var guardando = false
    @State private var errorGuardado: String?

    init(ficha: FichaMedica, nombre: String, onGuardar: @escaping (FichaMedica) async -> String?) {
        self.nombre = nombre
        self.onGuardar = onGuardar
        _ficha = State(initialValue: ficha)
        _observaciones = State(initialValue: ficha.observaciones ?? "")
    }

    private var fichaFinal: FichaMedica {
        var f = ficha
        let obs = observaciones.trimmingCharacters(in: .whitespacesAndNewlines)
        f.observaciones = obs.isEmpty ? nil : obs
        return f
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancelar") { dismiss() }
                    .foregroundColor(.brandRed)
                Spacer()
                Text("Ficha médica").font(.app(.headline))
                Spacer()
                Button("Cancelar") {}.hidden()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(nombre.isEmpty ? "Datos médicos" : "Datos médicos de \(nombre)")
                            .font(.system(size: 26, weight: .bold))
                        Text("Usa datos ficticios durante las pruebas.")
                            .font(.app(.footnote))
                            .foregroundColor(.textoSuave)
                    }

                    FormFieldContainer(
                        titulo: "Tipo sanguíneo",
                        obligatorio: true,
                        error: intentoGuardar && ficha.tipoSanguineo == nil ? "Selecciona una opción." : nil
                    ) {
                        ChipSelector(
                            opciones: TipoSanguineo.allCases,
                            seleccion: $ficha.tipoSanguineo,
                            titulo: \.titulo
                        )
                    }

                    seccionAlergias
                    seccionEnfermedades

                    FormFieldContainer(titulo: "Observaciones (opcional)") {
                        TextField("Ej. Marcapasos, usa lentes, dieta baja en sodio", text: $observaciones, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(16)
                            .fieldBorder(false)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 10) {
                if intentoGuardar, let primerError = fichaFinal.errores.first {
                    Text(primerError)
                        .font(.app(.footnote))
                        .foregroundColor(.brandRed)
                }
                PrimaryButton(title: guardando ? "Guardando…" : "Guardar ficha") {
                    Task { await guardar() }
                }
                .disabled(guardando)
                .opacity(guardando ? 0.7 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .tint(.brandRed)
        .interactiveDismissDisabled(guardando)
        .alert("No se pudo guardar", isPresented: Binding(
            get: { errorGuardado != nil },
            set: { if !$0 { errorGuardado = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(errorGuardado ?? "")
        }
    }

    private var seccionAlergias: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alergias").font(.app(.title3)).fontWeight(.bold)

            ForEach(ficha.alergias) { alergia in
                FilaEditable(texto: alergia.nombre) {
                    SeveridadChip(severidad: alergia.severidad)
                } eliminar: {
                    ficha.alergias.removeAll { $0.id == alergia.id }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Ej. Penicilina", text: $nuevaAlergia)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .fieldBorder(false)
                        .onSubmit(agregarAlergia)
                    BotonAgregar(habilitado: !limpio(nuevaAlergia).isEmpty, accion: agregarAlergia)
                }
                ChipSelector(opciones: Severidad.allCases, seleccion: $nuevaSeveridad, titulo: \.titulo)
            }
        }
    }

    private func agregarAlergia() {
        let nombre = limpio(nuevaAlergia)
        guard !nombre.isEmpty else { return }
        ficha.alergias.append(Alergia(nombre: nombre, severidad: nuevaSeveridad ?? .leve))
        nuevaAlergia = ""
    }

    private var seccionEnfermedades: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Enfermedades").font(.app(.title3)).fontWeight(.bold)

            ForEach(ficha.enfermedades) { enfermedad in
                FilaEditable(texto: enfermedad.nombre) {
                    EmptyView()
                } eliminar: {
                    ficha.enfermedades.removeAll { $0.id == enfermedad.id }
                }
            }

            HStack(spacing: 8) {
                TextField("Ej. Diabetes tipo 2", text: $nuevaEnfermedad)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .fieldBorder(false)
                    .onSubmit(agregarEnfermedad)
                BotonAgregar(habilitado: !limpio(nuevaEnfermedad).isEmpty, accion: agregarEnfermedad)
            }
        }
    }

    private func agregarEnfermedad() {
        let nombre = limpio(nuevaEnfermedad)
        guard !nombre.isEmpty else { return }
        ficha.enfermedades.append(Enfermedad(nombre: nombre))
        nuevaEnfermedad = ""
    }

    private func limpio(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces)
    }

    private func guardar() async {
        intentoGuardar = true
        agregarAlergia()
        agregarEnfermedad()
        guard fichaFinal.esValida else { return }
        guardando = true
        defer { guardando = false }
        if let error = await onGuardar(fichaFinal) {
            errorGuardado = error
        } else {
            dismiss()
        }
    }
}

private struct FilaEditable<Accesorio: View>: View {
    let texto: String
    @ViewBuilder let accesorio: Accesorio
    let eliminar: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(texto)
            Spacer()
            accesorio
            Button(action: eliminar) {
                Image(systemName: "minus.circle.fill")
                    .icono(.seleccion)
                    .foregroundColor(Color.iconoSuave)
            }
            .accessibilityLabel("Eliminar \(texto)")
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.tintaSuave))
    }
}

private struct BotonAgregar: View {
    let habilitado: Bool
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Image(systemName: "plus")
                .icono(.navegacion)
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.rojoSolido))
        }
        .disabled(!habilitado)
        .opacity(habilitado ? 1 : 0.4)
        .accessibilityLabel("Agregar")
    }
}
