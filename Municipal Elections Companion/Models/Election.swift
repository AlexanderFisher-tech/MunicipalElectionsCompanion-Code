//
//  Election.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation

// Received from GET /api/elections?city={name}
struct Election: Codable, Hashable {
    let municipalityId: Int
    let municipalityName: String
    let province: String?
    let electionDate: Date?
    let description: String?
    let logoUrl: String?
    let offices: [Position]
    let candidateCount: Int?
}

extension Election {
    var logoURL: URL? { logoUrl.flatMap(URL.init(string:)) }
}
