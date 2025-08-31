//
//  LegacyDataBridge.swift
//  shigodeki
//
//  Small helper to isolate legacy list->section flatten logic
//

import Foundation

enum LegacyDataBridge {
    /// Loads legacy list-based tasks under a phase and flattens them into section-assigned tasks
    static func flattenLegacyTasks(phaseId: String, projectId: String) async throws -> [ShigodekiTask] {
        let listManager = await SharedManagerStore.shared.getTaskListManager()
        let lists = try await listManager.getTaskLists(phaseId: phaseId, projectId: projectId)
        var merged: [ShigodekiTask] = []
        for list in lists {
            guard let lid = list.id else { continue }
            let snapshotTasks = try await EnhancedTaskManager().getTasks(listId: lid, phaseId: phaseId, projectId: projectId)
            for var t in snapshotTasks {
                t.sectionId = lid
                t.sectionName = list.name
                merged.append(t)
            }
        }
        return merged.sorted { $0.order < $1.order }
    }
}

