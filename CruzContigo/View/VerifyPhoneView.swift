//
//  VerifyPhoneView.swift
//  CruzContigo
//
//  Created by Ricardo Gómez on 20/10/26.
//

import SwiftUI

struct VerifyPhoneView: View {
    var onVerificado: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var code: String = ""
    @State private var codigoReenviado = false

    private let codeLength = 6

    var body: some View {
        VStack(spacing: 0) {
            header
            BrandLogoView()
                .padding(.top, 24)
            titleSection
                .padding(.top, 28)
            codeSection
                .padding(.top, 28)
            resendSection
                .padding(.top, 24)

            Spacer()

            footer
                .padding(.bottom, 32)
        }
    }

    // MARK: - Secciones

    private var header: some View {
        HStack {
            BrandBackButton { dismiss() }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PASO 1 DE 2")
                .font(.app(.caption))
                .fontWeight(.bold)
                .foregroundColor(.brandRed)

            Text("Verifica tu número")
                .font(.app(.largeTitle).weight(.bold))

            (Text("Te enviamos un código de 6 dígitos al ")
                .foregroundColor(.textoSuave)
            + Text("+52 81 •••• 4567")
                .fontWeight(.bold)
                .foregroundColor(.primary))
                .font(.app(.body))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var codeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingresa el código para continuar.")
                .font(.app(.subheadline))
                .foregroundColor(.textoSuave)

            CodeInputView(code: $code, length: codeLength)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var resendSection: some View {
        VStack(spacing: 4) {
            Text("¿No recibiste el código?")
                .font(.app(.subheadline))
                .foregroundColor(.textoSuave)
            Button {
                code = ""
                codigoReenviado = true
            } label: {
                Text(codigoReenviado ? "Código reenviado" : "Reenviar código")
                    .font(.app(.subheadline))
                    .fontWeight(.bold)
                    .foregroundColor(.brandRed)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 16) {
            PrimaryButton(title: "Verificar y continuar", action: onVerificado)
                .disabled(code.count < codeLength)
                .opacity(code.count < codeLength ? 0.5 : 1)

            Button { dismiss() } label: {
                Text("Cambiar número telefónico")
                    .font(.app(.subheadline))
                    .fontWeight(.bold)
                    .foregroundColor(.brandRed)
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.app(.caption))
                Text("Tu información se mantiene protegida.")
                    .font(.app(.footnote))
            }
            .foregroundColor(.textoSuave)
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    VerifyPhoneView()
}
