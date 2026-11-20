//
//  SessionViewModel.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation
import Observation

/// App-wide authentication and municipality state. Injected into the environment at the root,
/// so every screen agrees on who is logged in and which city they're looking at.
@MainActor
@Observable
final class SessionViewModel {
    enum Phase: Equatable {
        case launching
        case signedOut
        /// Logged in; loading the Firestore profile to find the user's municipality.
        case loadingProfile
        /// First login (or the saved city no longer exists): the user must pick a municipality.
        case needsMunicipality
        case ready
    }

    private(set) var phase: Phase = .launching
    private(set) var session: StoredSession?
    private(set) var municipality: Municipality?
    private(set) var profile: UserProfile?

    /// A message for the login screen, e.g. after the session expired.
    var notice: String?
    /// Set when the profile couldn't be loaded; the loading screen offers a retry.
    private(set) var profileError: String?

    private let services: AppServices

    init(services: AppServices? = nil) {
        self.services = services ?? .shared
        // Any authorized API call answering 401 means the JWT is no longer valid.
        self.services.apiClient.onUnauthorized = { [weak self] in
            self?.expireSession()
        }
    }

    var email: String { session?.email ?? "" }
    var name: String { session?.name ?? "" }
    var cityName: String { municipality?.name ?? "No city selected" }

    // MARK: - Authentication

    func restore() async {
        switch services.auth.restoreSession() {
        case .restored(let restored):
            session = restored
            await loadProfile()
        case .expired:
            notice = "Your session has expired. Please log in again."
            phase = .signedOut
        case .none:
            phase = .signedOut
        }
    }

    func login(email: String, password: String) async throws {
        let newSession = try await services.auth.login(email: email, password: password)
        session = newSession
        notice = nil
        await loadProfile()
    }

    func register(name: String, email: String, password: String) async throws {
        try await services.auth.register(name: name, email: email, password: password)
    }

    func logout() {
        services.auth.logout()
        session = nil
        municipality = nil
        profile = nil
        profileError = nil
        phase = .signedOut
    }

    /// Clears the session and sends the user back to login with a friendly message.
    func expireSession() {
        guard session != nil else { return }
        logout()
        notice = "Your session has expired. Please log in again."
    }

    /// Returns a message to show for `error`, or nil if the error ended the session
    /// (in which case the user is already being sent to the login screen).
    func message(for error: Error) -> String? {
        if UserFacingError.requiresReauthentication(error) {
            expireSession()
            return nil
        }
        return UserFacingError.message(for: error)
    }

    // MARK: - Municipality

    func loadProfile() async {
        guard let session else { return }
        phase = .loadingProfile
        profileError = nil

        do {
            guard let saved = try await services.profiles.fetchProfile(email: session.email) else {
                phase = .needsMunicipality
                return
            }
            profile = saved
            // Resolve the stored id to the full Municipality (logo, election date, etc.).
            let municipalities = try await services.elections.fetchMunicipalities()
            if let match = municipalities.first(where: { $0.municipalityId == saved.municipalityId })
                ?? municipalities.first(where: { $0.name == saved.city }) {
                municipality = match
                phase = .ready
            } else {
                phase = .needsMunicipality
            }
        } catch {
            profileError = message(for: error)
        }
    }

    /// Saves the municipality to Firestore first, and only then switches the app over to it.
    func selectMunicipality(_ newValue: Municipality) async throws {
        guard let session else { throw SelectionValidationError.notLoggedIn }
        profile = try await services.profiles.saveMunicipality(newValue, email: session.email)
        municipality = newValue
        phase = .ready
    }

    /// Records a successful Firestore sync locally and in the user's profile.
    func recordSync(at date: Date) {
        profile?.lastSync = date
        guard let email = session?.email else { return }
        Task {
            // Best effort: failing to store the timestamp shouldn't interrupt the user.
            try? await services.profiles.updateLastSync(date, email: email)
        }
    }
}
