//
//  TaskModelMigrationService.swift
//  shigodeki
//
//  Provides helper routines to backfill newly added task fields such as
//  `orderIndex` and `syncStatus` so existing data can participate in
//  reordering and offline badge features.
//

import Foundation
import FirebaseFirestore

struct TaskBackfillInfo {
    enum CollectionPath {
        case list(listId: String, phaseId: String, projectId: String)
        case phase(phaseId: String, projectId: String)
    }

    let documentId: String
    let collectionPath: CollectionPath
    let desiredOrderIndex: Int
    let desiredSyncStatus: TaskSyncStatus
    let needsOrderIndex: Bool
    let needsSyncStatus: Bool
}

actor TaskModelMigrationService {
    static let shared = TaskModelMigrationService()

    private let db = Firestore.firestore()

    func backfillIfNeeded(_ infos: [TaskBackfillInfo]) async {
        let updates = infos.filter { $0.needsOrderIndex || $0.needsSyncStatus }
        guard updates.isEmpty == false else { return }

        let batch = db.batch()
        for info in updates {
            guard let document = documentReference(for: info) else { continue }
            var data: [String: Any] = [:]
            if info.needsOrderIndex {
                data["orderIndex"] = info.desiredOrderIndex
            }
            if info.needsSyncStatus {
                data["syncStatus"] = info.desiredSyncStatus.rawValue
            }
            if data.isEmpty == false {
                batch.setData(data, forDocument: document, merge: true)
            }
        }

        do {
            try await batch.commit()
            #if DEBUG
            print("🛠️ TaskModelMigrationService: Backfilled \(updates.count) task documents")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ TaskModelMigrationService: Failed to backfill tasks - \(error.localizedDescription)")
            #endif
        }
    }

    private func documentReference(for info: TaskBackfillInfo) -> DocumentReference? {
        switch info.collectionPath {
        case let .list(listId, phaseId, projectId):
            guard !listId.isEmpty else { return nil }
            return db.collection("projects").document(projectId)
                .collection("phases").document(phaseId)
                .collection("lists").document(listId)
                .collection("tasks").document(info.documentId)
        case let .phase(phaseId, projectId):
            return db.collection("projects").document(projectId)
                .collection("phases").document(phaseId)
                .collection("tasks").document(info.documentId)
        }
    }
}

