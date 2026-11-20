//
//  ElectionService.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher & Gemini
//

import Foundation

/// Election data from the Web API. Every call except `fetchMunicipalities` is scoped to one city.
protocol ElectionServiceProtocol {
    func fetchMunicipalities() async throws -> [Municipality]
    func fetchElection(city: String) async throws -> Election
    func fetchOffices(city: String) async throws -> [Position]
    func fetchCandidates(city: String, positionId: Int?) async throws -> [Candidate]
    func searchCandidates(city: String, name: String) async throws -> [Candidate]
    func fetchCandidate(id: Int, city: String) async throws -> Candidate
}

final class ElectionService: ElectionServiceProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    // GET /api/municipalities (all cities; used only for the city picker)
    func fetchMunicipalities() async throws -> [Municipality] {
        try await client.get("api/municipalities")
    }

    // GET /api/elections?city={name}
    func fetchElection(city: String) async throws -> Election {
        try await client.get("api/elections", query: [cityItem(city)])
    }

    // GET /api/offices?city={name}
    func fetchOffices(city: String) async throws -> [Position] {
        let offices: [Position] = try await client.get("api/offices", query: [cityItem(city)])
        return offices.filter { $0.municipalityName == nil || $0.municipalityName == city }
    }

    // GET /api/candidates?city={name}[&positionId=]
    func fetchCandidates(city: String, positionId: Int?) async throws -> [Candidate] {
        var query = [cityItem(city)]
        if let positionId {
            query.append(URLQueryItem(name: "positionId", value: String(positionId)))
        }
        let candidates: [Candidate] = try await client.get("api/candidates", query: query)
        return candidates.onlyIn(city: city)
    }

    // GET /api/candidates/search?city={name}&name={q}
    func searchCandidates(city: String, name: String) async throws -> [Candidate] {
        let candidates: [Candidate] = try await client.get(
            "api/candidates/search",
            query: [cityItem(city), URLQueryItem(name: "name", value: name)]
        )
        return candidates.onlyIn(city: city)
    }

    // GET /api/candidates/{id}?city={name} (404 if the candidate belongs to another city)
    func fetchCandidate(id: Int, city: String) async throws -> Candidate {
        try await client.get("api/candidates/\(id)", query: [cityItem(city)])
    }

    private func cityItem(_ city: String) -> URLQueryItem {
        URLQueryItem(name: "city", value: city)
    }
}

private extension Array where Element == Candidate {
    /// Defensive client-side check: never show another municipality's candidates,
    /// even if the server were to return them.
    func onlyIn(city: String) -> [Candidate] {
        filter { $0.municipalityName == nil || $0.municipalityName == city }
    }
}
