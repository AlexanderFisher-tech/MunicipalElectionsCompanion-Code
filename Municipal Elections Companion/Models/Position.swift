//
//  Position.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation

struct Position: Codable, Hashable {
    let positionId: Int
    let name: String
    /// `var` so `ElectionService` can apply the assignment's seat limits (see `SeatLimitOverrides`).
    var seatsAvailable: Int
    let municipalityId: Int
    let municipalityName: String?
}

extension Position: Identifiable {
    var id: Int { positionId }
}
