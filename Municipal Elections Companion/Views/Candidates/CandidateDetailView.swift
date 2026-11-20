//
//  CandidateDetailView.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import SwiftUI

/// Candidate information from the Web API plus Add / Edit / Delete Selection actions.
/// Stacks vertically on iPhone portrait; photo and information sit side by side when there's
/// horizontal room (iPad, iPhone landscape).
struct CandidateDetailView: View {
    let route: CandidateRoute

    @Environment(SessionViewModel.self) private var session
    @Environment(SelectionsViewModel.self) private var selections
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var viewModel: CandidateDetailViewModel
    @State private var editorMode: SelectionEditorMode?
    @State private var confirmingDelete = false
    @State private var alertMessage: String?

    @ScaledMetric private var photoSize: CGFloat = 140

    init(route: CandidateRoute) {
        self.route = route
        _viewModel = State(initialValue: CandidateDetailViewModel(initial: route.preview))
    }

    private var isSideBySide: Bool {
        horizontalSizeClass == .regular || verticalSizeClass == .compact
    }

    var body: some View {
        Group {
            if let candidate = viewModel.candidate {
                ScrollView {
                    details(for: candidate)
                        .padding()
                }
            } else if viewModel.isLoading {
                ProgressView("Loading candidate…")
            } else {
                ContentUnavailableView(
                    "Candidate Unavailable",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text(viewModel.errorMessage ?? "This candidate couldn't be loaded.")
                )
            }
        }
        .navigationTitle(viewModel.candidate?.name ?? "Candidate Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationSubtitle("City: \(session.cityName)")
        .task(id: session.cityName) {
            await viewModel.load(id: route.candidateId, city: session.cityName)
        }
        .sheet(item: $editorMode) { mode in
            SelectionEditorView(mode: mode)
        }
        .alert(
            "Remove \(viewModel.candidate?.name ?? "this candidate") from your selections?",
            isPresented: $confirmingDelete
        ) {
            Button("Delete Selection", role: .destructive) {
                Task { await deleteSelection() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your notes for this candidate will be deleted.")
        }
        .alert(
            "Candidate Selections",
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

    // MARK: - Layout

    @ViewBuilder
    private func details(for candidate: Candidate) -> some View {
        if isSideBySide {
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 16) {
                    CandidatePhoto(url: candidate.photoURL, size: photoSize)
                    selectionPanel(for: candidate)
                }
                .frame(maxWidth: photoSize * 2.2)

                VStack(alignment: .leading, spacing: 16) {
                    identity(for: candidate, alignment: .leading)
                    information(for: candidate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(spacing: 16) {
                CandidatePhoto(url: candidate.photoURL, size: photoSize)
                identity(for: candidate, alignment: .center)
                selectionPanel(for: candidate)
                information(for: candidate)
            }
        }
    }

    private func identity(for candidate: Candidate, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(candidate.name)
                .font(.title.bold())
                .multilineTextAlignment(alignment == .center ? .center : .leading)
            Text(candidate.positionName ?? "Candidate")
                .font(.headline)
                .foregroundStyle(.tint)
            if let city = candidate.municipalityName {
                Label(city, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let seats = selections.seatLimit(forPosition: candidate.positionId, fallback: candidate.seatsAvailable) {
                Text("\(selections.chosenCount(forPosition: candidate.positionId)) of \(seats) \(candidate.positionName ?? "") seats chosen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }

    private func information(for candidate: Candidate) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()

            Text("Biography")
                .font(.headline)
            Text(candidate.biography ?? "No biography available.")
                .font(.body)

            Divider()

            Text("Contact Information")
                .font(.headline)
            if let email = candidate.email, !email.isEmpty, let mailURL = URL(string: "mailto:\(email)") {
                Link(destination: mailURL) {
                    Label(email, systemImage: "envelope.fill")
                }
                .font(.subheadline)
            }
            if let websiteURL = candidate.websiteURL {
                Link(destination: websiteURL) {
                    Label(candidate.website ?? websiteURL.absoluteString, systemImage: "globe")
                }
                .font(.subheadline)
            }
            if (candidate.email ?? "").isEmpty && candidate.websiteURL == nil {
                Text("No contact information provided.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Add Selection, or Edit / Delete Selection when this candidate is already saved.
    @ViewBuilder
    private func selectionPanel(for candidate: Candidate) -> some View {
        let isBusy = selections.pendingCandidateIds.contains(candidate.candidateId)

        if let saved = selections.selection(for: candidate.candidateId) {
            VStack(alignment: .leading, spacing: 10) {
                Label("In your selections", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text(saved.notes.isEmpty ? "No notes." : saved.notes)
                    .font(.subheadline)
                    .foregroundStyle(saved.notes.isEmpty ? .secondary : .primary)
                Text("Saved \(saved.dateCreated.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack {
                    editButton(saved)
                    deleteButton
                }
                .disabled(isBusy)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        } else {
            Button {
                if let problem = selections.problemAdding(candidate) {
                    alertMessage = problem.errorDescription
                } else {
                    editorMode = .create(candidate)
                }
            } label: {
                Group {
                    if isBusy {
                        ProgressView()
                    } else {
                        Label("Add Selection", systemImage: "plus.circle.fill")
                    }
                }
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isBusy || !selections.hasLoaded)
        }
    }

    private func editButton(_ saved: CandidateSelection) -> some View {
        Button {
            editorMode = .edit(saved)
        } label: {
            Label("Edit Selection", systemImage: "pencil")
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmingDelete = true
        } label: {
            Label("Delete Selection", systemImage: "trash")
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func deleteSelection() async {
        guard let saved = viewModel.candidate.flatMap({ selections.selection(for: $0.candidateId) }) else { return }
        alertMessage = await selections.delete(saved).errorMessage
    }
}
