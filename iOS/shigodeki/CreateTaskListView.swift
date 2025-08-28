//
//  CreateTaskListView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

struct CreateTaskListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var taskListName: String = ""
    @State private var selectedColor: TaskListColor = .blue
    @State private var isCreating = false
    @State private var showSuccess = false
    
    let family: Family
    let taskManager: TaskManager
    let creatorUserId: String
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("タスクリスト名")
                            .font(.headline)
                        
                        TextField("例: 家事、買い物、仕事", text: $taskListName)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("カラー")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(TaskListColor.allCases, id: \.self) { color in
                                Button(action: {
                                    selectedColor = color
                                }) {
                                    Circle()
                                        .fill(Color(color.rawValue))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                        )
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                                .opacity(selectedColor == color ? 1 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 32)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: createTaskList) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            }
                            Text(isCreating ? "作成中..." : "タスクリストを作成")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(taskListName.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(taskListName.isEmpty || isCreating)
                    
                    Button("キャンセル") {
                        dismiss()
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("タスクリスト作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("タスクリスト作成完了", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("タスクリスト「\(taskListName)」が作成されました。")
            }
        }
    }
    
    private func createTaskList() {
        guard let familyId = family.id else { return }
        
        isCreating = true
        
        Task.detached {
            do {
                _ = try await taskManager.createTaskList(
                    name: taskListName,
                    familyId: familyId,
                    creatorUserId: creatorUserId,
                    color: selectedColor
                )
                await MainActor.run {
                    isCreating = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                }
                print("Error creating task list: \(error)")
            }
        }
    }
}

#Preview {
    CreateTaskListView(
        family: Family(name: "サンプル家族", members: ["user1"]),
        taskManager: TaskManager(),
        creatorUserId: "user1"
    )
}