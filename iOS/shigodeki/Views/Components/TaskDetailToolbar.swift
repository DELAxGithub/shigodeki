//
//  TaskDetailToolbar.swift
//  shigodeki
//
//  Extracted from TaskDetailView.swift for CLAUDE.md compliance
//  Task detail toolbar component
//

import SwiftUI

struct TaskDetailToolbar: ToolbarContent {
    let aiGenerator: AITaskGenerator
    let onShowAIAssistant: () -> Void
    let onShowAISettings: () -> Void
    let onCreateTask: () -> Void
    
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            // AI Assistant Button
            Button(action: {
                if aiGenerator.availableProviders.isEmpty {
                    onShowAISettings()
                } else {
                    onShowAIAssistant()
                }
            }) {
                Image(systemName: "brain")
                    .foregroundColor(.blue)
            }
            .help("AI タスク提案")
            
            // Add Task Button
            Button(action: onCreateTask) {
                Image(systemName: "plus")
            }
            .help("新しいタスクを作成")
        }
    }
}