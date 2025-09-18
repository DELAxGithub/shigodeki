import SwiftUI

struct AIDraftFlowView: View {
    let taskList: TaskList
    let project: Project?
    let phase: Phase?
    let existingTasks: [ShigodekiTask]
    @ObservedObject var aiGenerator: AITaskGenerator
    let onPreviewDrafts: ([TaskDraft], TaskDraftSource) -> Void
    let onDirectSave: ([ShigodekiTask]) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TaskAIAssistantView(
            taskList: taskList,
            existingTasks: existingTasks,
            aiGenerator: aiGenerator,
            onTasksGenerated: { tasks in
                onDirectSave(tasks)
                dismiss()
            },
            onPreviewDrafts: { drafts, source in
                onPreviewDrafts(drafts, source)
            },
            project: project,
            phase: phase
        )
    }
}

#Preview {
    AIDraftFlowView(
        taskList: TaskList(name: "Sample", familyId: "fam", createdBy: "user"),
        project: Project(name: "Sample Project", ownerId: "user"),
        phase: Phase(name: "フェーズ", projectId: "proj", createdBy: "user", order: 0),
        existingTasks: [],
        aiGenerator: AITaskGenerator(),
        onPreviewDrafts: { _, _ in },
        onDirectSave: { _ in }
    )
}
