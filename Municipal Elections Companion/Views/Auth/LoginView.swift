//
//  LoginView.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher & Gemini
//

import SwiftUI

struct LoginView: View {
    @Environment(SessionViewModel.self) private var session
    @State private var viewModel = LoginViewModel()
    @State private var showRegisterSheet = false

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.tint)
                        Text("Municipal Elections Companion")
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                        Text("Log in to browse your municipality's candidates and build your selections.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                if let notice = session.notice {
                    Section {
                        Label(notice, systemImage: "clock.badge.exclamationmark")
                            .foregroundStyle(.orange)
                    }
                }

                Section(header: Text("Account Credentials")) {
                    TextField("Email", text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .autocorrectionDisabled()

                    SecureField("Password (min 6 characters)", text: $viewModel.password)
                        .textContentType(.password)
                        .onSubmit { Task { await viewModel.login(using: session) } }
                }

                Section {
                    Button {
                        Task { await viewModel.login(using: session) }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Log In")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isLoading)
                }

                Section {
                    Button("Don't have an account? Register") {
                        showRegisterSheet = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Welcome")
            .sheet(isPresented: $showRegisterSheet) {
                RegisterView { registeredEmail in
                    viewModel.email = registeredEmail
                }
            }
            .alert(
                "Login Failed",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(SessionViewModel())
}
