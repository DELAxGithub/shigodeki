//
//  CreateTaskComponents.swift
//  shigodeki
//
//  Extracted from CreateTaskView.swift for CLAUDE.md compliance
//  Separates UI components to resolve type-check complexity
//

import SwiftUI

// MARK: - Task Input Components

struct TaskTitleSection: View {
    @Binding var title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("タスク名")
                .font(.headline)
            
            TextField("例: 掃除機をかける", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.body)
        }
    }
}

struct CreateTaskDescriptionSection: View {
    @Binding var description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("詳細（任意）")
                .font(.headline)
            
            TextField("詳しい説明を入力...", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .lineLimit(3...6)
        }
    }
}

// MARK: - Priority Selection Component

struct TaskPrioritySection: View {
    @Binding var selectedPriority: TaskPriority
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("優先度")
                .font(.headline)
            
            HStack(spacing: 16) {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    PriorityButton(
                        priority: priority, 
                        isSelected: selectedPriority == priority
                    ) {
                        selectedPriority = priority
                    }
                }
            }
        }
    }
}

struct PriorityButton: View {
    let priority: TaskPriority
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(priority.swiftUIColor)
                    .frame(width: 12, height: 12)
                Text(priority.displayName)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Due Date Component

struct TaskDueDateSection: View {
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date
    
    var body: some View {
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
    }
}

// MARK: - Assignee Selection Component

struct TaskAssigneeSection: View {
    @Binding var selectedAssignee: String?
    let familyMembers: [User]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("担当者（任意）")
                .font(.headline)
            
            VStack(spacing: 8) {
                UnassignedButton(
                    isSelected: selectedAssignee == nil
                ) {
                    selectedAssignee = nil
                }
                
                ForEach(familyMembers, id: \.id) { member in
                    AssigneeButton(
                        member: member,
                        isSelected: selectedAssignee == member.id
                    ) {
                        selectedAssignee = member.id
                    }
                }
            }
        }
    }
}

struct UnassignedButton: View {
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
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
    }
}

struct AssigneeButton: View {
    let member: User
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
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

// MARK: - Action Buttons Component

struct CreateTaskActionButtons: View {
    let title: String
    let isCreating: Bool
    let createAction: () -> Void
    let cancelAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: createAction) {
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
            
            Button("キャンセル", action: cancelAction)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}