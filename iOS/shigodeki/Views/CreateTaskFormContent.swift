//
//  CreateTaskFormContent.swift
//  shigodeki
//
//  Form content view for task creation - resolves type-check complexity
//  Extracted for CLAUDE.md compliance
//

import SwiftUI

struct CreateTaskFormContent: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var selectedPriority: TaskPriority
    @Binding var selectedAssignee: String?
    @Binding var dueDate: Date
    @Binding var hasDueDate: Bool
    @Binding var selectedTags: [String]
    @Binding var keepAttachment: Bool
    @Binding var attachments: [String]
    
    let taskList: TaskList
    let familyMembers: [User]
    let creatorUserId: String
    let tagManager: TagManager
    let isCreating: Bool
    let onCreateTask: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                TaskFormFields(
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
                    tagManager: tagManager
                )
                
                Spacer(minLength: 32)
                
                CreateTaskActionButtons(
                    title: title,
                    isCreating: isCreating,
                    createAction: onCreateTask,
                    cancelAction: onCancel
                )
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }
}

struct TaskFormFields: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var selectedPriority: TaskPriority
    @Binding var selectedAssignee: String?
    @Binding var dueDate: Date
    @Binding var hasDueDate: Bool
    @Binding var selectedTags: [String]
    @Binding var keepAttachment: Bool
    @Binding var attachments: [String]
    
    let taskList: TaskList
    let familyMembers: [User]
    let creatorUserId: String
    let tagManager: TagManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TaskTitleSection(title: $title)
            
            CreateTaskDescriptionSection(description: $description)
            
            TaskPrioritySection(selectedPriority: $selectedPriority)
            
            TaskDueDateSection(hasDueDate: $hasDueDate, dueDate: $dueDate)
            
            TaskTagSection(
                selectedTags: $selectedTags,
                taskList: taskList,
                creatorUserId: creatorUserId,
                tagManager: tagManager
            )

            if familyMembers.count > 1 {
                TaskAssigneeSection(
                    selectedAssignee: $selectedAssignee,
                    familyMembers: familyMembers
                )
            }

            // Optional: capture/select photo and generate suggestions via TidyPlanKit
            PhotoTaskSuggestionSection(
                title: $title,
                description: $description,
                selectedPriority: $selectedPriority,
                dueDate: $dueDate,
                hasDueDate: $hasDueDate,
                selectedTags: $selectedTags,
                keepAttachment: $keepAttachment,
                attachments: $attachments,
                contextHint: "タスクリスト: \(taskList.name)"
            )

            // Attachment options
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $keepAttachment) {
                    Text("添付として保持")
                }
                if keepAttachment {
                    Text("現在の添付: \(attachments.count) 件")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
}

struct TaskTagSection: View {
    @Binding var selectedTags: [String]
    let taskList: TaskList
    let creatorUserId: String
    let tagManager: TagManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("タグ（任意）")
                .font(.headline)
            
            TagInputView(
                selectedTags: $selectedTags,
                availableTags: tagManager.tags.filter { $0.projectId == taskList.projectId },
                projectId: taskList.projectId,
                ownerId: taskList.projectId,
                ownerType: .family,
                createdBy: creatorUserId,
                onTagCreated: { _ in
                    // Tag will be automatically updated via listener
                }
            )
            .frame(maxHeight: 200)
        }
    }
}
