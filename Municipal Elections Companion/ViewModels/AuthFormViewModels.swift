//
//  AuthFormViewModels.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher & Gemini
//

import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    private(set) var isLoading = false
    var errorMessage: String?

    // Form validation (prevents invalid network calls)
    var isFormValid: Bool {
        Validation.isValidEmail(email) && Validation.isValidPassword(password)
    }

    func login(using session: SessionViewModel) async {
        guard isFormValid, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await session.login(email: email, password: password)
            password = ""
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}

@MainActor
@Observable
final class RegisterViewModel {
    var name = ""
    var email = ""
    var password = ""
    private(set) var isLoading = false
    private(set) var didRegister = false
    var errorMessage: String?

    // Name not empty + valid Email + valid Password (>= 6 chars)
    var isFormValid: Bool {
        Validation.isValidName(name) && Validation.isValidEmail(email) && Validation.isValidPassword(password)
    }

    var nameHint: String? {
        name.isEmpty || Validation.isValidName(name) ? nil : "Name is required."
    }

    var emailHint: String? {
        email.isEmpty || Validation.isValidEmail(email) ? nil : "Enter a valid email address."
    }

    var passwordHint: String? {
        password.isEmpty || Validation.isValidPassword(password) ? nil : "Password must be at least 6 characters."
    }

    func register(using session: SessionViewModel) async {
        guard isFormValid, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await session.register(name: name, email: email, password: password)
            didRegister = true
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}
