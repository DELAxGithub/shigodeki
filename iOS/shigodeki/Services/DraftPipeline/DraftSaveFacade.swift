//
//  DraftSaveFacade.swift
//  shigodeki
//
//  Unified entrypoint for TaskDraft → Preview → Save (+ undo) pipeline.
//

import SwiftUI
import UIKit

enum DraftPipelineError: Error {
    case unsupported
    case missingContext
}

struct DraftSaveContext {
    let listId: String
    let phaseId: String
    let projectId: String
    let createdBy: String
    let taskManager: EnhancedTaskManager
    let toastCenter: ToastCenter?
}

enum DraftSaveFacade {
    private static var activeContext: DraftSaveContext?

    @MainActor
    static func presentPreview(
        drafts: [TaskDraft],
        source: TaskDraftSource,
        from presenter: UIViewController,
        context: DraftSaveContext? = nil
    ) {
        guard FeatureFlags.unifiedPreviewEnabled else { return }
        guard drafts.isEmpty == false else { return }

        if let context { activeContext = context }
        guard activeContext != nil else { return }

        var hostingController: UIHostingController<TasksPreview>?
        let preview = TasksPreview(
            drafts: drafts,
            onAccept: { acceptedDrafts in
                Task { @MainActor in
                    do {
                        try await saveWithUndo(drafts: acceptedDrafts, source: source)
                        hostingController?.dismiss(animated: true)
                    } catch {
                        #if DEBUG
                        print("DraftSaveFacade.saveWithUndo failed: \(error)")
                        #endif
                        hostingController?.dismiss(animated: true)
                    }
                }
            },
            onCancel: {
                activeContext = nil
                hostingController?.dismiss(animated: true)
            }
        )

        let controller = UIHostingController(rootView: preview)
        hostingController = controller
        controller.modalPresentationStyle = .formSheet

        Telemetry.fire(
            .onPreviewShown,
            TelemetryPayload(screen: "TasksPreview", depth: drafts.count, previewSource: source.rawValue)
        )

        presenter.present(controller, animated: true)
    }

    @MainActor
    static func saveWithUndo(drafts: [TaskDraft], source: TaskDraftSource) async throws {
        guard var context = activeContext else { throw DraftPipelineError.missingContext }
        guard drafts.isEmpty == false else { return }

        defer { activeContext = nil }

        var createdTasks: [ShigodekiTask] = []
        for draft in drafts {
            let created = try await context.taskManager.createTask(
                title: draft.title,
                description: draft.rationale,
                assignedTo: draft.assignee,
                createdBy: context.createdBy,
                dueDate: draft.due,
                priority: draft.priority,
                listId: context.listId,
                phaseId: context.phaseId,
                projectId: context.projectId,
                order: nil
            )
            createdTasks.append(created)
        }

        let count = drafts.count
        let message = count == 1 ? "1件のタスクを追加しました" : "\(count)件のタスクを追加しました"
        context.toastCenter?.show(message) {
            let ids = createdTasks.compactMap { $0.id }
            guard ids.isEmpty == false else { return }
            Task { @MainActor in
                for id in ids {
                    do {
                        try await context.taskManager.deleteTask(
                            id: id,
                            listId: context.listId,
                            phaseId: context.phaseId,
                            projectId: context.projectId
                        )
                    } catch {
                        #if DEBUG
                        print("DraftSaveFacade undo failed: \(error)")
                        #endif
                    }
                }
                Telemetry.fire(
                    .onUndo,
                    TelemetryPayload(screen: "DraftPipeline", depth: ids.count, previewSource: source.rawValue)
                )
            }
        }

        Telemetry.fire(
            .onTaskAdded,
            TelemetryPayload(screen: "DraftPipeline", depth: count, previewSource: source.rawValue)
        )
    }
}
