//
//  AuthAPIService.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher & Gemini
//

import Foundation

/// Registration and login against the Web API, which remains the system of record for accounts.
protocol AuthAPIServiceProtocol {
    func register(_ request: RegisterRequest) async throws
    func login(_ request: LoginRequest) async throws -> AuthResponse
}

final class AuthAPIService: AuthAPIServiceProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    // POST /api/auth/register
    func register(_ request: RegisterRequest) async throws {
        try await client.post("api/auth/register", body: request, authorized: false)
    }

    // POST /api/auth/login
    func login(_ request: LoginRequest) async throws -> AuthResponse {
        try await client.post("api/auth/login", body: request, authorized: false)
    }
}
