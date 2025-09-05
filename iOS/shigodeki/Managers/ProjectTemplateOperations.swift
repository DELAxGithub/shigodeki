//
//  ProjectTemplateOperations.swift
//  shigodeki
//
//  Extracted from ProjectManager.swift for better code organization
//

import Foundation
import FirebaseFirestore

/// Handles all project template-related operations
@MainActor
class ProjectTemplateOperations: ObservableObject {
    @Published var templates: [ProjectTemplate] = []
    @Published var isLoadingTemplates = false
    @Published var error: FirebaseError?
    
    private let projectOperations = FirebaseOperationBase<Project>(collectionPath: "projects")
    private let templateImporter = TemplateImporter()
    private let templateExporter = TemplateExporter()
    
    // MARK: - Template Loading
    
    func loadBuiltInTemplates() async {
        isLoadingTemplates = true
        defer { isLoadingTemplates = false }
        
        // Load templates on background queue
        let builtInTemplates = BuiltInTemplates.allTemplates
        
        await MainActor.run {
            self.templates = builtInTemplates
            print("📚 Loaded \(builtInTemplates.count) built-in templates")
        }
    }
    
    // MARK: - Template Import/Export
    
    func createProjectFromTemplate(_ template: ProjectTemplate, 
                                  projectName: String? = nil,
                                  ownerId: String,
                                  ownerType: ProjectOwnerType = .individual,
                                  createdByUserId: String,
                                  customizations: ProjectCustomizations? = nil,
                                  onProjectCreated: @escaping (Project) async throws -> Project) async throws -> Project {
        print("🎯 Creating project from template: '\(template.name)'")
        isLoadingTemplates = true
        defer { isLoadingTemplates = false }
        
        do {
            // Import template and create project
            let finalProjectName = projectName ?? template.name
            let project = try await templateImporter.createProject(
                from: template,
                ownerId: ownerId,
                projectName: finalProjectName,
                customizations: customizations
            )
            
            // Create project in Firebase via callback
            var createdProject = try await onProjectCreated(project)
            
            // Pre-populate statistics immediately from template for faster UI feedback
            let phaseCount = template.phases.count
            let taskCount = template.phases.flatMap { $0.taskLists }.reduce(0) { acc, list in acc + list.tasks.count }
            var statsUpdatedProject = createdProject
            statsUpdatedProject.statistics = ProjectStats(totalTasks: taskCount, completedTasks: 0, totalPhases: phaseCount, activeMembers: 0)
            statsUpdatedProject.lastModifiedAt = Date()
            createdProject = try await updateProject(statsUpdatedProject)
            
            // Create phases, task lists, and tasks from template
            try await createProjectStructureFromTemplate(
                template: template,
                projectId: createdProject.id ?? "",
                ownerId: ownerId,
                customizations: customizations
            )
            
            print("🎉 Project created from template successfully!")
            return createdProject
        } catch {
            print("❌ Failed to create project from template: \(error)")
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    private func createProjectStructureFromTemplate(
        template: ProjectTemplate,
        projectId: String,
        ownerId: String,
        customizations: ProjectCustomizations? = nil
    ) async throws {
        let phaseManager = PhaseManager()
        _ = TaskListManager() // kept for export path elsewhere
        let taskManager = EnhancedTaskManager()
        let subtaskManager = SubtaskManager()
        var phaseCount = 0
        var listCount = 0
        var taskCount = 0
        var subtaskCount = 0
        
        // Create phases in order
        for phaseTemplate in template.phases.sorted(by: { $0.order < $1.order }) {
            let createdPhase = try await phaseManager.createPhase(
                name: phaseTemplate.title,
                description: phaseTemplate.description,
                projectId: projectId,
                createdBy: ownerId,
                order: phaseTemplate.order
            )
            guard let phaseId = createdPhase.id else { continue }
            phaseCount += 1
            print("🧱 Created phase: \(createdPhase.name) [\(phaseId)]")
            
            // Create sections for this phase and tasks under phase-level collection
            let sectionManager = PhaseSectionManager()
            for taskListTemplate in phaseTemplate.taskLists.sorted(by: { $0.order < $1.order }) {
                let sec = try await sectionManager.createSection(
                    name: taskListTemplate.name,
                    phaseId: phaseId,
                    projectId: projectId,
                    order: taskListTemplate.order,
                    colorHex: (customizations?.customPhaseColors[phaseTemplate.title]?.swiftUIColor.description)
                )
                listCount += 1
                print("📁 Created section: \(sec.name) [\(sec.id ?? "")] in phase \(phaseId)")
                for (taskIndex, taskTemplate) in taskListTemplate.tasks.enumerated() {
                    if taskTemplate.isOptional && (customizations?.skipOptionalTasks == true) { continue }
                    let priority = customizations?.taskPriorityOverrides[taskTemplate.title] ?? taskTemplate.priority
                    let createdTask = try await taskManager.createPhaseTask(
                        title: taskTemplate.title,
                        description: taskTemplate.description,
                        assignedTo: nil,
                        createdBy: ownerId,
                        dueDate: nil,
                        priority: priority,
                        sectionId: sec.id,
                        sectionName: sec.name,
                        phaseId: phaseId,
                        projectId: projectId,
                        order: taskIndex
                    )
                    guard let taskId = createdTask.id else { continue }
                    taskCount += 1
                    print("✅ Created task: \(createdTask.title) [\(taskId)] in section \(sec.id ?? "")")
                    for (subtaskIndex, subtaskTemplate) in taskTemplate.subtasks.enumerated() {
                        let createdSubtask = try await subtaskManager.createSubtask(
                            title: subtaskTemplate.title,
                            description: subtaskTemplate.description,
                            assignedTo: nil,
                            createdBy: ownerId,
                            dueDate: nil,
                            taskId: taskId,
                            listId: "",
                            phaseId: phaseId,
                            projectId: projectId,
                            order: subtaskIndex
                        )
                        subtaskCount += 1
                        print("• Created subtask: \(createdSubtask.title) [\(createdSubtask.id ?? "")] for task \(taskId)")
                    }
                }
            }
        }

        print("📈 Template creation summary → phases: \(phaseCount), lists: \(listCount), tasks: \(taskCount), subtasks: \(subtaskCount)")
        // 更新された統計情報をプロジェクトに保存
        let stats = ProjectStats(
            totalTasks: taskCount,
            completedTasks: 0,
            totalPhases: phaseCount,
            activeMembers: 1
        )
        do {
            try await updateProjectStatistics(projectId: projectId, stats: stats)
            print("🧮 Project statistics updated: phases=\(phaseCount), tasks=\(taskCount)")
        } catch {
            print("⚠️ Failed to update project statistics: \(error)")
        }
    }
    
    func exportProjectAsTemplate(_ project: Project) async throws -> ProjectTemplate {
        print("📤 Exporting project as template: '\(project.name)'")
        isLoadingTemplates = true
        defer { isLoadingTemplates = false }
        
        do {
            // Get all project components
            let phaseManager = PhaseManager()
            let taskListManager = TaskListManager()
            _ = EnhancedTaskManager()
            let subtaskManager = SubtaskManager()
            
            guard let projectId = project.id else {
                throw FirebaseError.operationFailed("Project ID is required for export")
            }
            
            let phases = try await phaseManager.getPhases(projectId: projectId)
            var taskLists: [String: [TaskList]] = [:]
            var tasks: [String: [ShigodekiTask]] = [:]
            var subtasks: [String: [Subtask]] = [:]
            
            // Collect all task lists, tasks, and subtasks
            for phase in phases {
                guard let phaseId = phase.id else { continue }
                let phaseLists = try await taskListManager.getTaskLists(phaseId: phaseId, projectId: projectId)
                taskLists[phaseId] = phaseLists
                
                for taskList in phaseLists {
                    guard let taskListId = taskList.id else { continue }
                    // Load tasks for this task list
                    let enhancedTaskManager = EnhancedTaskManager()
                    let listTasks = try await enhancedTaskManager.getTasks(
                        listId: taskListId, 
                        phaseId: phaseId, 
                        projectId: projectId
                    )
                    tasks[taskListId] = listTasks
                    
                    for task in listTasks {
                        guard let taskId = task.id else { continue }
                        let taskSubtasks = try await subtaskManager.getSubtasks(
                            taskId: taskId,
                            listId: taskListId,
                            phaseId: phaseId,
                            projectId: projectId
                        )
                        subtasks[taskId] = taskSubtasks
                    }
                }
            }
            
            // Export to template
            let template = try await templateExporter.exportProject(
                project,
                phases: phases,
                taskLists: taskLists,
                tasks: tasks,
                subtasks: subtasks,
                options: .default
            )
            
            print("✅ Project exported as template successfully!")
            return template
        } catch {
            print("❌ Failed to export project as template: \(error)")
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func importTemplateFromFile(url: URL) async throws -> ProjectTemplate {
        isLoadingTemplates = true
        defer { isLoadingTemplates = false }
        
        do {
            let result = try await templateImporter.importTemplateFromFile(url: url)
            return result.projectTemplate
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateProject(_ project: Project) async throws -> Project {
        try project.validate()
        return try await projectOperations.update(project)
    }
    
    private func updateProjectStatistics(projectId: String, stats: ProjectStats) async throws {
        guard var project = try await projectOperations.read(id: projectId) else {
            throw FirebaseError.documentNotFound
        }
        
        project.statistics = stats
        project.lastModifiedAt = Date()
        
        _ = try await updateProject(project)
    }
}