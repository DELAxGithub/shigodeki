//
//  CreateTaskView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
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
    @State private var isCreating = false
    @State private var showSuccess = false
    
    let taskList: TaskList
    let family: Family
    let taskManager: TaskManager
    let creatorUserId: String
    let familyMembers: [User]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Task Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("タスク名")
                                .font(.headline)
                            
                            TextField("例: 掃除機をかける", text: $title)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }
                        
                        // Task Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("詳細（任意）")
                                .font(.headline)
                            
                            TextField("詳しい説明を入力...", text: $description, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .lineLimit(3...6)
                        }
                        
                        // Priority
                        VStack(alignment: .leading, spacing: 8) {
                            Text("優先度")
                                .font(.headline)
                            
                            HStack(spacing: 16) {
                                ForEach(TaskPriority.allCases, id: \.self) { priority in
                                    Button(action: {
                                        selectedPriority = priority
                                    }) {
                                        HStack {
                                            Circle()
                                                .fill(Color(priority.color))
                                                .frame(width: 12, height: 12)
                                            Text(priority.displayName)
                                                .font(.subheadline)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedPriority == priority ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                        .cornerRadius(20)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Due Date
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("期限")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Toggle("", isOn: $hasDueDate)
                            }
                            
                            if hasDueDate {
                                DatePicker("期限日", selection: $dueDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                            }
                        }
                        
                        // Assignee
                        if familyMembers.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("担当者（任意）")
                                    .font(.headline)
                                
                                VStack(spacing: 8) {
                                    Button(action: {
                                        selectedAssignee = nil
                                    }) {
                                        HStack {
                                            Image(systemName: selectedAssignee == nil ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedAssignee == nil ? .blue : .gray)
                                            Text("未割り当て")
                                                .font(.subheadline)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    ForEach(familyMembers, id: \.id) { member in
                                        Button(action: {
                                            selectedAssignee = member.id
                                        }) {
                                            HStack {
                                                Image(systemName: selectedAssignee == member.id ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(selectedAssignee == member.id ? .blue : .gray)
                                                Text(member.name)
                                                    .font(.subheadline)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    Spacer(minLength: 32)
                    
                    VStack(spacing: 16) {
                        Button(action: createTask) {
                            HStack {
                                if isCreating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 4)
                                }
                                Text(isCreating ? "作成中..." : "タスクを作成")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(title.isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(title.isEmpty || isCreating)
                        
                        Button("キャンセル") {
                            dismiss()
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("タスク作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("タスク作成完了", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("タスク「\(title)」が作成されました。")
            }
        }
    }
    
    private func createTask() {
        guard let taskListId = taskList.id, let familyId = family.id else { return }
        
        isCreating = true
        
        Task.detached {
            do {
                _ = try await taskManager.createTask(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    taskListId: taskListId,
                    familyId: familyId,
                    creatorUserId: creatorUserId,
                    assignedTo: selectedAssignee,
                    dueDate: hasDueDate ? dueDate : nil,
                    priority: selectedPriority
                )
                await MainActor.run {
                    isCreating = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                }
                print("Error creating task: \(error)")
            }
        }
    }
}

#Preview {
    CreateTaskView(
        taskList: TaskList(name: "サンプルタスクリスト", familyId: "family1", createdBy: "user1"),
        family: Family(name: "サンプル家族", members: ["user1", "user2"]),
        taskManager: TaskManager(),
        creatorUserId: "user1",
        familyMembers: [
            User(name: "太郎", email: "taro@example.com"),
            User(name: "花子", email: "hanako@example.com")
        ]
    )
}