//
//  Candidate.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation

struct Candidate: Codable, Hashable {
    let candidateId: Int
    let name: String
    let biography: String?
    let photoUrl: String?
    let website: String?
    let email: String?
    let positionId: Int
    let positionName: String?
    /// Selection limit for this candidate's office in this city (e.g. Mayor = 1).
    var seatsAvailable: Int?
    let municipalityId: Int
    let municipalityName: String?
}

extension Candidate: Identifiable {
    var id: Int { candidateId }
}

extension Candidate {
    var photoURL: URL? { photoUrl.flatMap(URL.init(string:)) }

    var websiteURL: URL? {
        guard let website, !website.isEmpty else { return nil }
        return URL(string: website)
    }
}
