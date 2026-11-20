//
//  SelectionsViewModel.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation
import Observation

/// Result of a Firestore write, for the screen that started it to present.
enum SelectionWriteOutcome: Equatable {
    case success
    case failure(String)
    /// The session ended (token or Firebase login expired); the app is returning to login.
    case sessionEnded

    var errorMessage: String? {
        if case .failure(let message) = self { return message }
        return nil
    }
}

/// The user's candidate selections for the current municipality, stored in Firestore.
/// Shared app-wide so the directory, detail, selections and profile screens always agree.
@MainActor
@Observable
final class SelectionsViewModel {
    /// Only the current city's selections. Cleared as soon as the city changes.
    private(set) var selections: [CandidateSelection] = []
    /// Offices for the current city, used for seat limits and ordering.
    private(set) var offices: [Position] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var lastSync: Date?
    /// Candidate IDs with a write in progress, so their buttons can show progress.
    private(set) var pendingCandidateIds: Set<Int> = []
    /// Error from the last load, shown on the selections screen.
    var errorMessage: String?

    private var loadedMunicipalityId: Int?
    private let services: AppServices
    private let session: SessionViewModel

    init(session: SessionViewModel, services: AppServices? = nil) {
        self.session = session
        self.services = services ?? .shared
    }

    // MARK: - Queries

    func selection(for candidateId: Int) -> CandidateSelection? {
        selections.first { $0.candidateId == candidateId }
    }

    func chosenCount(forPosition positionId: Int) -> Int {
        selections.filter { $0.positionId == positionId }.count
    }

    func seatLimit(forPosition positionId: Int, fallback: Int? = nil) -> Int? {
        offices.first { $0.positionId == positionId }?.seatsAvailable ?? fallback
    }

    /// Selections grouped by office, in the city's office order.
    var groupedByOffice: [(office: String, positionId: Int, items: [CandidateSelection])] {
        let order = Dictionary(uniqueKeysWithValues: offices.enumerated().map { ($1.positionId, $0) })
        return Dictionary(grouping: selections, by: \.positionId)
            .map { positionId, items in
                (office: items.first?.positionName ?? "Candidate",
                 positionId: positionId,
                 items: items.sorted { $0.candidateName < $1.candidateName })
            }
            .sorted { (order[$0.positionId] ?? .max, $0.positionId) < (order[$1.positionId] ?? .max, $1.positionId) }
    }

    // MARK: - Read

    /// Loads selections for the session's current city. Selections from a previous
    /// city are cleared immediately, before the network round trip.
    func load() async {
        guard !session.email.isEmpty, let municipality = session.municipality else {
            reset()
            return
        }
        if loadedMunicipalityId != municipality.municipalityId {
            selections = []
            offices = []
            hasLoaded = false
            loadedMunicipalityId = municipality.municipalityId
        }

        isLoading = true
        defer { isLoading = false }
        do {
            async let fetchedOffices = services.elections.fetchOffices(city: municipality.name)
            let fetched = try await services.selections.fetchSelections(
                userEmail: session.email,
                municipalityName: municipality.name
            )
            // A fast city switch may have happened while waiting; drop stale results.
            guard loadedMunicipalityId == municipality.municipalityId else { return }
            selections = fetched.filter { $0.municipalityId == municipality.municipalityId }
            offices = (try? await fetchedOffices) ?? offices
            hasLoaded = true
            markSynced()
        } catch {
            errorMessage = session.message(for: error)
        }
    }

    func reset() {
        selections = []
        offices = []
        hasLoaded = false
        lastSync = nil
        loadedMunicipalityId = nil
        errorMessage = nil
    }

    // MARK: - Create

    /// Quick local check before opening the editor, so the user learns about a full office
    /// or a duplicate before typing notes. `add` re-validates against the server.
    func problemAdding(_ candidate: Candidate) -> SelectionValidationError? {
        guard let municipality = session.municipality else { return .noCitySelected }
        guard candidate.municipalityId == municipality.municipalityId else {
            return .wrongMunicipality(candidateCity: candidate.municipalityName ?? "another city", currentCity: municipality.name)
        }
        if selection(for: candidate.candidateId) != nil {
            return .duplicate(candidateName: candidate.name)
        }
        if let limit = seatLimit(forPosition: candidate.positionId, fallback: candidate.seatsAvailable),
           chosenCount(forPosition: candidate.positionId) >= limit {
            return .seatLimitReached(limit: limit, positionName: candidate.positionName ?? "candidate", city: municipality.name)
        }
        return nil
    }

    /// Validates and saves a new selection.
    func add(_ candidate: Candidate, notes: String) async -> SelectionWriteOutcome {
        guard let municipality = session.municipality else {
            return .failure(SelectionValidationError.noCitySelected.errorDescription ?? "")
        }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let selection = CandidateSelection(
            candidate: candidate,
            userEmail: session.email,
            municipality: municipality,
            notes: trimmedNotes
        )

        pendingCandidateIds.insert(candidate.candidateId)
        defer { pendingCandidateIds.remove(candidate.candidateId) }

        do {
            // Re-read from the server so the duplicate and seat checks use current data,
            // not a list that may be stale (e.g. changed on another device).
            let latest = try await services.selections.fetchSelections(
                userEmail: session.email,
                municipalityName: municipality.name
            )
            if offices.isEmpty {
                offices = (try? await services.elections.fetchOffices(city: municipality.name)) ?? []
            }
            guard let limit = seatLimit(forPosition: candidate.positionId, fallback: candidate.seatsAvailable) else {
                return .failure("Couldn't determine how many \(selection.positionName) seats are available. Please try again.")
            }
            try SelectionValidator.validateNew(selection, existing: latest, seatLimit: limit, currentCity: municipality)

            try await services.selections.create(selection)
            selections = latest.filter { $0.municipalityId == municipality.municipalityId } + [selection]
            markSynced()
            return .success
        } catch {
            return outcome(for: error)
        }
    }

    // MARK: - Update

    func updateNotes(for selection: CandidateSelection, to notes: String) async -> SelectionWriteOutcome {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingCandidateIds.insert(selection.candidateId)
        defer { pendingCandidateIds.remove(selection.candidateId) }

        do {
            try SelectionValidator.validateNotes(trimmedNotes)
            let modified = Date.now
            try await services.selections.updateNotes(selectionId: selection.id, notes: trimmedNotes, modified: modified)
            if let index = selections.firstIndex(where: { $0.id == selection.id }) {
                selections[index].notes = trimmedNotes
                selections[index].dateModified = modified
            }
            markSynced()
            return .success
        } catch {
            return outcome(for: error)
        }
    }

    // MARK: - Delete

    func delete(_ selection: CandidateSelection) async -> SelectionWriteOutcome {
        pendingCandidateIds.insert(selection.candidateId)
        defer { pendingCandidateIds.remove(selection.candidateId) }

        do {
            try await services.selections.delete(selectionId: selection.id)
            selections.removeAll { $0.id == selection.id }
            markSynced()
            return .success
        } catch {
            return outcome(for: error)
        }
    }

    private func outcome(for error: Error) -> SelectionWriteOutcome {
        guard let message = session.message(for: error) else { return .sessionEnded }
        return .failure(message)
    }

    private func markSynced() {
        let now = Date.now
        lastSync = now
        session.recordSync(at: now)
    }
}
