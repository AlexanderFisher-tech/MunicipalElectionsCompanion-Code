//
//  ContentView.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import SwiftUI

/// Chooses the top-level screen from the session phase:
/// login → profile loading → first-time city choice → main app.
struct ContentView: View {
    @Environment(SessionViewModel.self) private var session
    @Environment(SelectionsViewModel.self) private var selections
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            switch session.phase {
            case .launching:
                ProgressView("Loading…")
            case .signedOut:
                LoginView()
            case .loadingProfile:
                ProfileLoadingView()
            case .needsMunicipality:
                NavigationStack {
                    CitySelectionView(isFirstTime: true)
                }
            case .ready:
                MainView()
            }
        }
        .task {
            if session.phase == .launching {
                await session.restore()
            }
        }
        // Whenever the city changes (including first login), drop routes into the old city
        // and reload the selections for the new one.
        .task(id: session.municipality?.municipalityId) {
            router.reset()
            await selections.load()
        }
        .onChange(of: session.phase) { _, phase in
            if phase == .signedOut {
                router.reset()
                router.section = .home
                selections.reset()
            }
        }
    }
}

/// Shown while the Firestore profile loads; offers retry if it fails.
private struct ProfileLoadingView: View {
    @Environment(SessionViewModel.self) private var session

    var body: some View {
        if let error = session.profileError {
            ContentUnavailableView {
                Label("Couldn't Load Your Profile", systemImage: "exclamationmark.icloud")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") {
                    Task { await session.loadProfile() }
                }
                .buttonStyle(.borderedProminent)
                Button("Log Out", role: .destructive) {
                    session.logout()
                }
            }
        } else {
            ProgressView("Loading your profile…")
        }
    }
}
