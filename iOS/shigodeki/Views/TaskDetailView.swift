//
//  TaskDetailView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI
import FirebaseFirestore

struct TaskDetailView: View {
    let taskList: TaskList
    let family: Family
    @ObservedObject var taskManager: TaskManager
    
    @ObservedObject private var authManager = AuthenticationManager.shared
    @StateObject private var aiGenerator = AITaskGenerator()
    @State private var familyMembers: [User] = []
    @State private var isLoadingMembers = false
    @State private var showingCreateTask = false
    @State private var showingAIAssistant = false
    @State private var showingAISettings = false
    
    private var tasks: [ShigodekiTask] {
        taskManager.tasks[taskList.id!] ?? []
    }
    
    private var completedTasks: [ShigodekiTask] {
        tasks.filter { $0.isCompleted }
    }
    
    private var pendingTasks: [ShigodekiTask] {
        tasks.filter { !$0.isCompleted }
    }
    
    var body: some View {
        List {
            TaskListInfoSection(
                taskList: taskList,
                tasks: tasks,
                completedTasks: completedTasks
            )
            
            TaskListContentSection(
                pendingTasks: pendingTasks,
                completedTasks: completedTasks,
                taskList: taskList,
                family: family,
                taskManager: taskManager,
                familyMembers: familyMembers,
                isLoading: taskManager.isLoading,
                onCreateTask: { showingCreateTask = true }
            )
        }
        .navigationTitle(taskList.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            TaskDetailToolbar(
                aiGenerator: aiGenerator,
                onShowAIAssistant: { showingAIAssistant = true },
                onShowAISettings: { showingAISettings = true },
                onCreateTask: { showingCreateTask = true }
            )
        }
        .onAppear {
            loadData()
        }
        .refreshable {
            loadData()
        }
        .taskDetailSheets(
            taskList: taskList,
            family: family,
            taskManager: taskManager,
            authManager: authManager,
            aiGenerator: aiGenerator,
            familyMembers: familyMembers,
            tasks: tasks,
            showingCreateTask: $showingCreateTask,
            showingAIAssistant: $showingAIAssistant,
            showingAISettings: $showingAISettings,
            onDataLoad: loadData
        )
    }
    
    private func loadData() {
        guard let taskListId = taskList.id, let familyId = family.id else { return }
        
        // Load tasks
        Task.detached {
            await taskManager.loadTasks(taskListId: taskListId, familyId: familyId)
            await MainActor.run {
                taskManager.startListeningToTasks(taskListId: taskListId, familyId: familyId)
            }
        }
        
        // Load family members
        loadFamilyMembers()
    }
    
    private func loadFamilyMembers() {
        isLoadingMembers = true
        
        Task {
            do {
                let db = Firestore.firestore()
                let ids = family.members
                let fetched: [User] = try await withThrowingTaskGroup(of: User?.self) { group in
                    for memberId in ids {
                        group.addTask {
                            let userDoc = try? await db.collection("users").document(memberId).getDocument()
                            guard let data = userDoc?.data() else { return nil }
                            var user = User(
                                name: data["name"] as? String ?? "Unknown",
                                email: data["email"] as? String ?? "",
                                familyIds: data["familyIds"] as? [String] ?? []
                            )
                            user.id = memberId
                            user.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                            return user
                        }
                    }
                    var collected: [User] = []
                    for try await result in group {
                        if let u = result { collected.append(u) }
                    }
                    return collected
                }
                await MainActor.run {
                    familyMembers = fetched
                    isLoadingMembers = false
                }
            } catch {
                await MainActor.run { isLoadingMembers = false }
                print("Error loading family members: \(error)")
            }
        }
    }
}


#Preview {
    TaskDetailView(
        taskList: TaskList(name: "サンプルタスクリスト", familyId: "family1", createdBy: "user1"),
        family: Family(name: "サンプルチーム", members: ["user1", "user2"]),
        taskManager: TaskManager()
    )
}
