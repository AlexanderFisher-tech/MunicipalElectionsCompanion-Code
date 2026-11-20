//
//  FirebaseAuthService.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation
import FirebaseAuth

/// Firebase Auth is used only so Firestore security rules know who the user is.
/// The Web API stays the system of record; Firebase uses the same email and password.
protocol FirebaseAuthServiceProtocol {
    var currentUserEmail: String? { get }
    /// Signs in, creating the Firebase user first if this account predates Assignment 2.
    func signInOrCreate(email: String, password: String) async throws
    /// Creates the Firebase user after API registration. An existing user is not an error.
    func createUserIfNeeded(email: String, password: String) async throws
    func signOut()
}

final class FirebaseAuthService: FirebaseAuthServiceProtocol {
    private var auth: Auth { Auth.auth() }

    var currentUserEmail: String? {
        auth.currentUser?.email?.lowercased()
    }

    func signInOrCreate(email: String, password: String) async throws {
        do {
            try await auth.signIn(withEmail: email, password: password)
        } catch let error as NSError where Self.mayMeanUserMissing(error) {
            // With email-enumeration protection, a missing user is reported as
            // invalidCredential, so try to create the account before giving up.
            do {
                try await auth.createUser(withEmail: email, password: password)
            } catch let createError as NSError
                where AuthErrorCode(rawValue: createError.code) == .emailAlreadyInUse {
                // The user does exist, so the Firebase password differs from the API one.
                throw FirebaseAuthSyncError.passwordMismatch
            }
        }
    }

    func createUserIfNeeded(email: String, password: String) async throws {
        do {
            try await auth.createUser(withEmail: email, password: password)
        } catch let error as NSError where AuthErrorCode(rawValue: error.code) == .emailAlreadyInUse {
            return
        }
    }

    func signOut() {
        try? auth.signOut()
    }

    private static func mayMeanUserMissing(_ error: NSError) -> Bool {
        guard error.domain == AuthErrorDomain else { return false }
        switch AuthErrorCode(rawValue: error.code) {
        case .userNotFound, .invalidCredential, .wrongPassword:
            return true
        default:
            return false
        }
    }
}

enum FirebaseAuthSyncError: LocalizedError {
    case passwordMismatch

    var errorDescription: String? {
        "Your account exists, but its cloud sync credentials don't match. Contact support to reset your Firebase account."
    }
}
