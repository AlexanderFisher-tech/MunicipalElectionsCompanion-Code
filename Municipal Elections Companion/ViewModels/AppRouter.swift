//
//  AppRouter.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation
import Observation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case home, candidates, selections, profile

    var id: Self { self }

    var title: String {
        switch self {
        case .home: return "Election"
        case .candidates: return "Candidates"
        case .selections: return "My Selections"
        case .profile: return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "building.columns"
        case .candidates: return "person.3"
        case .selections: return "checkmark.seal"
        case .profile: return "person.crop.circle"
        }
    }
}

/// A navigation destination for a candidate. `preview` lets the detail screen show
/// something immediately while it refreshes from the API.
struct CandidateRoute: Hashable {
    let candidateId: Int
    var preview: Candidate?
}

/// Navigation state, held above the iPhone/iPad layouts so it survives rotation
/// and size-class changes (e.g. iPad multitasking).
@MainActor
@Observable
final class AppRouter {
    var section: AppSection = .home
    var candidatesPath: [CandidateRoute] = []
    var selectionsPath: [CandidateRoute] = []

    /// Called when the city changes or the user logs out: old routes may point at
    /// another municipality's candidates.
    func reset() {
        candidatesPath = []
        selectionsPath = []
    }
}
