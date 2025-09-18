//
//  ProjectMetricsService.swift
//  shigodeki
//
//  Computes lightweight project summary metrics for family cards.
//

import Foundation
import FirebaseFirestore

actor ProjectMetricsService {
    static let shared = ProjectMetricsService()
    private let db = Firestore.firestore()

    func metrics(for project: Project) async -> ProjectSummaryMetrics? {
        guard let projectId = project.id, !projectId.isEmpty else { return nil }

        do {
            let tasksSnapshot = try await db
                .collectionGroup("tasks")
                .whereField("projectId", isEqualTo: projectId)
                .getDocuments()

            var total = 0
            var completed = 0
            var remaining = 0
            var upcomingCandidates: [(title: String, due: Date?, createdAt: Date?)] = []

            for document in tasksSnapshot.documents {
                let data = document.data()
                total += 1
                let isCompleted = data["isCompleted"] as? Bool ?? false
                if isCompleted {
                    completed += 1
                } else {
                    remaining += 1
                    let title = (data["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let due = (data["dueDate"] as? Timestamp)?.dateValue()
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                    upcomingCandidates.append((title: title?.isEmpty == false ? title! : "タスク", due: due, createdAt: createdAt))
                }
            }

            upcomingCandidates.sort { lhs, rhs in
                switch (lhs.due, rhs.due) {
                case let (l?, r?):
                    if l == r { return (lhs.createdAt ?? Date.distantFuture) < (rhs.createdAt ?? Date.distantFuture) }
                    return l < r
                case (.none, .some):
                    return false
                case (.some, .none):
                    return true
                case (.none, .none):
                    return (lhs.createdAt ?? Date.distantFuture) < (rhs.createdAt ?? Date.distantFuture)
                }
            }

            let upcoming = upcomingCandidates.prefix(3).map { candidate in
                ProjectSummaryMetrics.UpcomingTask(title: candidate.title, dueDate: candidate.due)
            }

            let completion = total > 0 ? Double(completed) / Double(total) : 0
            let initials = project.memberIds.prefix(3).map { id -> String in
                let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return "?" }
                let letters = trimmed.prefix(2)
                return letters.uppercased()
            }

            let metrics = ProjectSummaryMetrics(
                completion: completion,
                remainingCount: remaining,
                upcomingTasks: Array(upcoming),
                lastUpdated: project.lastModifiedAt ?? project.createdAt,
                memberInitials: initials,
                memberCount: project.memberIds.count
            )

            return metrics
        } catch {
            print("❌ ProjectMetricsService error: \(error)")
            return nil
        }
    }
}

