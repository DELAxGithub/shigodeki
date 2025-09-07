//
//  TaskExtendedSections.swift
//  shigodeki
//
//  Extracted from PhaseTaskDetailSections.swift for CLAUDE.md compliance
//  Extended task functionality UI components
//

import SwiftUI

// MARK: - Assignment and Tags Section

struct TaskAssignmentTagsSection: View {
    @ObservedObject var viewModel: PhaseTaskDetailViewModel
    @ObservedObject var tagManager: TagManager
    @ObservedObject var sectionManager: PhaseSectionManager
    let projectMembers: [ProjectMember]
    let task: ShigodekiTask
    @Binding var showingTagEditor: Bool
    @Binding var selectedSectionId: String?
    
    var body: some View {
        Section("担当・タグ・セクション") {
            AssigneeSectionView(
                members: projectMembers,
                assignedTo: $viewModel.assignedTo
            )
            
            // Tags Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("タグ")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: { showingTagEditor = true }) {
                        Text(showingTagEditor ? "完了" : "編集")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
                
                if viewModel.tags.isEmpty {
                    Text("タグが設定されていません")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    TaskDetailTagsView(
                        tags: viewModel.tags,
                        tagMasters: tagManager.tags.filter { $0.projectId == viewModel.projectId ?? "" },
                        isEditing: showingTagEditor,
                        onTagTapped: { tagName in
                            print("Tag tapped: \(tagName)")
                        },
                        onEditTags: { 
                            showingTagEditor.toggle() 
                        }
                    )
                }
            }
            
            // Section Picker
            if !sectionManager.sections.isEmpty {
                SectionPickerView(
                    sections: sectionManager.sections,
                    selectedSectionId: Binding(
                        get: { selectedSectionId ?? task.sectionId }, 
                        set: { selectedSectionId = $0 }
                    ),
                    onChange: { _ in }
                )
            } else {
                ProgressView().frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Subtasks Section

struct TaskSubtasksSection: View {
    let subtasks: [Subtask]
    @Binding var newSubtaskTitle: String
    let onToggleSubtask: (Subtask) -> Void
    let onDeleteSubtask: (Subtask) -> Void
    let onAddSubtask: () -> Void
    
    var body: some View {
        Section("サブタスク") {
            if subtasks.isEmpty {
                Text("サブタスクはありません")
                    .foregroundColor(.secondary)
            } else {
                ForEach(subtasks) { subtask in
                    HStack {
                        Button(action: { onToggleSubtask(subtask) }) {
                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(subtask.isCompleted ? .green : .secondary)
                        }
                        
                        Text(subtask.title)
                        Spacer()
                        
                        Menu {
                            Button("削除", role: .destructive) { 
                                onDeleteSubtask(subtask) 
                            }
                        } label: { 
                            Image(systemName: "ellipsis.circle") 
                        }
                    }
                }
            }
            
            HStack {
                TextField("サブタスクを追加", text: $newSubtaskTitle)
                Button("追加") { 
                    onAddSubtask() 
                }
                .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}