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
    
    @StateObject private var authManager = AuthenticationManager()
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
            // Task List Info
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(taskList.color.swiftUIColor)
                            .frame(width: 20, height: 20)
                        
                        Text(taskList.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("\(tasks.count)個のタスク")
                        Text("•")
                        Text("\(completedTasks.count)個完了")
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // Pending Tasks
            if !pendingTasks.isEmpty {
                Section("未完了 (\(pendingTasks.count))") {
                    ForEach(pendingTasks) { task in
                        TaskRowView(
                            task: task,
                            taskList: taskList,
                            family: family,
                            taskManager: taskManager,
                            familyMembers: familyMembers
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
            }
            
            // Completed Tasks
            if !completedTasks.isEmpty {
                Section("完了 (\(completedTasks.count))") {
                    ForEach(completedTasks) { task in
                        TaskRowView(
                            task: task,
                            taskList: taskList,
                            family: family,
                            taskManager: taskManager,
                            familyMembers: familyMembers
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
            }
            
            // Empty state for no tasks
            if tasks.isEmpty && !taskManager.isLoading {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "checklist")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("タスクがありません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("新しいタスクを作成してみましょう")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            showingCreateTask = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("タスクを作成")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            }
        }
        .navigationTitle(taskList.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // AI Assistant Button
                Button(action: {
                    if aiGenerator.availableProviders.isEmpty {
                        showingAISettings = true
                    } else {
                        showingAIAssistant = true
                    }
                }) {
                    Image(systemName: "brain")
                        .foregroundColor(.blue)
                }
                .help("AI タスク提案")
                
                // Add Task Button
                Button(action: {
                    showingCreateTask = true
                }) {
                    Image(systemName: "plus")
                }
                .help("新しいタスクを作成")
            }
        }
        .onAppear {
            loadData()
        }
        .refreshable {
            await loadData()
        }
        .sheet(isPresented: $showingCreateTask) {
            if let userId = authManager.currentUser?.id {
                CreateTaskView(
                    taskList: taskList,
                    family: family,
                    taskManager: taskManager,
                    creatorUserId: userId,
                    familyMembers: familyMembers
                )
            }
        }
        .sheet(isPresented: $showingAIAssistant) {
            TaskAIAssistantView(
                taskList: taskList,
                existingTasks: tasks,
                aiGenerator: aiGenerator,
                onTasksGenerated: { generatedTasks in
                    // Handle generated tasks by saving them to the database
                    print("Generated \(generatedTasks.count) tasks")
                    
                    Task {
                        for generatedTask in generatedTasks {
                            do {
                                // Create task with proper IDs
                                let newTask = ShigodekiTask(
                                    title: generatedTask.title,
                                    description: generatedTask.description,
                                    assignedTo: generatedTask.assignedTo,
                                    createdBy: generatedTask.createdBy,
                                    dueDate: generatedTask.dueDate,
                                    priority: generatedTask.priority,
                                    listId: taskList.id ?? "",
                                    phaseId: generatedTask.phaseId,
                                    projectId: generatedTask.projectId,
                                    order: tasks.count + (generatedTasks.firstIndex(of: generatedTask) ?? 0)
                                )
                                
                                // Save to database
                                guard let taskListId = taskList.id,
                                      let familyId = family.id else { 
                                    print("Error: Missing required IDs")
                                    continue 
                                }
                                
                                try await taskManager.createTask(
                                    title: newTask.title,
                                    description: newTask.description,
                                    taskListId: taskListId,
                                    familyId: familyId,
                                    creatorUserId: newTask.createdBy,
                                    assignedTo: newTask.assignedTo,
                                    dueDate: newTask.dueDate,
                                    priority: newTask.priority
                                )
                                
                                print("✅ Successfully created AI task: \(newTask.title)")
                                
                            } catch {
                                print("❌ Error saving AI task: \(error)")
                            }
                        }
                        
                        // Refresh the task list to show new tasks
                        await MainActor.run {
                            loadData()
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showingAISettings) {
            APISettingsView()
                .onDisappear {
                    aiGenerator.updateAvailableProviders()
                }
        }
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
        
        Task.detached {
            do {
                let db = Firestore.firestore()
                var members: [User] = []
                
                for memberId in family.members {
                    let userDoc = try await db.collection("users").document(memberId).getDocument()
                    if let userData = userDoc.data() {
                        var user = User(
                            name: userData["name"] as? String ?? "Unknown",
                            email: userData["email"] as? String ?? "",
                            familyIds: userData["familyIds"] as? [String] ?? []
                        )
                        user.id = memberId
                        user.createdAt = (userData["createdAt"] as? Timestamp)?.dateValue()
                        members.append(user)
                    }
                }
                
                await MainActor.run {
                    familyMembers = members
                    isLoadingMembers = false
                }
                
            } catch {
                await MainActor.run {
                    isLoadingMembers = false
                }
                print("Error loading family members: \(error)")
            }
        }
    }
}

struct TaskRowView: View {
    let task: ShigodekiTask
    let taskList: TaskList
    let family: Family
    let taskManager: TaskManager
    let familyMembers: [User]
    
    private var assignedMember: User? {
        guard let assignedTo = task.assignedTo else { return nil }
        return familyMembers.first { $0.id == assignedTo }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion button
            Button(action: {
                toggleCompletion()
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .scaleEffect(task.isCompleted ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: task.isCompleted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "完了したタスク" : "未完了のタスク")
            .accessibilityHint(task.isCompleted ? "タップして未完了にします" : "タップして完了にします")
            
            VStack(alignment: .leading, spacing: 4) {
                // Task title
                HStack {
                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
                        .accessibilityLabel("タスク: \(task.title)")
                    
                    Spacer()
                    
                    // Priority indicator
                    Circle()
                        .fill(task.priority.swiftUIColor)
                        .frame(width: 8, height: 8)
                }
                
                // Task description
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Task metadata
                HStack {
                    // Assigned member
                    if let assignedMember = assignedMember {
                        HStack(spacing: 4) {
                            Image(systemName: "person")
                                .font(.caption)
                            Text(assignedMember.name)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    // Due date
                    if let dueDate = task.dueDateFormatted {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text(dueDate)
                        }
                        .font(.caption)
                        .foregroundColor(task.isOverdue ? .red : .secondary)
                    }
                    
                    Spacer()
                    
                    // Completion date
                    if task.isCompleted, let completedAt = task.completedAt {
                        Text("完了: \(DateFormatter.taskDateTime.string(from: completedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func toggleCompletion() {
        guard let taskId = task.id,
              let taskListId = taskList.id,
              let familyId = family.id else { return }
        
        // Haptic feedback based on completion state
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        let notificationFeedback = UINotificationFeedbackGenerator()
        
        if task.isCompleted {
            impactFeedback.impactOccurred()
        } else {
            notificationFeedback.notificationOccurred(.success)
        }
        
        Task {
            do {
                try await taskManager.toggleTaskCompletion(
                    taskId: taskId,
                    taskListId: taskListId,
                    familyId: familyId
                )
            } catch {
                print("Error toggling task completion: \(error)")
                // Error feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
}

#Preview {
    TaskDetailView(
        taskList: TaskList(name: "サンプルタスクリスト", familyId: "family1", createdBy: "user1"),
        family: Family(name: "サンプル家族", members: ["user1", "user2"]),
        taskManager: TaskManager()
    )
}