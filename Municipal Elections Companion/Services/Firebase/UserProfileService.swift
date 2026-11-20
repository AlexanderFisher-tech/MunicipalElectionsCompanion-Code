//
//  UserProfileService.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation
import FirebaseFirestore

/// Reads and writes the user's profile (selected municipality and last sync) in `UserProfiles/{email}`.
protocol UserProfileServiceProtocol {
    func fetchProfile(email: String) async throws -> UserProfile?
    func saveMunicipality(_ municipality: Municipality, email: String) async throws -> UserProfile
    func updateLastSync(_ date: Date, email: String) async throws
}

final class UserProfileService: UserProfileServiceProtocol {
    static let collectionName = "UserProfiles"

    private func document(for email: String) -> DocumentReference {
        Firestore.firestore().collection(Self.collectionName).document(email.lowercased())
    }

    func fetchProfile(email: String) async throws -> UserProfile? {
        let snapshot = try await document(for: email).getDocument(source: .server)
        guard snapshot.exists else { return nil }
        do {
            return try snapshot.data(as: UserProfile.self)
        } catch {
            print("Invalid UserProfile document: \(error)")
            throw FirestoreDataError.invalidDocument
        }
    }

    func saveMunicipality(_ municipality: Municipality, email: String) async throws -> UserProfile {
        let profile = UserProfile(
            email: email.lowercased(),
            city: municipality.name,
            municipalityId: municipality.municipalityId,
            lastSync: .now
        )
        let data = try Firestore.Encoder().encode(profile)
        try await document(for: email).setData(data, merge: true)
        return profile
    }

    func updateLastSync(_ date: Date, email: String) async throws {
        try await document(for: email).setData(["lastSync": Timestamp(date: date)], merge: true)
    }
}
