//
//  ProfileView.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher on 2026-10-24.
//

import SwiftUI

struct ProfileView: View {
    @Environment(SessionViewModel.self) private var session
    @Environment(SelectionsViewModel.self) private var selections

    @State private var showingCityPicker = false
    @State private var confirmingLogout = false

    @ScaledMetric private var logoSize: CGFloat = 36

    var body: some View {
        List {
            Section(header: Text("User Info")) {
                LabeledContent("Name", value: session.name.isEmpty ? "Not Set" : session.name)
                LabeledContent("Email", value: session.email)
            }

            Section {
                HStack(spacing: 12) {
                    MunicipalityLogo(url: session.municipality?.logoURL, size: logoSize)
                    LabeledContent("City", value: session.cityName)
                }
                Button("Change Municipality", systemImage: "arrow.left.arrow.right") {
                    showingCityPicker = true
                }
            } header: {
                Text("Municipality")
            } footer: {
                Text("Saved to your profile in Firebase. Changing it reloads the election, offices, candidates and your selections for the new city.")
            }

            Section(header: Text("Candidate Selections")) {
                LabeledContent("Total saved selections", value: "\(selections.selections.count)")
                LabeledContent("Last synchronized", value: lastSyncText)
                Button("Sync Now", systemImage: "arrow.triangle.2.circlepath") {
                    Task { await selections.load() }
                }
                .disabled(selections.isLoading)
            }

            Section {
                Button("Log Out", role: .destructive) {
                    confirmingLogout = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Profile")
        .navigationSubtitle("City: \(session.cityName)")
        .sheet(isPresented: $showingCityPicker) {
            NavigationStack {
                CitySelectionView(isFirstTime: false)
            }
        }
        .alert("Log out of Municipal Elections Companion?", isPresented: $confirmingLogout) {
            Button("Log Out", role: .destructive) { session.logout() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var lastSyncText: String {
        guard let date = selections.lastSync ?? session.profile?.lastSync else { return "Never" }
        return date.formatted(date: .abbreviated, time: .standard)
    }
}
