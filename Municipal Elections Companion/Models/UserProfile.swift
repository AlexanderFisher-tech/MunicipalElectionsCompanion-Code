//
//  UserProfile.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation

/// The user's profile in the Firestore `UserProfiles` collection, keyed by lowercased email.
/// Stores the municipality the user chose so it follows them across devices.
struct UserProfile: Codable, Equatable {
    let email: String
    var city: String
    var municipalityId: Int
    var lastSync: Date?
}
