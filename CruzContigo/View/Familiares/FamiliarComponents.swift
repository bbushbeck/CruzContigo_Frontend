//
//  FamiliarComponents.swift
//  CruzContigo
//

import SwiftUI

extension Color {
    static let tintaSuave = Color.adaptable(
        claro: UIColor(red: 0.86, green: 0.11, blue: 0.14, alpha: 0.07),
        oscuro: UIColor(red: 0.94, green: 0.48, blue: 0.48, alpha: 0.16)
    )

    private static let paletaAvatar: [Color] = [
        .brandRed,
        .adaptable(claro: UIColor(red: 0.11, green: 0.40, blue: 0.70, alpha: 1), oscuro: UIColor(red: 0.45, green: 0.66, blue: 0.95, alpha: 1)),
        .adaptable(claro: UIColor(red: 0.05, green: 0.47, blue: 0.40, alpha: 1), oscuro: UIColor(red: 0.35, green: 0.78, blue: 0.66, alpha: 1)),
        .adaptable(claro: UIColor(red: 0.70, green: 0.36, blue: 0.04, alpha: 1), oscuro: UIColor(red: 0.97, green: 0.65, blue: 0.33, alpha: 1)),
        .adaptable(claro: UIColor(red: 0.42, green: 0.27, blue: 0.66, alpha: 1), oscuro: UIColor(red: 0.74, green: 0.62, blue: 0.96, alpha: 1))
    ]

    static func avatar(_ indice: Int) -> Color {
        paletaAvatar[indice % paletaAvatar.count]
    }
}

struct FamiliarAvatar: View {
    let familiar: Familiar
    var tamano: CGFloat = 56

    var body: some View {
        let color = Color.avatar(familiar.indiceColor)
        ZStack {
            Circle()
                .fill(color.opacity(0.16))
            Text(familiar.iniciales)
                .font(.system(size: tamano * 0.36, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(width: tamano, height: tamano)
        .accessibilityHidden(true)
    }
}

struct InfoChip: View {
    let texto: String
    var icono: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icono { Image(systemName: icono) }
            Text(texto)
        }
        .font(.app(.caption))
        .fontWeight(.semibold)
        .foregroundColor(.brandRed)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.tintaSuave))
    }
}

struct SeccionHeader<Accion: View>: View {
    let titulo: String
    @ViewBuilder var accion: Accion

    @Environment(\.dynamicTypeSize) private var tipo

    var body: some View {
        let layout = tipo.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        layout {
            Text(titulo)
                .font(.app(.title3))
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
            if !tipo.isAccessibilitySize { Spacer() }
            accion
        }
    }
}

extension SeccionHeader where Accion == EmptyView {
    init(titulo: String) {
        self.titulo = titulo
        self.accion = EmptyView()
    }
}

struct EnlaceTexto: View {
    let titulo: String
    var icono: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icono { Image(systemName: icono) }
            Text(titulo)
        }
        .font(.app(.subheadline).weight(.bold))
        .foregroundColor(.brandRed)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

struct PersonaTile: View {
    let familiar: Familiar
    let seleccionada: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                FamiliarAvatar(familiar: familiar, tamano: 48)
                Spacer()
                Image(systemName: seleccionada ? "checkmark.circle.fill" : "circle")
                    .icono(.seleccion)
                    .foregroundColor(seleccionada ? .brandRed : Color.iconoSuave)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(familiar.nombre)
                    .font(.app(.headline))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("\(familiar.edad) años · \(familiar.parentesco.titulo)")
                    .font(.app(.footnote))
                    .foregroundColor(.textoSuave)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(width: 156, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(seleccionada ? Color.tintaSuave : Color.superficie)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(seleccionada ? Color.brandRed : Color.borderGray, lineWidth: seleccionada ? 2 : 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(familiar.nombreCompleto), \(familiar.edad) años, \(familiar.parentesco.titulo)")
        .accessibilityAddTraits(seleccionada ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(seleccionada ? "" : "Muestra sus accesos rápidos")
    }
}

struct AgregarPersonaTile: View {
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 48, height: 48)
                Image(systemName: "plus")
                    .icono(.grande)
                    .foregroundColor(.brandRed)
            }
            Text("Agregar")
                .font(.app(.subheadline).weight(.bold))
                .foregroundColor(.brandRed)
        }
        .frame(width: 104)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.borderGray, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        )
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Agregar persona a tu cuidado")
        .accessibilityAddTraits(.isButton)
    }
}

struct FamiliarCard: View {
    let familiar: Familiar

    @Environment(\.dynamicTypeSize) private var tipo

    var body: some View {
        let layout = tipo.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 16))
        layout {
            FamiliarAvatar(familiar: familiar)

            VStack(alignment: .leading, spacing: 6) {
                Text(familiar.nombreCompleto)
                    .font(.app(.headline))
                    .foregroundColor(.primary)
                Text("\(familiar.parentesco.titulo) · \(familiar.edad) años")
                    .font(.app(.subheadline))
                    .foregroundColor(.textoSuave)
                InfoChip(texto: familiar.tipoCuidado.titulo, icono: familiar.tipoCuidado.icono)
            }

            if !tipo.isAccessibilitySize {
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .icono(.flecha)
                    .foregroundColor(Color.iconoSuave)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.superficie)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.borderGray, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

struct AccesoRapidoTile: View {
    let modulo: Modulo
    var compacto = true

    var body: some View {
        Group {
            if compacto {
                VStack(spacing: 10) {
                    icono
                    Text(modulo.titulo)
                        .font(.app(.footnote).weight(.semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2, reservesSpace: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 6)
            } else {
                ModuloFila(modulo: modulo)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.superficie)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.borderGray, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(modulo.titulo)
        .accessibilityHint(modulo.subtitulo)
        .accessibilityAddTraits(.isButton)
    }

    private var icono: some View {
        ZStack {
            Circle()
                .fill(Color.clear)
                .frame(width: 48, height: 48)
            Image(systemName: modulo.icono)
                .icono(.grande)
                .foregroundColor(.brandRed)
        }
    }
}

struct ModuloFila: View {
    let modulo: Modulo

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .frame(width: 44, height: 44)
                Image(systemName: modulo.icono)
                    .icono(.mediano)
                    .foregroundColor(.brandRed)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(modulo.titulo)
                    .font(.app(.headline))
                    .foregroundColor(.primary)
                Text(modulo.subtitulo)
                    .font(.app(.caption))
                    .foregroundColor(.textoSuave)
            }
            Spacer(minLength: 0)
            if !modulo.disponible {
                Text("Pronto")
                    .font(.app(.caption2).weight(.bold))
                    .foregroundColor(.textoSuave)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.rellenoSuave))
            }
            Image(systemName: "chevron.right")
                .icono(.flecha)
                .foregroundColor(Color.iconoSuave)
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

struct EmergenciaCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 52, height: 52)
                Image(systemName: "phone.fill")
                    .icono(.grande)
                    .foregroundColor(.brandRed)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Emergencia")
                    .font(.app(.headline))
                    .foregroundColor(.brandRed)
                Text("Ver contactos y opciones de ayuda")
                    .font(.app(.subheadline))
                    .foregroundColor(.textoSuave)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .icono(.flecha)
                .foregroundColor(.brandRed)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.tintaSuave)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.brandRed.opacity(0.35), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Emergencia")
        .accessibilityHint("Muestra opciones para pedir ayuda. Siempre se pide confirmación antes de llamar.")
        .accessibilityAddTraits(.isButton)
    }
}

struct FormFieldContainer<Content: View>: View {
    let titulo: String
    var obligatorio = false
    var error: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                Text(titulo)
                if obligatorio {
                    Text("*")
                        .foregroundColor(.brandRed)
                        .accessibilityLabel("obligatorio")
                }
            }
            .font(.app(.subheadline))
            .fontWeight(.semibold)

            content

            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.app(.caption))
                    .foregroundColor(.brandRed)
                    .transition(.opacity)
            }
        }
    }
}

struct BrandTextField: View {
    let titulo: String
    let placeholder: String
    @Binding var texto: String
    var obligatorio = false
    var error: String? = nil
    var teclado: UIKeyboardType = .default

    var body: some View {
        FormFieldContainer(titulo: titulo, obligatorio: obligatorio, error: error) {
            TextField(placeholder, text: $texto)
                .keyboardType(teclado)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .fieldBorder(error != nil)
                .accessibilityLabel(titulo)
        }
    }
}

extension View {
    func fieldBorder(_ conError: Bool) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.superficie)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(conError ? Color.brandRed : Color.borderGray, lineWidth: 1)
            )
    }

    func fondoBarraEstado() -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: 0)
                .background(Color.fondoApp, ignoresSafeAreaEdges: .top)
        }
    }

    func tarjetaBorde(radio: CGFloat = 20) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radio)
                    .fill(Color.superficie)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radio)
                    .stroke(Color.borderGray, lineWidth: 1)
            )
    }
}

struct ChipSelector<Opcion: Identifiable & Hashable>: View {
    let opciones: [Opcion]
    @Binding var seleccion: Opcion?
    let titulo: (Opcion) -> String
    var icono: ((Opcion) -> String)? = nil

    @Environment(\.dynamicTypeSize) private var tipo

    private var columnas: [GridItem] {
        [GridItem(.adaptive(minimum: tipo.isAccessibilitySize ? 220 : 100), spacing: 8)]
    }

    var body: some View {
        LazyVGrid(columns: columnas, alignment: .leading, spacing: 8) {
            ForEach(opciones) { opcion in
                let activo = seleccion == opcion
                Button {
                    seleccion = opcion
                } label: {
                    HStack(spacing: 6) {
                        if let icono { Image(systemName: icono(opcion)) }
                        Text(titulo(opcion))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.center)
                    }
                    .font(.app(.subheadline).weight(.semibold))
                    .foregroundColor(activo ? .white : .primary)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(activo ? Color.rojoSolido : Color.superficie)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(activo ? Color.rojoSolido : Color.borderGray, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(activo ? .isSelected : [])
            }
        }
        .vibracion(.selection, trigger: seleccion)
    }
}
