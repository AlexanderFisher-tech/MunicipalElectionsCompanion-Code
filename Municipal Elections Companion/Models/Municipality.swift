//
//  Municipality.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher & Gemini
//

import Foundation

struct Municipality: Codable, Hashable {
    let municipalityId: Int
    let name: String
    let province: String
    /// The API sends this without a time zone ("2026-10-17T00:00:00"); see `JSONDecoder.api`.
    let electionDate: Date?
    let description: String?
    let logoUrl: String?
}

extension Municipality: Identifiable {
    /*
     Need to create another ID property to satisfy the Identifiable protocol
     which requires an attribute exactly named as `id`
     */
    var id: Int { municipalityId }
}

extension Municipality {
    var logoURL: URL? { logoUrl.flatMap(URL.init(string:)) }
}
