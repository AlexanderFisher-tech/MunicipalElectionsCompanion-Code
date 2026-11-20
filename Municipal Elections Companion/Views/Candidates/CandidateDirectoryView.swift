//
//  CandidateDirectoryView.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import SwiftUI

/// Candidates running in the user's municipality, grouped by office.
///
/// Layout adapts to the size classes:
/// - iPhone portrait (compact × regular): single-column list
/// - iPhone landscape (compact × compact): wide rows with biography and contact, in columns
/// - iPad (regular width): adaptive card grid, which gains columns as the space grows
struct CandidateDirectoryView: View {
    @Environment(SessionViewModel.self) private var session
    @Environment(SelectionsViewModel.self) private var selections
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var viewModel = CandidateDirectoryViewModel()

    @ScaledMetric private var cardMinWidth: CGFloat = 220
    @ScaledMetric private var wideRowMinWidth: CGFloat = 320

    private enum Layout { case list, wideRows, cards }

    private var layout: Layout {
        if horizontalSizeClass == .regular { return .cards }
        return verticalSizeClass == .compact ? .wideRows : .list
    }

    /// Reload whenever the city or search changes.
    private struct LoadKey: Equatable {
        let city: String
        let search: String
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        let city = session.cityName

        content
            .navigationTitle(AppSection.candidates.title)
            .navigationSubtitle("City: \(city)")
            .searchable(text: $viewModel.searchText, prompt: "Search \(city) candidates")
            .toolbar {
                ToolbarItem(placement: .primaryAction) { officeFilterMenu }
            }
            .task(id: LoadKey(city: city, search: viewModel.searchText)) {
                // Debounce typing so each keystroke doesn't hit the API.
                if !viewModel.searchText.isEmpty {
                    try? await Task.sleep(for: .milliseconds(350))
                    guard !Task.isCancelled else { return }
                }
                await viewModel.load(city: city)
            }
            .refreshable {
                await viewModel.load(city: city)
            }
            .navigationDestination(for: CandidateRoute.self) { route in
                CandidateDetailView(route: route)
            }
            .alert(
                "Couldn't Load Candidates",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("Retry") { Task { await viewModel.load(city: city) } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.isEmpty {
            ProgressView("Loading candidates…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isEmpty {
            if viewModel.searchText.isEmpty {
                ContentUnavailableView(
                    "No Candidates Found",
                    systemImage: "person.slash",
                    description: Text("There are no candidates listed for \(session.cityName) yet.")
                )
            } else {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        } else {
            switch layout {
            case .list:
                list
            case .wideRows:
                grid(minimumWidth: wideRowMinWidth) { candidate in
                    CandidateRowView(candidate: candidate, isSelected: isSelected(candidate), showsDetails: true)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
                }
            case .cards:
                grid(minimumWidth: cardMinWidth) { candidate in
                    CandidateCardView(candidate: candidate, isSelected: isSelected(candidate))
                }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.groups) { group in
                Section {
                    ForEach(group.candidates) { candidate in
                        NavigationLink(value: CandidateRoute(candidateId: candidate.candidateId, preview: candidate)) {
                            CandidateRowView(candidate: candidate, isSelected: isSelected(candidate), showsDetails: false)
                        }
                    }
                } header: {
                    header(for: group)
                }
            }
        }
        .listStyle(.plain)
    }

    private func grid<Cell: View>(minimumWidth: CGFloat, @ViewBuilder cell: @escaping (Candidate) -> Cell) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: 16, alignment: .top)],
                alignment: .leading,
                spacing: 16,
                pinnedViews: .sectionHeaders
            ) {
                ForEach(viewModel.groups) { group in
                    Section {
                        ForEach(group.candidates) { candidate in
                            NavigationLink(value: CandidateRoute(candidateId: candidate.candidateId, preview: candidate)) {
                                cell(candidate)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        header(for: group)
                            .padding(.vertical, 8)
                            .background(.bar)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func header(for group: CandidateDirectoryViewModel.OfficeGroup) -> some View {
        OfficeHeader(
            name: group.name,
            seats: selections.seatLimit(forPosition: group.id, fallback: group.seats),
            chosen: selections.chosenCount(forPosition: group.id)
        )
    }

    private var officeFilterMenu: some View {
        @Bindable var viewModel = viewModel
        return Menu {
            Picker("Office", selection: $viewModel.officeFilter) {
                Text("All Offices").tag(Int?.none)
                ForEach(viewModel.availableOffices, id: \.id) { office in
                    Text(office.name).tag(Int?.some(office.id))
                }
            }
        } label: {
            Label("Filter by Office", systemImage: viewModel.officeFilter == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private func isSelected(_ candidate: Candidate) -> Bool {
        selections.selection(for: candidate.candidateId) != nil
    }
}

// MARK: - Cells

/// A horizontal candidate row. With `showsDetails`, adds a biography excerpt and contact
/// info, used where there's extra horizontal space (iPhone landscape).
struct CandidateRowView: View {
    let candidate: Candidate
    let isSelected: Bool
    let showsDetails: Bool

    @ScaledMetric private var photoSize: CGFloat = 52
    @ScaledMetric private var detailedPhotoSize: CGFloat = 72

    var body: some View {
        HStack(alignment: showsDetails ? .top : .center, spacing: 12) {
            CandidatePhoto(url: candidate.photoURL, size: showsDetails ? detailedPhotoSize : photoSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.name)
                    .font(.headline)
                Text(candidate.positionName ?? "Candidate")
                    .font(.subheadline)
                    .foregroundStyle(.tint)

                if showsDetails {
                    if let biography = candidate.biography, !biography.isEmpty {
                        Text(biography)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if let email = candidate.email, !email.isEmpty {
                        Label(email, systemImage: "envelope")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else if let city = candidate.municipalityName {
                    Text(city)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
            SelectedBadge(isSelected: isSelected)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// A vertical card for the iPad grid.
struct CandidateCardView: View {
    let candidate: Candidate
    let isSelected: Bool

    @ScaledMetric private var photoSize: CGFloat = 96

    var body: some View {
        VStack(spacing: 8) {
            CandidatePhoto(url: candidate.photoURL, size: photoSize)
                .overlay(alignment: .topTrailing) {
                    SelectedBadge(isSelected: isSelected)
                }

            Text(candidate.name)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(candidate.positionName ?? "Candidate")
                .font(.subheadline)
                .foregroundStyle(.tint)

            if let biography = candidate.biography, !biography.isEmpty {
                Text(biography)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// A checkmark shown on candidates already in the user's selections.
struct SelectedBadge: View {
    let isSelected: Bool

    var body: some View {
        if isSelected {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .background(Circle().fill(.background))
                .accessibilityLabel("In your selections")
        }
    }
}
