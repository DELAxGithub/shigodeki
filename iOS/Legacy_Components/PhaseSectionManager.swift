//
//  PhaseSectionManager.swift
//  shigodeki
//
//  Minimal manager to read sections within a phase
//

import Foundation
import FirebaseFirestore

@MainActor
class PhaseSectionManager: ObservableObject {
    @Published var sections: [PhaseSection] = []
    @Published var isLoading = false
    @Published var error: FirebaseError?
    private var listeners: [ListenerRegistration] = []
    
    deinit {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    func getSections(phaseId: String, projectId: String) async throws -> [PhaseSection] {
        isLoading = true
        defer { isLoading = false }
        do {
            let coll = Firestore.firestore()
                .collection("projects").document(projectId)
                .collection("phases").document(phaseId)
                .collection("sections")
            let snapshot = try await coll.order(by: "order").getDocuments()
            return try snapshot.documents.compactMap { try $0.data(as: PhaseSection.self) }
        } catch {
            let e = FirebaseError.from(error)
            self.error = e
            throw e
        }
    }
    
    func startListening(phaseId: String, projectId: String) {
        removeAllListeners()
        let coll = Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("sections")
        let l = coll.order(by: "order").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error = error { self.error = FirebaseError.from(error); return }
                guard let docs = snapshot?.documents else { return }
                do {
                    let items = try docs.compactMap { try $0.data(as: PhaseSection.self) }
                    self.sections = items
                } catch {
                    self.error = FirebaseError.from(error)
                }
            }
        }
        listeners.append(l)
    }
    
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    // MARK: - CRUD
    func createSection(name: String, phaseId: String, projectId: String, order: Int? = nil, colorHex: String? = nil) async throws -> PhaseSection {
        isLoading = true
        defer { isLoading = false }
        let coll = Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("sections")
        let nextOrder: Int
        if let order = order {
            nextOrder = order
        } else {
            let cur = try await coll.getDocuments()
            let maxOrder = cur.documents.compactMap { try? $0.data(as: PhaseSection.self).order }.max() ?? -1
            nextOrder = maxOrder + 1
        }
        var sec = PhaseSection(name: name, order: nextOrder, colorHex: colorHex)
        sec.createdAt = Date()
        let doc = coll.document()
        sec.id = doc.documentID
        try await doc.setData(try Firestore.Encoder().encode(sec))
        return sec
    }

    func updateSection(_ section: PhaseSection, phaseId: String, projectId: String) async throws {
        guard let sid = section.id else { return }
        let doc = Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("sections").document(sid)
        try await doc.setData(try Firestore.Encoder().encode(section), merge: true)
    }

    func deleteSection(id: String, phaseId: String, projectId: String) async throws {
        let doc = Firestore.firestore()
            .collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("sections").document(id)
        try await doc.delete()
    }

    func reorderSections(_ sections: [PhaseSection], phaseId: String, projectId: String) async throws {
        let batch = Firestore.firestore().batch()
        for (index, sec) in sections.enumerated() {
            var s = sec
            s.order = index
            let ref = Firestore.firestore()
                .collection("projects").document(projectId)
                .collection("phases").document(phaseId)
                .collection("sections").document(sec.id ?? "")
            try batch.setData(try Firestore.Encoder().encode(s), forDocument: ref, merge: true)
        }
        try await batch.commit()
    }
}
