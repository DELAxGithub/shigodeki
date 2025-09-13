//
//  CreateTaskView.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - UI components extracted
//  Core view structure for task creation form
//

import SwiftUI

struct CreateTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedPriority: TaskPriority = .medium
    @State private var selectedAssignee: String?
    @State private var dueDate: Date = Date()
    @State private var hasDueDate: Bool = false
    @State private var selectedTags: [String] = []
    @State private var keepAttachment: Bool = false
    @State private var attachments: [String] = [] // base64 data URLs or remote URLs
    
    // Services
    @StateObject private var tagManager = TagManager()
    @StateObject private var creationService: TaskCreationService
    
    let taskList: TaskList
    let family: Family
    let creatorUserId: String
    let familyMembers: [User]
    
    init(
        taskList: TaskList,
        family: Family,
        taskManager: TaskManager,
        creatorUserId: String,
        familyMembers: [User]
    ) {
        self.taskList = taskList
        self.family = family
        self.creatorUserId = creatorUserId
        self.familyMembers = familyMembers
        
        // Initialize service with dependencies
        self._creationService = StateObject(
            wrappedValue: TaskCreationService(
                taskManager: taskManager,
                tagManager: TagManager()
            )
        )
    }
    
    var body: some View {
        NavigationView {
            CreateTaskFormContent(
                title: $title,
                description: $description,
                selectedPriority: $selectedPriority,
                selectedAssignee: $selectedAssignee,
                dueDate: $dueDate,
                hasDueDate: $hasDueDate,
                selectedTags: $selectedTags,
                keepAttachment: $keepAttachment,
                attachments: $attachments,
                taskList: taskList,
                familyMembers: familyMembers,
                creatorUserId: creatorUserId,
                tagManager: tagManager,
                isCreating: creationService.isCreating,
                onCreateTask: createTask,
                onCancel: { dismiss() }
            )
            .navigationTitle("タスク作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .alert("タスク作成完了", isPresented: $creationService.showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("タスク「\(title)」が作成されました。")
        }
        .alert("エラー", isPresented: Binding<Bool>(
            get: { creationService.errorMessage != nil },
            set: { _ in creationService.errorMessage = nil }
        )) {
            Button("OK") {}
        } message: {
            Text(creationService.errorMessage ?? "")
        }
        .task {
            await creationService.loadTags(projectId: taskList.projectId)
        }
        .onDisappear {
            creationService.stopTagListening()
        }
    }
    
    private func createTask() {
        Task {
            await creationService.createTask(
                title: title,
                description: description,
                taskList: taskList,
                family: family,
                creatorUserId: creatorUserId,
                selectedAssignee: selectedAssignee,
                dueDate: dueDate,
                hasDueDate: hasDueDate,
                selectedPriority: selectedPriority,
                selectedTags: selectedTags,
                attachments: keepAttachment ? attachments : []
            )
        }
    }
}

#Preview {
    CreateTaskView(
        taskList: TaskList(name: "サンプルタスクリスト", familyId: "family1", createdBy: "user1"),
        family: Family(name: "サンプルチーム", members: ["user1", "user2"]),
        taskManager: TaskManager(),
        creatorUserId: "user1",
        familyMembers: [
            User(name: "太郎", email: "taro@example.com"),
            User(name: "花子", email: "hanako@example.com")
        ]
    )
}
