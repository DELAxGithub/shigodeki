import Foundation
import FirebaseAuth

// MARK: - Create Project Service

class CreateProjectService: ObservableObject {
    private let authManager = AuthenticationManager.shared
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    func createInitialTasksFromAI(_ aiTasks: [ShigodekiTask], for project: Project) async {
        guard let projectId = project.id, let userId = authManager.currentUser?.id else {
            print("⚠️ Cannot create AI tasks: missing project ID or user ID")
            return
        }
        
        do {
            // Create a default phase for AI-generated tasks
            let phaseManager = PhaseManager()
            let defaultPhase = try await phaseManager.createPhase(
                name: "初期タスク",
                description: "AI生成によるプロジェクトの初期タスク群",
                projectId: projectId,
                createdBy: userId,
                order: 0
            )
            
            guard let phaseId = defaultPhase.id else {
                print("⚠️ Failed to create default phase for AI tasks")
                return
            }
            
            // Create a default task list within the phase
            let taskListManager = TaskListManager()
            let defaultTaskList = try await taskListManager.createTaskList(
                name: "AI生成タスク",
                phaseId: phaseId,
                projectId: projectId,
                createdBy: userId,
                color: .blue,
                order: 0
            )
            
            guard let taskListId = defaultTaskList.id else {
                print("⚠️ Failed to create default task list for AI tasks")
                return
            }
            
            // Create each AI-generated task in the task list
            let enhancedTaskManager = EnhancedTaskManager()
            var createdCount = 0
            
            for (index, aiTask) in aiTasks.enumerated() {
                do {
                    _ = try await enhancedTaskManager.createTask(
                        title: aiTask.title,
                        description: aiTask.description,
                        assignedTo: nil, // No initial assignment
                        createdBy: userId,
                        dueDate: aiTask.dueDate,
                        priority: aiTask.priority,
                        listId: taskListId,
                        phaseId: phaseId,
                        projectId: projectId,
                        order: index
                    )
                    createdCount += 1
                } catch {
                    print("⚠️ Failed to create AI task '\(aiTask.title)': \(error)")
                }
            }
            
            print("✅ Successfully created \(createdCount)/\(aiTasks.count) AI-generated tasks")
            
        } catch {
            print("❌ Failed to set up AI task infrastructure: \(error)")
        }
    }
    
    func validateProjectCreation(
        name: String,
        selectedOwnerType: ProjectOwnerType,
        selectedFamilyId: String?,
        selectedCreationMethod: CreateProjectView.CreationMethod,
        selectedTemplate: ProjectTemplate?,
        aiPrompt: String,
        selectedProjectType: ProjectType?,
        familyManager: FamilyManager
    ) -> (isValid: Bool, reason: String?) {
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (false, "プロジェクト名を入力してください")
        }
        
        if selectedOwnerType == .family {
            if familyManager.families.isEmpty {
                return (false, "家族グループが見つかりません")
            }
            if selectedFamilyId == nil {
                return (false, "家族グループを選択してください")
            }
        }
        
        switch selectedCreationMethod {
        case .template:
            if selectedTemplate == nil {
                return (false, "テンプレートを選択してください")
            }
        case .ai:
            if aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (false, "AI生成の内容を入力してください")
            }
            if selectedProjectType == nil {
                return (false, "プロジェクトタイプを選択してください")
            }
        case .scratch, .file:
            break // No additional validation needed
        }
        
        return (true, nil)
    }
}