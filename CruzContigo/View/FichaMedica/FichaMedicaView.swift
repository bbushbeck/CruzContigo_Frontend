//
//  FichaMedicaView.swift
//  CruzContigo
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

    private var puedeVerDocumentos: Bool { familiar?.esProfesional != true }

    private var muestraAccesos: Bool {
        guard familiar?.puedeGestionarAccesos == true, AppConfig.apiBaseURL != nil else { return false }
        return viewModel.estado == .lista || viewModel.estado == .sinFicha
    }

    private var header: some View {
        HStack {
            BrandBackButton { dismiss() }
            Spacer()
            if muestraAccesos {
                Button {
                    gestionandoAccesos = true
                } label: {
                    Label("Accesos", systemImage: "person.badge.key.fill")
                        .font(.app(.subheadline).weight(.bold))
                        .foregroundColor(.brandRed)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Color.tintaSuave)
                        .cornerRadius(12)
                }
                .accessibilityHint("Autoriza o retira quién puede ver esta ficha")
            }
            if viewModel.estado == .lista, familiar?.puedeEditar == true {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sinFicha: some View {
        VStack(spacing: 0) {
            titulo
                .padding(.horizontal, 24)
                .padding(.top, 16)
            Spacer()
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 96, height: 96)
                    Image(systemName: "doc.text.fill")
                        .icono(.destacado)
                        .foregroundColor(.brandRed)
                }
                Text("Sin ficha médica")
                    .font(.app(.headline))
                Text("Registra su tipo de sangre, alergias y enfermedades para tenerlos a la mano en una emergencia.")
                    .font(.app(.subheadline))
                    .foregroundColor(.textoSuave)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 8) {
                if familiar?.puedeEditar == true {
                    PrimaryButton(title: "Crear ficha médica") { editando = true }
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

    private func contenido(_ ficha: FichaMedica) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titulo
                if familiar?.esProfesional == true {
                    avisoProfesional
                }
                tarjetaSangre(ficha)

                SeccionFicha(titulo: "Alergias", icono: "allergens", vacio: "Sin alergias registradas") {
                    ForEach(ficha.alergias) { alergia in
                        HStack {
                            Text(alergia.nombre).font(.app(.body))
                            Spacer()
                            SeveridadChip(severidad: alergia.severidad)
                        }
                        .padding(.vertical, 6)
                    }
                } esVacio: { ficha.alergias.isEmpty }

                SeccionFicha(titulo: "Enfermedades", icono: "heart.text.square", vacio: "Sin enfermedades registradas") {
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
                } esVacio: { ficha.enfermedades.isEmpty }

                if let antecedentes = ficha.antecedentes {
                    SeccionFicha(titulo: "Antecedentes", icono: "clock.arrow.circlepath", vacio: "") {
                        Text(antecedentes).font(.app(.body))
                    } esVacio: { false }
                }

                if ficha.medicoTratante != nil || ficha.institucionSalud != nil {
                    SeccionFicha(titulo: "Atención médica", icono: "stethoscope", vacio: "") {
                        if let medico = ficha.medicoTratante {
                            Text("Médico tratante").font(.app(.caption)).foregroundColor(.textoSuave)
                            Text(medico).font(.app(.body)).padding(.bottom, 6)
                        }
                        if let institucion = ficha.institucionSalud {
                            Text("Institución de salud").font(.app(.caption)).foregroundColor(.textoSuave)
                            Text(institucion).font(.app(.body))
                        }
                    } esVacio: { false }
                }

                if let observaciones = ficha.observaciones {
                    SeccionFicha(titulo: "Observaciones", icono: "note.text", vacio: "") {
                        Text(observaciones).font(.app(.body))
                    } esVacio: { false }
                }

                if puedeVerDocumentos {
                    Button { mostrandoDocumentos = true } label: {
                        Label("Documentos médicos", systemImage: "folder.fill")
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

    private func tarjetaSangre(_ ficha: FichaMedica) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.clear)
                    .frame(width: 64, height: 64)
                Image(systemName: "drop.fill")
                    .icono(.grande)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Tipo sanguíneo")
                    .font(.app(.subheadline).weight(.semibold))
                    .opacity(0.9)
                Text(ficha.tipoSanguineo?.titulo ?? "—")
                    .font(.system(size: 34, weight: .bold))
            }
            Spacer()
        }
        .foregroundColor(.white)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.rojoSolido))
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
