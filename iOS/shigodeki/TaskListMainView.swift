//
//  TaskListMainView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

struct TaskListMainView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @StateObject private var familyManager = FamilyManager()
    @StateObject private var taskManager = TaskManager()
    @State private var selectedFamily: Family?
    @State private var showingCreateTaskList = false
    @State private var bootstrapped = false
    
    @State private var navigationResetId = UUID()
    
    var body: some View {
        NavigationView {
            VStack {
                if (!bootstrapped) || authManager.isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if familyManager.families.isEmpty && !familyManager.isLoading {
                    // No families state
                    VStack(spacing: 24) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 8) {
                            Text("家族グループが必要です")
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            Text("タスクタブは『家族グループのタスク』を表示します。\nプロジェクト配下のタスクは『プロジェクト』タブで管理できます。")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        NavigationLink(destination: FamilyView()) {
                            HStack {
                                Image(systemName: "person.3.fill")
                                Text("家族グループを作成")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    
                } else if let selectedFamily = selectedFamily {
                    // Task lists for selected family
                    TaskListsView(family: selectedFamily, taskManager: taskManager)
                    
                } else if !familyManager.families.isEmpty {
                    // Family selection
                    FamilySelectionView(families: familyManager.families) { family in
                        selectedFamily = family
                        Task.detached {
                            await taskManager.loadTaskLists(familyId: family.id!)
                            await MainActor.run {
                                taskManager.startListeningToTaskLists(familyId: family.id!)
                            }
                        }
                    }
                }
                
                if familyManager.isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("タスク")
            .toolbar {
                if selectedFamily != nil {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingCreateTaskList = true
                        }) {
                            Image(systemName: "plus")
                        }
                        
                        Button(action: {
                            selectedFamily = nil
                            taskManager.stopListeningToTaskLists()
                        }) {
                            Image(systemName: "house")
                        }
                    }
                }
            }
            .onAppear {
                if let userId = authManager.currentUser?.id {
                    familyManager.startListeningToFamilies(userId: userId)
                    Task.detached { await familyManager.loadFamiliesForUser(userId: userId) }
                    bootstrapped = true
                }
            }
            .onChange(of: authManager.currentUser?.id ?? "") { _, newId in
                guard !newId.isEmpty else { return }
                familyManager.startListeningToFamilies(userId: newId)
                Task.detached { await familyManager.loadFamiliesForUser(userId: newId) }
                bootstrapped = true
            }
            .onDisappear {
                familyManager.stopListeningToFamilies()
                taskManager.stopListeningToTaskLists()
                taskManager.stopListeningToTasks()
            }
            .sheet(isPresented: $showingCreateTaskList) {
                if let family = selectedFamily, let userId = authManager.currentUser?.id {
                    CreateTaskListView(family: family, taskManager: taskManager, creatorUserId: userId)
                }
            }
        }
        .id(navigationResetId)
        .onReceive(NotificationCenter.default.publisher(for: .taskTabSelected)) { _ in
            navigationResetId = UUID()
        }
    }
}

struct FamilySelectionView: View {
    let families: [Family]
    let onFamilySelected: (Family) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("家族を選択")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top)
            
            Text("タスクを管理する家族グループを選んでください")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            LazyVStack(spacing: 12) {
                ForEach(families) { family in
                    Button(action: {
                        onFamilySelected(family)
                    }) {
                        HStack {
                            Image(systemName: "house.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(family.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("\(family.members.count)人のメンバー")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

struct TaskListsView: View {
    let family: Family
    @ObservedObject var taskManager: TaskManager
    @State private var showingCreateTaskList = false
    @State private var showingQuickAIGeneration = false
    @State private var showingAISettings = false
    @ObservedObject private var authManager = AuthenticationManager.shared
    @StateObject private var aiGenerator = AITaskGenerator()
    
    var body: some View {
        VStack {
            if taskManager.taskLists.isEmpty && !taskManager.isLoading {
                // Empty state
                VStack(spacing: 24) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 8) {
                        Text("タスクリストがありません")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("新しいタスクリストを作成して\nタスク管理を始めましょう。\n（注）プロジェクトのタスクは『プロジェクト』タブで表示されます")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 12) {
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
                        
                        Button(action: {
                            if aiGenerator.availableProviders.isEmpty {
                                showingAISettings = true
                            } else {
                                showingQuickAIGeneration = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "brain")
                                Text("AI でタスクを生成")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
                
            } else {
                List {
                    // Info banner clarifying scope
                    Section {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("このタブでは家族グループ配下のタスクを表示します。プロジェクト配下のタスクは『プロジェクト』タブを開いてください。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    // Quick AI Generation Section
                    Section {
                        Button(action: {
                            if aiGenerator.availableProviders.isEmpty {
                                showingAISettings = true
                            } else {
                                showingQuickAIGeneration = true
                            }
                        }) {
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "brain")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("AI クイック生成")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text("自然言語からタスクを瞬時に生成")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Task Lists Section
                    if !taskManager.taskLists.isEmpty {
                        Section("タスクリスト") {
                            ForEach(taskManager.taskLists) { taskList in
                                NavigationLink(destination: TaskDetailView(taskList: taskList, family: family, taskManager: taskManager)) {
                                    TaskListRowView(taskList: taskList, taskCount: taskManager.tasks[taskList.id!]?.count ?? 0)
                                }
                            }
                        }
                    }
                }
                .refreshable {
                    await taskManager.loadTaskLists(familyId: family.id!)
                }
            }
            
            if taskManager.isLoading {
                ProgressView("読み込み中...")
                    .padding()
            }
        }
        .sheet(isPresented: $showingCreateTaskList) {
            if let userId = authManager.currentUser?.id {
                CreateTaskListView(family: family, taskManager: taskManager, creatorUserId: userId)
            }
        }
        .sheet(isPresented: $showingQuickAIGeneration) {
            QuickAIGenerationView(
                family: family,
                taskManager: taskManager,
                aiGenerator: aiGenerator
            )
        }
        .sheet(isPresented: $showingAISettings) {
            APISettingsView()
                .onDisappear {
                    aiGenerator.updateAvailableProviders()
                }
        }
    }
}

struct TaskListRowView: View {
    let taskList: TaskList
    let taskCount: Int
    
    var body: some View {
        HStack {
            Circle()
                .fill(taskList.color.swiftUIColor)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(taskList.name)
                    .font(.headline)
                
                Text("\(taskCount)個のタスク")
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

#Preview {
    TaskListMainView()
}
