//
//  SelectionEditorView.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import SwiftUI

enum SelectionEditorMode: Identifiable {
    case create(Candidate)
    case edit(CandidateSelection)

    var id: String {
        switch self {
        case .create(let candidate): return "create-\(candidate.candidateId)"
        case .edit(let selection): return "edit-\(selection.id)"
        }
    }
}

/// Sheet for adding a candidate to the user's selections, or editing an existing selection's notes.
struct SelectionEditorView: View {
    let mode: SelectionEditorMode

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionViewModel.self) private var session
    @Environment(SelectionsViewModel.self) private var selections

    // Draft state lives in @State on the sheet, so it survives rotation while editing.
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    @ScaledMetric private var photoSize: CGFloat = 56
    @ScaledMetric private var editorMinHeight: CGFloat = 140

    init(mode: SelectionEditorMode) {
        self.mode = mode
        switch mode {
        case .create: _notes = State(initialValue: "")
        case .edit(let selection): _notes = State(initialValue: selection.notes)
        }
    }

    private var isOverLimit: Bool { notes.count > CandidateSelection.maxNotesLength }

    private var hasChanges: Bool {
        switch mode {
        case .create: return !notes.isEmpty
        case .edit(let selection): return notes != selection.notes
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        CandidatePhoto(url: photoURL, size: photoSize)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidateName).font(.headline)
                            Text(positionName).font(.subheadline).foregroundStyle(.tint)
                            Text(session.cityName).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: editorMinHeight)
                        .accessibilityLabel("Notes")
                } header: {
                    Text("Notes (optional)")
                } footer: {
                    HStack(alignment: .firstTextBaseline) {
                        if isOverLimit {
                            Text("Notes cannot exceed \(CandidateSelection.maxNotesLength) characters.")
                        } else {
                            Text("Why you chose this candidate, questions to ask, and so on.")
                        }
                        Spacer()
                        Text("\(notes.count)/\(CandidateSelection.maxNotesLength)")
                            .monospacedDigit()
                    }
                    .foregroundStyle(isOverLimit ? .red : .secondary)
                }
            }
            .navigationTitle(isCreating ? "Add Selection" : "Edit Selection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(isCreating ? "Add" : "Save") {
                            Task { await save() }
                        }
                        .disabled(isOverLimit || (!isCreating && !hasChanges))
                    }
                }
            }
            .interactiveDismissDisabled(hasChanges || isSaving)
            .alert(
                "Couldn't Save Selection",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let outcome: SelectionWriteOutcome
        switch mode {
        case .create(let candidate):
            outcome = await selections.add(candidate, notes: notes)
        case .edit(let selection):
            outcome = await selections.updateNotes(for: selection, to: notes)
        }

        switch outcome {
        case .success, .sessionEnded:
            dismiss()
        case .failure(let message):
            errorMessage = message
        }
    }

    // MARK: - Display values

    private var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    private var candidateName: String {
        switch mode {
        case .create(let candidate): return candidate.name
        case .edit(let selection): return selection.candidateName
        }
    }

    private var positionName: String {
        switch mode {
        case .create(let candidate): return candidate.positionName ?? "Candidate"
        case .edit(let selection): return selection.positionName
        }
    }

    private var photoURL: URL? {
        switch mode {
        case .create(let candidate): return candidate.photoURL
        case .edit(let selection): return selection.photoURL
        }
    }
}
