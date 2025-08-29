//
//  PhaseListView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI
import FirebaseFirestore

struct PhaseListView: View {
    let project: Project
    @ObservedObject var phaseManager: PhaseManager
    @StateObject private var taskListManager = TaskListManager()
    @StateObject private var authManager = AuthenticationManager()
    @State private var showingCreatePhase = false
    @State private var selectedPhase: Phase?
    
    var body: some View {
        VStack {
            if phaseManager.phases.isEmpty && !phaseManager.isLoading {
                // Empty phases state
                VStack(spacing: 24) {
                    Image(systemName: "list.number")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 8) {
                        Text("フェーズがありません")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("プロジェクトを段階的に進めるため\nフェーズを作成しましょう")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        showingCreatePhase = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("フェーズを作成")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                .padding()
                
            } else {
                List {
                    ForEach(phaseManager.phases) { phase in
                        NavigationLink(
                            destination: PhaseTaskListView(phase: phase, project: project, taskListManager: taskListManager),
                            tag: phase,
                            selection: $selectedPhase
                        ) {
                            PhaseRowView(phase: phase, phaseManager: phaseManager)
                        }
                    }
                    .onMove(perform: movePhases)
                    .onDelete(perform: deletePhases)
                }
                .refreshable {
                    await loadPhases()
                }
            }
            
            if phaseManager.isLoading {
                ProgressView("読み込み中...")
                    .padding()
            }
        }
        .navigationTitle("フェーズ")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreatePhase = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            loadPhases()
            startListeningToPhases()
        }
        .onDisappear {
            phaseManager.removeAllListeners()
        }
        .sheet(isPresented: $showingCreatePhase) {
            CreatePhaseView(project: project, phaseManager: phaseManager)
        }
        .alert("エラー", isPresented: .constant(phaseManager.error != nil)) {
            Button("OK") {
                phaseManager.error = nil
            }
        } message: {
            Text(phaseManager.error?.localizedDescription ?? "")
        }
    }
    
    private func loadPhases() {
        guard let projectId = project.id else { return }
        
        Task {
            do {
                _ = try await phaseManager.getPhases(projectId: projectId)
            } catch {
                print("Error loading phases: \(error)")
            }
        }
    }
    
    private func startListeningToPhases() {
        guard let projectId = project.id else { return }
        phaseManager.startListeningForPhases(projectId: projectId)
    }
    
    private func movePhases(from source: IndexSet, to destination: Int) {
        var reorderedPhases = phaseManager.phases
        reorderedPhases.move(fromOffsets: source, toOffset: destination)
        
        guard let projectId = project.id else { return }
        
        Task {
            do {
                try await phaseManager.reorderPhases(reorderedPhases, projectId: projectId)
            } catch {
                print("Error reordering phases: \(error)")
            }
        }
    }
    
    private func deletePhases(at offsets: IndexSet) {
        guard let projectId = project.id else { return }
        
        for index in offsets {
            let phase = phaseManager.phases[index]
            guard let phaseId = phase.id else { continue }
            
            Task {
                do {
                    try await phaseManager.deletePhase(id: phaseId, projectId: projectId)
                } catch {
                    print("Error deleting phase: \(error)")
                }
            }
        }
    }
}

// MARK: - Phase Task List View

struct PhaseTaskListView: View {
    let phase: Phase
    let project: Project
    @ObservedObject var taskListManager: TaskListManager
    @StateObject private var authManager = AuthenticationManager()
    @State private var showingCreateTaskList = false
    
    var body: some View {
        VStack {
            if taskListManager.taskLists.isEmpty && !taskListManager.isLoading {
                // Empty task lists state
                VStack(spacing: 24) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 8) {
                        Text("タスクリストがありません")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("このフェーズのタスクを管理するため\nタスクリストを作成しましょう")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        showingCreateTaskList = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("タスクリストを作成")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                .padding()
                
            } else {
                List {
                    ForEach(taskListManager.taskLists) { taskList in
                        NavigationLink(destination: TaskListDetailView(taskList: taskList, phase: phase, project: project)) {
                            PhaseTaskListRowView(taskList: taskList)
                        }
                    }
                }
                .refreshable {
                    guard let phaseId = phase.id, let projectId = project.id else { return }
                    await loadTaskLists(phaseId: phaseId, projectId: projectId)
                }
            }
            
            if taskListManager.isLoading {
                ProgressView("読み込み中...")
                    .padding()
            }
        }
        .navigationTitle(phase.name)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreateTaskList = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            guard let phaseId = phase.id, let projectId = project.id else { return }
            Task {
                await loadTaskLists(phaseId: phaseId, projectId: projectId)
            }
        }
        .sheet(isPresented: $showingCreateTaskList) {
            CreatePhaseTaskListView(phase: phase, project: project, taskListManager: taskListManager)
        }
    }
    
    private func loadTaskLists(phaseId: String, projectId: String) async {
        do {
            _ = try await taskListManager.getTaskLists(phaseId: phaseId, projectId: projectId)
        } catch {
            print("Error loading task lists: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct PhaseTaskListRowView: View {
    let taskList: TaskList
    
    var body: some View {
        HStack {
            Circle()
                .fill(taskList.color.swiftUIColor)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(taskList.name)
                    .font(.headline)
                
                Text("0個のタスク") // TODO: Get actual task count
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct TaskListDetailView: View {
    let taskList: TaskList
    let phase: Phase
    let project: Project
    @StateObject private var taskManager = TaskManager()
    @StateObject private var authManager = AuthenticationManager()
    @State private var showingCreateTask = false
    
    var body: some View {
        VStack {
            if let tasks = taskManager.tasks[taskList.id ?? ""], !tasks.isEmpty {
                List {
                    ForEach(tasks) { task in
                        HStack {
                            Circle()
                                .fill(task.priority.swiftUIColor)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading) {
                                Text(task.title)
                                    .font(.headline)
                                if let description = task.description, !description.isEmpty {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("タスクがありません")
                        .font(.title3)
                    Button("タスクを追加") {
                        showingCreateTask = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle(taskList.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("追加") {
                    showingCreateTask = true
                }
            }
        }
        .onAppear {
            loadTasks()
        }
        .sheet(isPresented: $showingCreateTask) {
            CreatePhaseTaskView(
                taskList: taskList,
                phase: phase, 
                project: project,
                taskManager: taskManager
            )
        }
    }
    
    private func loadTasks() {
        guard let taskListId = taskList.id,
              let phaseId = phase.id,
              let projectId = project.id else { return }
        
        Task {
            do {
                let tasks = try await loadPhaseTasksFromFirestore(
                    projectId: projectId,
                    phaseId: phaseId,
                    taskListId: taskListId
                )
                
                await MainActor.run {
                    taskManager.tasks[taskListId] = tasks
                }
            } catch {
                print("Error loading phase tasks: \(error)")
            }
        }
    }
    
    private func loadPhaseTasksFromFirestore(projectId: String, phaseId: String, taskListId: String) async throws -> [ShigodekiTask] {
        let db = Firestore.firestore()
        let tasksCollection = db.collection("projects").document(projectId)
            .collection("phases").document(phaseId)
            .collection("lists").document(taskListId)
            .collection("tasks")
        
        let snapshot = try await tasksCollection.getDocuments()
        
        return try snapshot.documents.compactMap { document in
            let data = document.data()
            
            var task = ShigodekiTask(
                title: data["title"] as? String ?? "",
                description: data["description"] as? String,
                assignedTo: data["assignedTo"] as? String,
                createdBy: data["createdBy"] as? String ?? "",
                dueDate: (data["dueDate"] as? Timestamp)?.dateValue(),
                priority: TaskPriority(rawValue: data["priority"] as? String ?? "medium") ?? .medium
            )
            
            task.id = document.documentID
            task.isCompleted = data["isCompleted"] as? Bool ?? false
            task.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
            task.completedAt = (data["completedAt"] as? Timestamp)?.dateValue()
            
            return task
        }
    }
}

struct CreatePhaseTaskListView: View {
    let phase: Phase
    let project: Project
    @ObservedObject var taskListManager: TaskListManager
    @Environment(\.presentationMode) var presentationMode
    @State private var taskListName = ""
    @State private var selectedColor: TaskListColor = .blue
    
    var body: some View {
        NavigationView {
            Form {
                TextField("タスクリスト名", text: $taskListName)
                
                Section("色") {
                    ColorSelectionGrid(selectedColor: $selectedColor)
                }
            }
            .navigationTitle("新しいタスクリスト")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createTaskList()
                    }
                    .disabled(taskListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func createTaskList() {
        // TODO: Implement task list creation with new architecture
        presentationMode.wrappedValue.dismiss()
    }
}

struct ColorSelectionGrid: View {
    @Binding var selectedColor: TaskListColor
    
    var body: some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 4)
        LazyVGrid(columns: columns) {
            ForEach(TaskListColor.allCases, id: \.self) { color in
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                    )
                    .onTapGesture {
                        selectedColor = color
                    }
            }
        }
    }
}

struct CreatePhaseTaskView: View {
    let taskList: TaskList
    let phase: Phase
    let project: Project
    @ObservedObject var taskManager: TaskManager
    @StateObject private var authManager = AuthenticationManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var taskTitle: String = ""
    @State private var taskDescription: String = ""
    @State private var selectedPriority: TaskPriority = .medium
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("タスク詳細")) {
                    TextField("タスクタイトル", text: $taskTitle)
                    TextField("説明（オプション）", text: $taskDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("優先度")) {
                    Picker("優先度", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(priority.swiftUIColor)
                                    .frame(width: 12, height: 12)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            .navigationTitle("新しいタスク")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createTask()
                    }
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createTask() {
        guard let userId = authManager.currentUser?.id,
              let taskListId = taskList.id,
              let phaseId = phase.id,
              let projectId = project.id else { return }
        
        isCreating = true
        
        Task {
            do {
                _ = try await taskManager.createPhaseTask(
                    title: taskTitle,
                    description: taskDescription.isEmpty ? nil : taskDescription,
                    taskListId: taskListId,
                    projectId: projectId,
                    phaseId: phaseId,
                    creatorUserId: userId,
                    priority: selectedPriority
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error creating task: \(error)")
                isCreating = false
            }
        }
    }
}

#Preview {
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    PhaseListView(project: sampleProject, phaseManager: PhaseManager())
}