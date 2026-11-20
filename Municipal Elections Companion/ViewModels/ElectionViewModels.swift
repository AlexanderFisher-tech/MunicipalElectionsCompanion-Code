//
//  ElectionViewModels.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation
import Observation

/// The list of municipalities, used only by the city picker.
@MainActor
@Observable
final class CitySelectionViewModel {
    private(set) var municipalities: [Municipality] = []
    private(set) var isLoading = false
    private(set) var savingId: Int?
    var errorMessage: String?

    private let services: AppServices

    init(services: AppServices? = nil) {
        self.services = services ?? .shared
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            municipalities = try await services.elections.fetchMunicipalities()
                .sorted { $0.name < $1.name }
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    /// Saves the choice to Firestore. Returns true on success.
    func choose(_ municipality: Municipality, session: SessionViewModel) async -> Bool {
        savingId = municipality.municipalityId
        defer { savingId = nil }
        do {
            try await session.selectMunicipality(municipality)
            return true
        } catch {
            errorMessage = session.message(for: error)
            return false
        }
    }
}

/// The current city's election overview for the Home screen.
@MainActor
@Observable
final class HomeViewModel {
    private(set) var election: Election?
    private(set) var isLoading = false
    var errorMessage: String?

    private let services: AppServices

    init(services: AppServices? = nil) {
        self.services = services ?? .shared
    }

    func load(city: String) async {
        if election?.municipalityName != city { election = nil }
        isLoading = true
        defer { isLoading = false }
        do {
            election = try await services.elections.fetchElection(city: city)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}

/// Candidates for the current city, with server-side name search and an office filter.
@MainActor
@Observable
final class CandidateDirectoryViewModel {
    struct OfficeGroup: Identifiable {
        let id: Int
        let name: String
        let seats: Int?
        let candidates: [Candidate]
    }

    private(set) var candidates: [Candidate] = []
    private(set) var isLoading = false
    private(set) var loadedCity: String?
    var searchText = ""
    /// nil means all offices.
    var officeFilter: Int?
    var errorMessage: String?

    private let services: AppServices

    init(services: AppServices? = nil) {
        self.services = services ?? .shared
    }

    /// Offices present in the loaded candidates, for the filter menu.
    var availableOffices: [(id: Int, name: String)] {
        Dictionary(grouping: allCandidatesForFilter, by: \.positionId)
            .map { (id: $0.key, name: $0.value.first?.positionName ?? "Office") }
            .sorted { $0.id < $1.id }
    }

    var groups: [OfficeGroup] {
        let visible = candidates.filter { officeFilter == nil || $0.positionId == officeFilter }
        return Dictionary(grouping: visible, by: \.positionId)
            .map { positionId, items in
                OfficeGroup(
                    id: positionId,
                    name: items.first?.positionName ?? "Candidates",
                    seats: items.first?.seatsAvailable,
                    candidates: items.sorted { $0.name < $1.name }
                )
            }
            .sorted { $0.id < $1.id }
    }

    var isEmpty: Bool { groups.isEmpty }

    private var unfilteredCandidates: [Candidate] = []
    private var allCandidatesForFilter: [Candidate] { unfilteredCandidates.isEmpty ? candidates : unfilteredCandidates }

    func load(city: String) async {
        if loadedCity != city {
            // Never keep showing the previous city's candidates.
            candidates = []
            unfilteredCandidates = []
            officeFilter = nil
            loadedCity = city
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = true
        defer { isLoading = false }
        do {
            let results: [Candidate]
            if query.isEmpty {
                results = try await services.elections.fetchCandidates(city: city, positionId: nil)
                unfilteredCandidates = results
            } else {
                results = try await services.elections.searchCandidates(city: city, name: query)
            }
            guard loadedCity == city else { return }
            candidates = results
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}

/// Refreshes one candidate from `GET /api/candidates/{id}?city=`, which also guarantees
/// the candidate belongs to the user's municipality.
@MainActor
@Observable
final class CandidateDetailViewModel {
    private(set) var candidate: Candidate?
    private(set) var isLoading = false
    var errorMessage: String?

    private let services: AppServices

    init(initial: Candidate?, services: AppServices? = nil) {
        self.candidate = initial
        self.services = services ?? .shared
    }

    func load(id: Int, city: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            candidate = try await services.elections.fetchCandidate(id: id, city: city)
        } catch is CancellationError {
            return
        } catch APIError.notFound {
            candidate = nil
            errorMessage = "This candidate isn't running in \(city)."
        } catch {
            // Keep showing the preview data if we have it; only surface the error otherwise.
            if candidate == nil {
                errorMessage = UserFacingError.message(for: error)
            }
        }
    }
}
