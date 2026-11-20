//
//  HomeView.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import SwiftUI

/// Election overview for the user's municipality, from `GET /api/elections?city=`.
struct HomeView: View {
    @Environment(SessionViewModel.self) private var session
    @Environment(SelectionsViewModel.self) private var selections
    @Environment(AppRouter.self) private var router
    @State private var viewModel = HomeViewModel()

    @ScaledMetric private var logoSize: CGFloat = 72
    @ScaledMetric private var officeMinWidth: CGFloat = 220

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) { viewModel.errorMessage = nil }
                }

                if let election = viewModel.election {
                    electionDetails(election)
                } else if viewModel.isLoading {
                    ProgressView("Loading election…")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle(AppSection.home.title)
        .navigationSubtitle("City: \(session.cityName)")
        .task(id: session.cityName) {
            await viewModel.load(city: session.cityName)
        }
        .refreshable {
            await viewModel.load(city: session.cityName)
            await selections.load()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            MunicipalityLogo(url: viewModel.election?.logoURL ?? session.municipality?.logoURL, size: logoSize)
            VStack(alignment: .leading, spacing: 4) {
                Text("Municipal Elections Companion")
                    .font(.title2.bold())
                CityLabel(city: session.cityName)
                if let date = viewModel.election?.electionDate ?? session.municipality?.electionDate {
                    Label(date.formatted(date: .long, time: .omitted), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func electionDetails(_ election: Election) -> some View {
        if let description = election.description, !description.isEmpty {
            Text(description)
                .font(.body)
        }

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Offices on the Ballot")
                    .font(.headline)
                Spacer()
                if let count = election.candidateCount {
                    Text("\(count) candidates")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: officeMinWidth), spacing: 12)], spacing: 12) {
                ForEach(election.offices) { office in
                    officeCard(office)
                }
            }
        }

        Button {
            router.section = .candidates
        } label: {
            Label("Browse \(election.municipalityName) Candidates", systemImage: "person.3")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func officeCard(_ office: Position) -> some View {
        let chosen = selections.chosenCount(forPosition: office.positionId)
        return VStack(alignment: .leading, spacing: 6) {
            Text(office.name)
                .font(.headline)
            Text(office.seatsAvailable == 1 ? "Vote for 1" : "Vote for up to \(office.seatsAvailable)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(min(chosen, office.seatsAvailable)), total: Double(max(office.seatsAvailable, 1))) {
                Text("You've chosen \(chosen) of \(office.seatsAvailable)")
                    .font(.caption)
            }
            .tint(chosen >= office.seatsAvailable ? .green : .accentColor)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}
