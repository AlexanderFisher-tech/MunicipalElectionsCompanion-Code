//
//  CandidateSelection.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation

/// A candidate the user has saved, stored in the Firestore `CandidateSelections` collection.
///
/// The document ID is deterministic (`"\(userEmail)_\(candidateId)"`), so the same user can
/// never have two documents for the same candidate.
struct CandidateSelection: Codable, Hashable, Identifiable {
    static let maxNotesLength = 500

    let id: String
    let userEmail: String
    let candidateId: Int
    let candidateName: String
    let positionId: Int
    let positionName: String
    let municipalityId: Int
    /// The city name exactly as the API returns it, used to filter by the selected city.
    let municipalityName: String
    let photoUrl: String?
    var notes: String
    let dateCreated: Date
    var dateModified: Date

    static func documentId(userEmail: String, candidateId: Int) -> String {
        "\(userEmail.lowercased())_\(candidateId)"
    }
}

extension CandidateSelection {
    var photoURL: URL? { photoUrl.flatMap(URL.init(string:)) }

    var wasEdited: Bool { dateModified.timeIntervalSince(dateCreated) > 1 }

    /// Builds a new selection for `candidate`, owned by `userEmail`, in `municipality`.
    init(candidate: Candidate, userEmail: String, municipality: Municipality, notes: String, now: Date = .now) {
        let email = userEmail.lowercased()
        self.init(
            id: Self.documentId(userEmail: email, candidateId: candidate.candidateId),
            userEmail: email,
            candidateId: candidate.candidateId,
            candidateName: candidate.name,
            positionId: candidate.positionId,
            positionName: candidate.positionName ?? "Candidate",
            municipalityId: municipality.municipalityId,
            municipalityName: municipality.name,
            photoUrl: candidate.photoUrl,
            notes: notes,
            dateCreated: now,
            dateModified: now
        )
    }
}
