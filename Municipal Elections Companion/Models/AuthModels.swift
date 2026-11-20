//
//  AuthModels.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher & Gemini
//

import Foundation

// Sent to POST /api/auth/register
struct RegisterRequest: Codable {
    let name: String
    let email: String
    let password: String
}

// Sent to POST /api/auth/login
struct LoginRequest: Codable {
    let email: String
    let password: String
}

// Received from POST /api/auth/login
struct AuthResponse: Codable {
    let token: String
    let name: String?
    let email: String?
}

// Used to read { "message": "..." } when the API returns an error or success message
struct APIMessageResponse: Codable {
    let message: String?
}

// The logged-in user's session. Persisted as a whole in the Keychain (never UserDefaults).
struct StoredSession: Codable, Equatable {
    let token: String
    /// Always lowercased so it matches Firebase Auth and Firestore identifiers.
    let email: String
    let name: String
}
