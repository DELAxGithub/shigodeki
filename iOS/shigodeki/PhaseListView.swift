//
//  PhaseListView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

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
                .fill(Color(taskList.color.rawValue))
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
    
    var body: some View {
        VStack {
            Text("Task List Detail View")
            Text("TaskList: \(taskList.name)")
            Text("Phase: \(phase.name)")
            Text("Project: \(project.name)")
        }
        .navigationTitle(taskList.name)
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
                    .fill(Color(color.rawValue))
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

#Preview {
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    PhaseListView(project: sampleProject, phaseManager: PhaseManager())
}