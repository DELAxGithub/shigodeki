//
//  TaskListMainView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

struct TaskListMainView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var familyManager = FamilyManager()
    @StateObject private var taskManager = TaskManager()
    @State private var selectedFamily: Family?
    @State private var showingCreateTaskList = false
    
    var body: some View {
        NavigationView {
            VStack {
                if familyManager.families.isEmpty && !familyManager.isLoading {
                    // No families state
                    VStack(spacing: 24) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 8) {
                            Text("家族グループが必要です")
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            Text("タスクを管理するには\nまず家族グループを作成してください")
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
                    Task.detached {
                        await familyManager.loadFamiliesForUser(userId: userId)
                    }
                }
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
    @StateObject private var authManager = AuthenticationManager()
    
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
                        
                        Text("新しいタスクリストを作成して\nタスク管理を始めましょう")
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
                    ForEach(taskManager.taskLists) { taskList in
                        NavigationLink(destination: TaskDetailView(taskList: taskList, family: family, taskManager: taskManager)) {
                            TaskListRowView(taskList: taskList, taskCount: taskManager.tasks[taskList.id!]?.count ?? 0)
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