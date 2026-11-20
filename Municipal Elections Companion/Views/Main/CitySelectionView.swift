//
//  CitySelectionView.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import SwiftUI

/// Lets the user choose their municipality. Shown on first login, and from the Profile screen.
/// The choice is saved to Firestore (`UserProfiles/{email}`) before the app switches cities.
struct CitySelectionView: View {
    let isFirstTime: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionViewModel.self) private var session
    @State private var viewModel = CitySelectionViewModel()
    @ScaledMetric private var logoSize: CGFloat = 44

    var body: some View {
        List {
            Section {
                ForEach(viewModel.municipalities) { municipality in
                    Button {
                        Task { await choose(municipality) }
                    } label: {
                        row(for: municipality)
                    }
                    .disabled(viewModel.savingId != nil)
                }
            } header: {
                if isFirstTime {
                    Text("Choose the municipality you live in. You'll only see candidates for that city, and you can change it later in Profile.")
                        .textCase(nil)
                        .font(.subheadline)
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.municipalities.isEmpty {
                ProgressView("Loading municipalities…")
            } else if !viewModel.isLoading && viewModel.municipalities.isEmpty {
                ContentUnavailableView {
                    Label("No Municipalities", systemImage: "building.columns")
                } description: {
                    Text(viewModel.errorMessage ?? "Couldn't load the list of municipalities.")
                } actions: {
                    Button("Try Again") { Task { await viewModel.load() } }
                }
            }
        }
        .navigationTitle(isFirstTime ? "Welcome" : "Change Municipality")
        .toolbar {
            if isFirstTime {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Log Out", role: .destructive) { session.logout() }
                }
            } else {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await viewModel.load() }
        .alert(
            "Couldn't Save Municipality",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil && !viewModel.municipalities.isEmpty },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func row(for municipality: Municipality) -> some View {
        HStack(spacing: 12) {
            MunicipalityLogo(url: municipality.logoURL, size: logoSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(municipality.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(municipality.province)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.savingId == municipality.municipalityId {
                ProgressView()
            } else if municipality.municipalityId == session.municipality?.municipalityId {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Current municipality")
            }
        }
        .contentShape(Rectangle())
    }

    private func choose(_ municipality: Municipality) async {
        guard municipality.municipalityId != session.municipality?.municipalityId else {
            dismiss()
            return
        }
        if await viewModel.choose(municipality, session: session), !isFirstTime {
            dismiss()
        }
    }
}
