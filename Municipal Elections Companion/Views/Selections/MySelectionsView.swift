//
//  MySelectionsView.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import SwiftUI

/// "My Candidate Selections": the user's Firestore selections for the current city,
/// with edit, delete (confirmed) and pull to refresh.
struct MySelectionsView: View {
    @Environment(SessionViewModel.self) private var session
    @Environment(SelectionsViewModel.self) private var selections

    @State private var editorMode: SelectionEditorMode?
    @State private var pendingDelete: CandidateSelection?
    @State private var alertMessage: String?

    var body: some View {
        List {
            if let error = selections.errorMessage {
                ErrorBanner(message: error) { selections.errorMessage = nil }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(selections.groupedByOffice, id: \.positionId) { group in
                Section {
                    ForEach(group.items) { selection in
                        NavigationLink(value: CandidateRoute(candidateId: selection.candidateId)) {
                            SelectionRowView(selection: selection)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", systemImage: "trash") { pendingDelete = selection }
                                .tint(.red)
                            Button("Edit", systemImage: "pencil") { editorMode = .edit(selection) }
                                .tint(.blue)
                        }
                        .contextMenu {
                            Button("Edit Selection", systemImage: "pencil") { editorMode = .edit(selection) }
                            Button("Delete Selection", systemImage: "trash", role: .destructive) { pendingDelete = selection }
                        }
                        .disabled(selections.pendingCandidateIds.contains(selection.candidateId))
                    }
                } header: {
                    OfficeHeader(
                        name: group.office,
                        seats: selections.seatLimit(forPosition: group.positionId),
                        chosen: group.items.count
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { emptyState }
        .navigationTitle("My Candidate Selections")
        .navigationBarTitleDisplayMode(.inline)
        .navigationSubtitle("City: \(session.cityName)")
        .refreshable {
            await selections.load()
        }
        .navigationDestination(for: CandidateRoute.self) { route in
            CandidateDetailView(route: route)
        }
        .sheet(item: $editorMode) { mode in
            SelectionEditorView(mode: mode)
        }
        .alert(
            "Remove \(pendingDelete?.candidateName ?? "this candidate") from your selections?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { selection in
            Button("Delete Selection", role: .destructive) {
                Task { alertMessage = await selections.delete(selection).errorMessage }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Your notes for this candidate will be deleted.")
        }
        .alert(
            "Couldn't Update Selections",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if selections.selections.isEmpty {
            if selections.isLoading || !selections.hasLoaded && selections.errorMessage == nil {
                ProgressView("Loading your selections…")
            } else if selections.hasLoaded {
                ContentUnavailableView(
                    "No Selections Yet",
                    systemImage: "checkmark.seal",
                    description: Text("Open a candidate in the Candidates tab and tap Add Selection to save them here for \(session.cityName).")
                )
            }
        }
    }
}

/// One saved selection: photo, name, position, municipality, notes and date saved.
struct SelectionRowView: View {
    let selection: CandidateSelection

    @ScaledMetric private var photoSize: CGFloat = 56

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CandidatePhoto(url: selection.photoURL, size: photoSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(selection.candidateName)
                    .font(.headline)
                Text(selection.positionName)
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                Label(selection.municipalityName, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !selection.notes.isEmpty {
                    Text(selection.notes)
                        .font(.callout)
                        .lineLimit(3)
                        .padding(.top, 2)
                }

                Text(savedText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private var savedText: String {
        let saved = "Saved \(selection.dateCreated.formatted(date: .abbreviated, time: .shortened))"
        guard selection.wasEdited else { return saved }
        return saved + " · Edited \(selection.dateModified.formatted(date: .abbreviated, time: .shortened))"
    }
}
