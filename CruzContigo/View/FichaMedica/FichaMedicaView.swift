//
//  FichaMedicaView.swift
//  CruzContigo
//
//  Ordenada por importancia en una emergencia: primero sangre y alergias, después
//  enfermedades y, plegado, lo demás. Las secciones vacías no se muestran.
//

import SwiftUI

struct FichaMedicaView: View {
    let familiarID: UUID

    @Environment(FamiliaresStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: FichaMedicaViewModel
    @State private var editando = false
    @State private var mostrandoDocumentos = false
    @State private var gestionandoAccesos = false
    @State private var detallesAbiertos = false

    init(familiarID: UUID) {
        self.familiarID = familiarID
        _viewModel = State(initialValue: FichaMedicaViewModel(familiarID: familiarID))
    }

    private var familiar: Familiar? {
        store.familiares.first { $0.id == familiarID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 12)

            switch viewModel.estado {
            case .cargando:
                Spacer()
                ProgressView("Cargando ficha…")
                Spacer()
            case .error(let mensaje):
                Spacer()
                EstadoErrorView(mensaje: mensaje) {
                    Task { await viewModel.cargar() }
                }
                Spacer()
            case .sinAcceso(let mensaje):
                sinAcceso(mensaje)
            case .sinFicha:
                sinFicha
            case .lista:
                if let ficha = viewModel.ficha {
                    contenido(ficha)
                }
            }
        }
        .task { await viewModel.cargar() }
        .sheet(isPresented: $editando) {
            EditFichaMedicaView(ficha: viewModel.borrador, nombre: familiar?.nombre ?? "") { nueva in
                await viewModel.guardar(nueva)
            }
        }
        .sheet(isPresented: $mostrandoDocumentos) {
            DocumentosMedicosView(familiarID: familiarID, puedeEditar: familiar?.puedeEditar ?? false)
        }
        .sheet(isPresented: $gestionandoAccesos) {
            AccesosFichaView(familiarID: familiarID, nombre: familiar?.nombre ?? "")
        }
    }

    private var puedeEditar: Bool { familiar?.puedeEditar == true }
    private var puedeVerDocumentos: Bool { familiar?.esProfesional != true }

    private var muestraAccesos: Bool {
        guard familiar?.puedeGestionarAccesos == true, AppConfig.apiBaseURL != nil else { return false }
        return viewModel.estado == .lista || viewModel.estado == .sinFicha
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack(spacing: 8) {
            BrandBackButton { dismiss() }
            Spacer()
            if muestraAccesos {
                Menu {
                    Button {
                        gestionandoAccesos = true
                    } label: {
                        Label("Quién puede verla", systemImage: "person.badge.key.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .icono(.navegacion)
                        .foregroundColor(.brandRed)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Más opciones")
            }
            if viewModel.estado == .lista, puedeEditar {
                Button {
                    editando = true
                } label: {
                    Label("Editar", systemImage: "pencil")
                        .font(.app(.subheadline).weight(.bold))
                        .foregroundColor(.brandRed)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Color.tintaSuave)
                        .cornerRadius(12)
                }
            }
        }
    }

    private var titulo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FICHA MÉDICA")
                .font(.app(.caption))
                .fontWeight(.bold)
                .foregroundColor(.brandRed)
            Text(familiar?.nombreCompleto ?? "Familiar")
                .font(.app(.title).weight(.bold))
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sin ficha

    private var sinFicha: some View {
        VStack(spacing: 0) {
            titulo
                .padding(.horizontal, 24)
                .padding(.top, 16)
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "heart.text.square.fill")
                    .icono(.destacado)
                    .foregroundColor(.brandRed)
                    .accessibilityHidden(true)
                Text("Aún no tiene ficha médica")
                    .font(.app(.title3).weight(.bold))
                Text("Son 3 preguntas: tipo de sangre, alergias y enfermedades. Sirven para que un médico le atienda rápido en una emergencia.")
                    .font(.app(.body))
                    .foregroundColor(.textoSuave)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 8) {
                if puedeEditar {
                    PrimaryButton(title: "Empezar") { editando = true }
                }
                if puedeVerDocumentos {
                    Button("Ver documentos médicos") { mostrandoDocumentos = true }
                        .font(.app(.headline))
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Ficha

    private func contenido(_ ficha: FichaMedica) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titulo
                if familiar?.esProfesional == true {
                    avisoProfesional
                }

                TarjetaEmergencia(ficha: ficha)

                if puedeEditar, !ficha.datosPendientes.isEmpty {
                    pendientes(ficha.datosPendientes)
                }

                if !ficha.enfermedades.isEmpty {
                    SeccionFicha(titulo: "Enfermedades", icono: "heart.text.square", vacio: "") {
                        ForEach(ficha.enfermedades) { enfermedad in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(enfermedad.nombre).font(.app(.body))
                                if let notas = enfermedad.notas {
                                    Text(notas).font(.app(.caption)).foregroundColor(.textoSuave)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                        }
                    } esVacio: { false }
                }

                if ficha.tieneDetalles {
                    masDetalles(ficha)
                }

                if puedeVerDocumentos {
                    Button { mostrandoDocumentos = true } label: {
                        Label("Recetas y estudios", systemImage: "folder.fill")
                            .font(.app(.headline))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.tintaSuave))
                    }
                    .accessibilityHint("Abre las fotos de recetas, estudios y archivos PDF")
                }

                Text("Actualizada el \(ficha.ultimaActualizacion.formatted(date: .long, time: .shortened))")
                    .font(.app(.footnote))
                    .foregroundColor(.textoSuave)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    private func pendientes(_ datos: [String]) -> some View {
        Button {
            editando = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .icono(.seleccion)
                    .foregroundColor(.brandRed)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Falta: \(datos.joined(separator: ", "))")
                        .font(.app(.subheadline).weight(.semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    Text("Completar")
                        .font(.app(.subheadline).weight(.bold))
                        .foregroundColor(.brandRed)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.tintaSuave))
        }
        .buttonStyle(.plain)
    }

    private func masDetalles(_ ficha: FichaMedica) -> some View {
        DisclosureGroup(isExpanded: $detallesAbiertos) {
            VStack(alignment: .leading, spacing: 14) {
                if let medico = ficha.medicoTratante {
                    Dato(titulo: "Su doctor", valor: medico)
                }
                if let institucion = ficha.institucionSalud {
                    Dato(titulo: "Dónde se atiende", valor: institucion)
                }
                if let antecedentes = ficha.antecedentes {
                    Dato(titulo: "Operaciones o enfermedades pasadas", valor: antecedentes)
                }
                if let observaciones = ficha.observaciones {
                    Dato(titulo: "Algo más que deba saber un médico", valor: observaciones)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
        } label: {
            Label("Más detalles", systemImage: "list.bullet.rectangle")
                .font(.app(.headline))
                .foregroundColor(.primary)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .tarjetaBorde(radio: 18)
    }

    private var avisoProfesional: some View {
        Label {
            Text("Acceso profesional de solo lectura. Esta consulta queda registrada y la persona titular puede verla.")
        } icon: {
            Image(systemName: "stethoscope")
        }
        .font(.app(.footnote))
        .foregroundColor(.textoSuave)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.tintaSuave))
    }

    private func sinAcceso(_ mensaje: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "lock.fill")
                .icono(.destacado)
                .foregroundColor(.brandRed)
                .accessibilityHidden(true)
            Text("Ya no tienes acceso a esta ficha")
                .font(.app(.headline))
            Text(mensaje)
                .font(.app(.subheadline))
                .foregroundColor(.textoSuave)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton(title: "Volver") {
                Task {
                    await store.cargar()
                    dismiss()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

// MARK: - Componentes

/// Lo primero que necesita un paramédico: tipo de sangre y alergias, con las
/// peligrosas marcadas. Se reutiliza en la ficha de emergencia sin conexión.
struct TarjetaEmergencia: View {
    let tipoSanguineo: TipoSanguineo?
    let alergias: [Alergia]

    init(ficha: FichaMedica) {
        self.init(tipoSanguineo: ficha.tipoSanguineo, alergias: ficha.alergias)
    }

    init(tipoSanguineo: TipoSanguineo?, alergias: [Alergia]) {
        self.tipoSanguineo = tipoSanguineo
        self.alergias = alergias.sorted { ($0.severidad == .grave ? 0 : 1) < ($1.severidad == .grave ? 0 : 1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "drop.fill")
                    .icono(.grande)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Tipo de sangre")
                        .font(.app(.subheadline).weight(.semibold))
                        .opacity(0.9)
                    Text(tipoSanguineo?.titulo ?? "No lo sé")
                        .font(.app(.largeTitle).weight(.bold))
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)

            Divider().overlay(Color.white.opacity(0.4))

            VStack(alignment: .leading, spacing: 8) {
                Text("Alergias")
                    .font(.app(.subheadline).weight(.semibold))
                    .opacity(0.9)
                if alergias.isEmpty {
                    Text("Sin alergias conocidas")
                        .font(.app(.title3).weight(.bold))
                } else {
                    ForEach(alergias) { alergia in
                        HStack(spacing: 8) {
                            if alergia.severidad == .grave {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .accessibilityHidden(true)
                            }
                            Text(alergia.nombre)
                                .font(.app(.title3).weight(.bold))
                            Spacer()
                            Text(alergia.severidad.titulo)
                                .font(.app(.caption).weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(alergia.severidad == .grave ? 0.35 : 0.2)))
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .foregroundColor(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.rojoSolido))
    }
}

private struct Dato: View {
    let titulo: String
    let valor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo)
                .font(.app(.caption))
                .foregroundColor(.textoSuave)
            Text(valor)
                .font(.app(.body))
        }
        .accessibilityElement(children: .combine)
    }
}

struct SeccionFicha<Content: View>: View {
    let titulo: String
    let icono: String
    let vacio: String
    @ViewBuilder let content: Content
    let esVacio: () -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(titulo, systemImage: icono)
                .font(.app(.headline))
                .foregroundColor(.primary)
            VStack(alignment: .leading, spacing: 0) {
                if esVacio() {
                    Text(vacio)
                        .font(.app(.subheadline))
                        .foregroundColor(.textoSuave)
                        .padding(.vertical, 6)
                } else {
                    content
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.borderGray, lineWidth: 1)
            )
        }
    }
}

struct SeveridadChip: View {
    let severidad: Severidad

    private var color: Color {
        switch severidad {
        case .leve: .orange
        case .moderada: .orange.mix(with: .brandRed, by: 0.5)
        case .grave: .brandRed
        }
    }

    var body: some View {
        Text(severidad.titulo)
            .font(.app(.caption).weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}
