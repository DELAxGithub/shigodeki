//
//  KPIDataSource.swift
//  shigodeki
//
//  Fetches lightweight task snapshots for KPI calculations.
//

import Foundation
import FirebaseFirestore

actor KPIDataSource {
    static let shared = KPIDataSource()
    private let db = Firestore.firestore()

    func fetchTasks(projectIds: [String]) async throws -> [TaskLite] {
        guard !projectIds.isEmpty else { return [] }
        var results: [TaskLite] = []
        let chunkSize = 10
        let chunks = stride(from: 0, to: projectIds.count, by: chunkSize).map { index -> [String] in
            let end = min(index + chunkSize, projectIds.count)
            return Array(projectIds[index..<end])
        }

        for chunk in chunks {
            let snapshot = try await db.collectionGroup("tasks")
                .whereField("projectId", in: chunk)
                .getDocuments()
            for document in snapshot.documents {
                guard let projectId = document.data()["projectId"] as? String else { continue }
                let data = document.data()
                let title = (data["title"] as? String) ?? "タスク"
                let phaseId = data["phaseId"] as? String
                let dueDate = (data["dueDate"] as? Timestamp)?.dateValue()
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
                let completedAt = (data["completedAt"] as? Timestamp)?.dateValue()
                let priority = data["priority"] as? String
                let isCompleted = data["isCompleted"] as? Bool ?? false
                let dependsOn = data["dependsOn"] as? [String] ?? []

                let lite = TaskLite(
                    id: document.documentID,
                    title: title,
                    projectId: projectId,
                    phaseId: phaseId,
                    dueDate: dueDate,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    completedAt: completedAt,
                    priorityRaw: priority,
                    isCompleted: isCompleted,
                    dependsOn: dependsOn
                )
                results.append(lite)
            }
        }
        return results
    }
}

