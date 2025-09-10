//
//  TaskBasicSections.swift
//  shigodeki
//
//  Extracted from PhaseTaskDetailSections.swift for CLAUDE.md compliance
//  Basic task information UI components
//

import SwiftUI

// MARK: - Basic Info Section

struct TaskBasicInfoSection: View {
    @ObservedObject var viewModel: PhaseTaskDetailViewModel
    let task: ShigodekiTask
    
    var body: some View {
        Section("基本") {
            TextField("タイトル", text: $viewModel.title)
            TextField("説明", text: $viewModel.taskDescription)
            Toggle("完了", isOn: $viewModel.isCompleted)
            
            Picker("優先度", selection: $viewModel.priority) {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
            
            Toggle("締切を設定", isOn: Binding(
                get: { viewModel.hasDueDateToggle },
                set: { viewModel.hasDueDateToggle = $0 }
            ))
            
            if viewModel.hasDueDateToggle {
                DatePicker(
                    "締切",
                    selection: Binding(
                        get: { viewModel.dueDateNonOptional },
                        set: { viewModel.dueDateNonOptional = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .environment(\.locale, Locale(identifier: "ja_JP"))
            }
        }
    }
}

// MARK: - Task Description Section

struct TaskDescriptionSection: View {
    @ObservedObject var viewModel: PhaseTaskDetailViewModel
    
    var body: some View {
        if !viewModel.taskDescription.isEmpty {
            Section("詳細説明") {
                ScrollView {
                    VStack(alignment: .leading) {
                        Text(viewModel.taskDescription)
                            .textSelection(.enabled)
                            .padding(.vertical, 8)
                    }
                }
                .frame(maxHeight: 150)
            }
        }
    }
}
