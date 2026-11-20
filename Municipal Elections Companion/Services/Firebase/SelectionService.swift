//
//  SelectionService.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation
import FirebaseFirestore

/// CRUD for the Firestore `CandidateSelections` collection.
protocol SelectionServiceProtocol {
    /// Only the user's selections for one municipality.
    func fetchSelections(userEmail: String, municipalityName: String) async throws -> [CandidateSelection]
    func create(_ selection: CandidateSelection) async throws
    func updateNotes(selectionId: String, notes: String, modified: Date) async throws
    func delete(selectionId: String) async throws
}

final class SelectionService: SelectionServiceProtocol {
    static let collectionName = "CandidateSelections"

    // Resolved lazily so it's only touched after FirebaseApp.configure() has run.
    private var collection: CollectionReference {
        Firestore.firestore().collection(Self.collectionName)
    }

    func fetchSelections(userEmail: String, municipalityName: String) async throws -> [CandidateSelection] {
        // Both filters are equality checks, so no composite index is needed. The
        // userEmail filter is also what lets the security rules allow this query.
        let snapshot = try await collection
            .whereField("userEmail", isEqualTo: userEmail.lowercased())
            .whereField("municipalityName", isEqualTo: municipalityName)
            .getDocuments(source: .server)

        do {
            return try snapshot.documents.map { try $0.data(as: CandidateSelection.self) }
        } catch {
            print("Invalid CandidateSelection document: \(error)")
            throw FirestoreDataError.invalidDocument
        }
    }

    func create(_ selection: CandidateSelection) async throws {
        let data = try Firestore.Encoder().encode(selection)
        try await collection.document(selection.id).setData(data)
    }

    func updateNotes(selectionId: String, notes: String, modified: Date) async throws {
        try await collection.document(selectionId).updateData([
            "notes": notes,
            "dateModified": Timestamp(date: modified),
        ])
    }

    func delete(selectionId: String) async throws {
        try await collection.document(selectionId).delete()
    }
}
