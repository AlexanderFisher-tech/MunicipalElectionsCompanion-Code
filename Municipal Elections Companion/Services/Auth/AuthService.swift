//
//  AuthService.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation

/// Why a saved session could not be restored at launch.
enum SessionRestoreResult {
    case restored(StoredSession)
    case none
    case expired
}

/// Coordinates the two identity providers: the Web API (JWT, system of record)
/// and Firebase Auth (identity for Firestore rules), plus Keychain storage.
protocol AuthServiceProtocol {
    func register(name: String, email: String, password: String) async throws
    func login(email: String, password: String) async throws -> StoredSession
    func restoreSession() -> SessionRestoreResult
    func logout()
}

final class AuthService: AuthServiceProtocol {
    private let api: AuthAPIServiceProtocol
    private let firebase: FirebaseAuthServiceProtocol
    private let store: SessionStoreProtocol

    init(api: AuthAPIServiceProtocol, firebase: FirebaseAuthServiceProtocol, store: SessionStoreProtocol) {
        self.api = api
        self.firebase = firebase
        self.store = store
    }

    func register(name: String, email: String, password: String) async throws {
        let email = Validation.normalizedEmail(email)
        try await api.register(RegisterRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email,
            password: password
        ))
        // Mirror the account in Firebase so Firestore rules recognise the user.
        // The user still logs in afterwards, so sign straight back out.
        try await firebase.createUserIfNeeded(email: email, password: password)
        firebase.signOut()
    }

    func login(email: String, password: String) async throws -> StoredSession {
        let email = Validation.normalizedEmail(email)
        let response = try await api.login(LoginRequest(email: email, password: password))
        try await firebase.signInOrCreate(email: email, password: password)

        let session = StoredSession(
            token: response.token,
            email: Validation.normalizedEmail(response.email ?? email),
            name: response.name ?? ""
        )
        do {
            try store.save(session)
        } catch {
            firebase.signOut()
            throw error
        }
        return session
    }

    func restoreSession() -> SessionRestoreResult {
        guard let session = store.load() else {
            firebase.signOut()
            return .none
        }
        // Both halves must still be valid: an unexpired JWT and the matching Firebase user.
        guard !JWTDecoder.isExpired(session.token),
              firebase.currentUserEmail == session.email
        else {
            logout()
            return .expired
        }
        return .restored(session)
    }

    func logout() {
        firebase.signOut()
        store.clear()
    }
}
