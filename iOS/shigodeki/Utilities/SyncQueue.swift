//
//  SyncQueue.swift
//  shigodeki
//
//  Minimal queued ops for Phase 2. Handles confirming creates and compensating deletes
//  with simple exponential backoff. Idempotent by design.
//

import Foundation
import FirebaseFirestore

enum SyncStatus: String {
    case pending
    case confirmed
}

enum SyncOp: Equatable {
    case confirmPhaseCreate(projectId: String, phaseId: String, listId: String, taskId: String)
    case deletePhaseTask(projectId: String, phaseId: String, listId: String, taskId: String)
}

extension SyncOp: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .confirmPhaseCreate(projectId, phaseId, listId, taskId):
            hasher.combine(0)
            hasher.combine(projectId)
            hasher.combine(phaseId)
            hasher.combine(listId)
            hasher.combine(taskId)
        case let .deletePhaseTask(projectId, phaseId, listId, taskId):
            hasher.combine(1)
            hasher.combine(projectId)
            hasher.combine(phaseId)
            hasher.combine(listId)
            hasher.combine(taskId)
        }
    }
}

actor SyncQueue {
    static let shared = SyncQueue()

    private var queue: [SyncOp] = []
    private var isRunning = false
    private let db = Firestore.firestore()
    private var pendingOps = Set<SyncOp>()

    @discardableResult
    func enqueue(_ op: SyncOp) -> Bool {
        guard pendingOps.contains(op) == false else { return false }

        queue.append(op)
        pendingOps.insert(op)
        Telemetry.fire(.onSyncQueued, TelemetryPayload(screen: "SyncQueue"))
        if !isRunning {
            Task { await run() }
        }
        return true
    }

    /// Cancel a pending confirm op for a specific task to reduce flicker when Undo is invoked immediately.
    func cancelConfirm(projectId: String, phaseId: String, listId: String, taskId: String) {
        let target = SyncOp.confirmPhaseCreate(projectId: projectId, phaseId: phaseId, listId: listId, taskId: taskId)
        queue.removeAll { $0 == target }
        pendingOps.remove(target)
    }

    private func run() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        var backoff: TimeInterval = 1
        while !queue.isEmpty {
            let op = queue.removeFirst()
            pendingOps.remove(op)
            do {
                switch op {
                case let .confirmPhaseCreate(projectId, phaseId, listId, taskId):
                    let ref = db.collection("projects").document(projectId)
                        .collection("phases").document(phaseId)
                        .collection("lists").document(listId)
                        .collection("tasks").document(taskId)
                    try await ref.setData(["syncStatus": SyncStatus.confirmed.rawValue], merge: true)
                case let .deletePhaseTask(projectId, phaseId, listId, taskId):
                    let ref = db.collection("projects").document(projectId)
                        .collection("phases").document(phaseId)
                        .collection("lists").document(listId)
                        .collection("tasks").document(taskId)
                    // Idempotent: ignore if already gone
                    _ = try? await ref.getDocument()
                    try await ref.delete()
                }
                Telemetry.fire(.onSyncSucceeded, TelemetryPayload(screen: "SyncQueue"))
                backoff = 1
            } catch {
                Telemetry.fire(.onSyncFailed, TelemetryPayload(screen: "SyncQueue"))
                // Requeue and backoff
                queue.insert(op, at: 0)
                pendingOps.insert(op)
                let ns = UInt64(backoff * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                backoff = min(backoff * 2, 60)
            }
        }
    }
}
