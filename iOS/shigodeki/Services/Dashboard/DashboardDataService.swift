//
//  DashboardDataService.swift
//  shigodeki
//
//  Provides lightweight aggregation queries for the dashboard without
//  attaching long-lived listeners. Results are cached briefly to avoid
//  redundant Firestore work when the dashboard reappears.
//

import Foundation
import FirebaseFirestore

struct DashboardTaskRecord: Identifiable, Equatable {
    let task: ShigodekiTask
    var id: String { task.id ?? UUID().uuidString }

    var dueDate: Date? { task.dueDate }
    var isOverdue: Bool { task.isOverdue }
}

actor DashboardDataService {
    private let db = Firestore.firestore()

    func fetchAssignedTasks(for userId: String, limit: Int = 20) async throws -> [DashboardTaskRecord] {
        guard !userId.isEmpty else { return [] }

        async let direct = fetchRecords(for: userId, field: "assignedTo", limit: limit)
        async let legacy = fetchRecords(for: userId, field: "assigneeId", limit: limit)

        let (directRecords, legacyRecords) = try await (direct, legacy)

        // Deduplicate by task id
        var merged: [String: DashboardTaskRecord] = [:]
        for record in directRecords + legacyRecords {
            if let id = record.task.id {
                merged[id] = record
            }
        }

        var result = Array(merged.values)
        result.sort { lhs, rhs in
            let lhsDue = lhs.task.dueDate ?? lhs.task.createdAt ?? Date.distantFuture
            let rhsDue = rhs.task.dueDate ?? rhs.task.createdAt ?? Date.distantFuture
            if lhsDue == rhsDue {
                return lhs.task.priority.rawValue > rhs.task.priority.rawValue
            }
            return lhsDue < rhsDue
        }

        if result.count > limit {
            result = Array(result.prefix(limit))
        }

        #if DEBUG
        print("📊 DashboardDataService: fetched \(result.count) assigned tasks for user \(userId)")
        #endif

        return result
    }

    func clearCache() {
    }

    private func fetchRecords(for userId: String, field: String, limit: Int) async throws -> [DashboardTaskRecord] {
        let query: Query = db.collectionGroup("tasks")
            .whereField(field, isEqualTo: userId)
            .whereField("isCompleted", isEqualTo: false)

        do {
            let records = try await runQuery(query)
            #if DEBUG
            print("📥 DashboardDataService: field=\(field) hit count=\(records.count)")
            #endif
            return records
        } catch {
            #if DEBUG
            print("⚠️ DashboardDataService: query for field \(field) failed: \(error)")
            #endif
            return []
        }
    }

    private func runQuery(_ query: Query) async throws -> [DashboardTaskRecord] {
        do {
            let snapshot = try await query.getDocuments()
            let decoder = Firestore.Decoder()
            return snapshot.documents.compactMap { document in
                do {
                    var task = try decoder.decode(ShigodekiTask.self, from: document.data())
                    if task.id == nil {
                        task.id = document.documentID
                    }
                    return DashboardTaskRecord(task: task)
                } catch {
                    #if DEBUG
                    print("⚠️ DashboardDataService: Failed to decode task \(document.documentID): \(error)")
                    #endif
                    return nil
                }
            }
        } catch {
            #if DEBUG
            print("⚠️ DashboardDataService: query failed for \(query) with error \(error)")
            #endif
            throw error
        }
    }
}
