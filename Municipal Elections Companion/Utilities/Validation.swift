//
//  Validation.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher & Gemini
//

import Foundation

struct Validation {
    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        // Basic RFC-compliant email regex
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        return trimmed.range(of: emailRegex, options: .regularExpression) != nil
    }

    static func isValidPassword(_ password: String, minLength: Int = 6) -> Bool {
        return password.count >= minLength
    }

    static func isValidName(_ name: String) -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Trims whitespace and lowercases, so the same address always maps to the same user.
    static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

// MARK: - Candidate selection rules

enum SelectionValidationError: LocalizedError, Equatable {
    case notLoggedIn
    case noCitySelected
    case wrongMunicipality(candidateCity: String, currentCity: String)
    case duplicate(candidateName: String)
    case notesTooLong(count: Int)
    case seatLimitReached(limit: Int, positionName: String, city: String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "Please log in to manage your candidate selections."
        case .noCitySelected:
            return "Choose your municipality on the Profile screen first."
        case .wrongMunicipality(let candidateCity, let currentCity):
            return "This candidate is running in \(candidateCity), but your municipality is \(currentCity)."
        case .duplicate(let candidateName):
            return "\(candidateName) is already in your selections."
        case .notesTooLong(let count):
            return "Notes can be at most \(CandidateSelection.maxNotesLength) characters (currently \(count))."
        case .seatLimitReached(let limit, let positionName, let city):
            let office = limit == 1 ? positionName : "\(positionName)s"
            return "You can only choose \(limit) \(office) in \(city)."
        }
    }
}

enum SelectionValidator {
    /// Checks every rule that must hold before a new selection is written to Firestore.
    ///
    /// - Parameters:
    ///   - existing: the user's current selections **in the current city**.
    ///   - seatLimit: `seatsAvailable` for the candidate's office in that city.
    static func validateNew(
        _ selection: CandidateSelection,
        existing: [CandidateSelection],
        seatLimit: Int,
        currentCity: Municipality
    ) throws(SelectionValidationError) {
        guard !selection.userEmail.isEmpty else { throw .notLoggedIn }
        guard selection.municipalityId == currentCity.municipalityId else {
            throw .wrongMunicipality(candidateCity: selection.municipalityName, currentCity: currentCity.name)
        }
        try validateNotes(selection.notes)
        guard !existing.contains(where: { $0.candidateId == selection.candidateId }) else {
            throw .duplicate(candidateName: selection.candidateName)
        }
        let alreadyChosen = existing.filter { $0.positionId == selection.positionId }.count
        guard alreadyChosen < seatLimit else {
            throw .seatLimitReached(limit: seatLimit, positionName: selection.positionName, city: currentCity.name)
        }
    }

    static func validateNotes(_ notes: String) throws(SelectionValidationError) {
        guard notes.count <= CandidateSelection.maxNotesLength else {
            throw .notesTooLong(count: notes.count)
        }
    }
}
