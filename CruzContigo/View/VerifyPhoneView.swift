//
//  VerifyPhoneView.swift
//  CruzContigo
//
//  Created by Ricardo Gómez on 20/10/26.
//

import SwiftUI

struct VerifyPhoneView: View {
    @Bindable var viewModel: AuthViewModel
    var onVerificado: () -> Void = {}

    @FocusState private var telefonoEnfocado: Bool
    private let codeLength = 6

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BrandLogoView()
                    .padding(.top, 24)
                titleSection
                    .padding(.top, 28)
                inputSection
                    .padding(.top, 28)
                if viewModel.esperandoCodigo {
                    resendSection
                        .padding(.top, 24)
                }
                if let mensajeError = viewModel.mensajeError {
                    Text(mensajeError)
                        .font(.app(.footnote))
                        .foregroundStyle(Color.brandRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                }
                footer
                    .padding(.top, 32)
                    .padding(.bottom, 32)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PASO 1 DE 2")
                .font(.app(.caption))
                .fontWeight(.bold)
                .foregroundColor(.brandRed)

            Text(viewModel.esperandoCodigo ? "Verifica tu número" : "Ingresa tu número")
                .font(.app(.largeTitle).weight(.bold))

            Group {
                if viewModel.esperandoCodigo {
                    Text("Te enviamos un código de 6 dígitos al ")
                        .foregroundColor(.textoSuave)
                    + Text(viewModel.telefono)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                } else {
                    Text("Te enviaremos un código para confirmar tu identidad.")
                        .foregroundColor(.textoSuave)
                }
            }
            .font(.app(.body))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.esperandoCodigo {
                Text("Ingresa el código para continuar.")
                    .font(.app(.subheadline))
                    .foregroundColor(.textoSuave)
                CodeInputView(code: $viewModel.codigo, length: codeLength)
            } else {
                Text("Número telefónico")
                    .font(.app(.subheadline))
                    .foregroundColor(.textoSuave)
                TextField("+52 81 1234 5678", text: $viewModel.telefono)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($telefonoEnfocado)
                    .font(.app(.body))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 56)
                    .background(Color.superficie)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(telefonoEnfocado ? Color.brandRed : Color.borderGray, lineWidth: 2)
                    )
                    .cornerRadius(14)
                    .accessibilityLabel("Número telefónico")
            }
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
                Task { await viewModel.solicitarCodigo() }
            } label: {
                Text(viewModel.cargando ? "Reenviando…" : "Reenviar código")
                    .font(.app(.subheadline))
                    .fontWeight(.bold)
                    .foregroundColor(.brandRed)
            }
            .disabled(viewModel.cargando)
        }
    }

    private var footer: some View {
        VStack(spacing: 16) {
            PrimaryButton(
                title: viewModel.cargando
                    ? "Un momento…"
                    : (viewModel.esperandoCodigo ? "Verificar y continuar" : "Enviar código")
            ) {
                Task {
                    if viewModel.esperandoCodigo {
                        await viewModel.verificarCodigo()
                        if viewModel.estaAutenticado { onVerificado() }
                    } else {
                        await viewModel.solicitarCodigo()
                    }
                }
            }
            .disabled(viewModel.esperandoCodigo ? !viewModel.puedeVerificar : !viewModel.puedeSolicitarCodigo)
            .opacity((viewModel.esperandoCodigo ? viewModel.puedeVerificar : viewModel.puedeSolicitarCodigo) ? 1 : 0.5)

            if viewModel.esperandoCodigo {
                Button { viewModel.cambiarNumero() } label: {
                    Text("Cambiar número telefónico")
                        .font(.app(.subheadline))
                        .fontWeight(.bold)
                        .foregroundColor(.brandRed)
                }
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
    VerifyPhoneView(viewModel: AuthViewModel())
}
