//
//  PhaseRowView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

struct PhaseRowView: View {
    let phase: Phase
    @ObservedObject var phaseManager: PhaseManager
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with phase number, title and status
            HStack {
                // Phase number badge
                HStack {
                    Text("\(phase.order + 1)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(width: 32, height: 32)
                .background(Color.primaryBlue)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.name)
                        .font(.headline)
                        .foregroundColor(.primaryText)
                        .fontWeight(.semibold)
                    
                    Text("Phase \(phase.order + 1)")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                // Status badge
                if phase.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("完了")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.completed)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.completed.opacity(0.1))
                    .clipShape(Capsule())
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle")
                            .font(.caption)
                        Text("進行中")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.inProgress)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.inProgress.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            
            // Description
            if let description = phase.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            // Metadata row
            HStack {
                // Task list count
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.caption)
                        .foregroundColor(.primaryBlue)
                    Text("0個のタスクリスト") // TODO: Get actual count
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primaryBlue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Spacer()
                
                // Creation date
                Text(formatDate(phase.createdAt))
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
            }
        }
        .listCard(isSelected: isPressed)
        .contentShape(Rectangle())
        .interactiveScale(isPressed: $isPressed)
        .onTapGesture {
            withAnimation(.quickEase) {
                isPressed = true
            }
            HapticFeedbackManager.shared.light()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.quickEase) {
                    isPressed = false
                }
            }
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

#Preview {
    let samplePhase = Phase(name: "Phase 1", description: "First phase", projectId: "proj1", createdBy: "user1", order: 0)
    PhaseRowView(phase: samplePhase, phaseManager: PhaseManager())
        .padding()
}