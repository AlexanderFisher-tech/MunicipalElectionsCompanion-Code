//
//  RegisterView.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import SwiftUI

struct RegisterView: View {
    // Lets us close/slide down this sheet to go back to LoginView
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionViewModel.self) private var session
    @State private var viewModel = RegisterViewModel()

    /// Passes the new account's email back so the login form can be prefilled.
    var onRegistered: (String) -> Void = { _ in }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    TextField("Full Name", text: $viewModel.name)
                        .textContentType(.name)

                    TextField("Email", text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)

                    SecureField("Password (min 6 characters)", text: $viewModel.password)
                        .textContentType(.password)
                } header: {
                    Text("Create Account")
                } footer: {
                    // Hints live in the footer so rows aren't inserted next to the fields while typing.
                    let hints = [viewModel.nameHint, viewModel.emailHint, viewModel.passwordHint].compactMap { $0 }
                    if !hints.isEmpty {
                        Text(hints.joined(separator: "\n"))
                            .foregroundStyle(.red)
                    }
                }
                .autocorrectionDisabled()  // Applies to all fields inside this Section

                Section {
                    Button {
                        Task { await viewModel.register(using: session) }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Account")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isLoading)
                }

                Section {
                    Button("Already have an account? Log In") {
                        dismiss()  // Closes the sheet back to LoginView
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Register")
            .alert(
                "Registration Failed",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Account Created!", isPresented: .constant(viewModel.didRegister)) {
                Button("Go to Login") {
                    onRegistered(Validation.normalizedEmail(viewModel.email))
                    dismiss()
                }
            } message: {
                Text("Your account has been created. Please log in.")
            }
        }
    }
}

#Preview {
    RegisterView()
        .environment(SessionViewModel())
}
