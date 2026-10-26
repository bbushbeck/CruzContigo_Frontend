//
//  OnBoardingRoleView.swift
//  CruzContigo
//
//  Created by Ricardo Gómez on 20/10/26.
//

import SwiftUI

enum UserRole: String {
    case cuidador
    case recibeCuidados
}

struct OnboardingRoleView: View {
    var onContinuar: () -> Void = {}

    @AppStorage("rolUsuario") private var rolGuardado: String = UserRole.cuidador.rawValue
    @State private var selectedRole: UserRole? = .cuidador

    var body: some View {
        VStack(spacing: 0) {
            CompactBrandHeader()
                .padding(.top, 12)

            ProgressBarView(progress: 0.5)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            titleSection
                .padding(.top, 24)

            roleCards
                .padding(.top, 32)

            Spacer()

            footer
                .padding(.bottom, 32)
        }
    }

    // MARK: - Secciones

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PASO 2 DE 2")
                .font(.app(.caption))
                .fontWeight(.bold)
                .foregroundColor(.brandRed)

            Text("¿Cómo usarás\nCruzContigo?")
                .font(.app(.largeTitle).weight(.bold))

            Text("Elige la opción que mejor te describa.")
                .font(.app(.body))
                .foregroundColor(.textoSuave)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var roleCards: some View {
        VStack(spacing: 16) {
            RoleCard(
                title: "Soy cuidador",
                subtitle: "Quiero cuidar a un familiar\no a otra persona.",
                icon: "person.2",
                isSelected: selectedRole == .cuidador
            ) {
                selectedRole = .cuidador
            }

            RoleCard(
                title: "Recibo cuidados",
                subtitle: "Quiero consultar mi salud\ny recibir apoyo.",
                icon: "heart",
                isSelected: selectedRole == .recibeCuidados
            ) {
                selectedRole = .recibeCuidados
            }
        }
        .padding(.horizontal, 24)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            PrimaryButton(title: "Continuar") {
                rolGuardado = (selectedRole ?? .cuidador).rawValue
                onContinuar()
            }
            Text("Podrás cambiar tu perfil más adelante.")
                .font(.app(.footnote))
                .foregroundColor(.textoSuave)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - header logo compacto

struct CompactBrandHeader: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("Cruz").font(.app(.title2)).fontWeight(.bold)
            + Text("Contigo")
                .font(.app(.title2)).fontWeight(.bold)
                .foregroundColor(.brandRed)

            Text("Cuidar es estar juntos")
                .font(.app(.footnote))
                .foregroundColor(.textoSuave)
        }
    }
}

// MARK: - Barra de prograeso

struct ProgressBarView: View {
    /// Value between 0 and 1.
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemFill))
                    .frame(height: 4)
                Capsule()
                    .fill(Color.brandRed)
                    .frame(width: geo.size.width * progress, height: 4)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Roles

struct RoleCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 16) {
                    iconView

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.app(.headline))
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.app(.subheadline))
                            .foregroundColor(.textoSuave)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                }
                .padding(20)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .icono(.seleccion)
                    .foregroundColor(isSelected ? .brandRed : Color.iconoSuave)
                    .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.tintaSuave : Color.superficie)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.brandRed : Color.borderGray, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(Color.clear)
                .frame(width: 56, height: 56)
            Image(systemName: icon)
                .icono(.grande)
                .foregroundColor(.brandRed)
        }
    }
}

#Preview {
    OnboardingRoleView()
}
