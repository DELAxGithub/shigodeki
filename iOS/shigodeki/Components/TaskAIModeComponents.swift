//
//  TaskAIModeComponents.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import SwiftUI

// MARK: - Assistant Mode Components

struct AssistantModeSelector: View {
    @Binding var selectedMode: TaskAIAssistantView.AssistantMode
    let modes: [TaskAIAssistantView.AssistantMode]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支援モード")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(modes) { mode in
                    AssistantModeCard(
                        mode: mode,
                        isSelected: selectedMode == mode
                    ) {
                        selectedMode = mode
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct AssistantModeCard: View {
    let mode: TaskAIAssistantView.AssistantMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(mode.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}