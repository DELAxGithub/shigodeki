//
//  TaskImprovementSuggestionComponents.swift
//  shigodeki
//
//  Extracted from TaskImprovementSuggestionView.swift for CLAUDE.md compliance
//  Task improvement suggestion list and row components
//

import SwiftUI

// MARK: - Analysis Header Section

struct AnalysisHeaderSection: View {
    let engine: TaskImprovementEngine?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                
                Text("AIタスク改善アシスタント")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                AnalysisStateIndicator(engine: engine)
            }
            
            Divider()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Analysis State Indicator

struct AnalysisStateIndicator: View {
    let engine: TaskImprovementEngine?
    
    private var stateInfo: (String, Color) {
        guard let engine = engine else {
            return ("初期化中", .gray)
        }
        
        switch engine.analysisState {
        case .idle:
            return ("待機中", .gray)
        case .analyzing:
            return ("分析中", .blue)
        case .applying:
            return ("適用中", .orange)
        case .completed:
            return ("完了", .green)
        case .applied:
            return ("適用済み", .green)
        case .failed:
            return ("エラー", .red)
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(stateInfo.1)
                .frame(width: 8, height: 8)
            
            Text(stateInfo.0)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(stateInfo.1)
        }
    }
}

// MARK: - Suggestions List View

struct SuggestionsListView: View {
    let engine: TaskImprovementEngine
    @Binding var selectedSuggestions: Set<UUID>
    let onApplySelected: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Apply button
            if !selectedSuggestions.isEmpty {
                HStack {
                    Button(action: onApplySelected) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("選択した提案を適用 (\(selectedSuggestions.count))")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
            }
            
            // Suggestions list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(engine.improvements, id: \.id) { suggestion in
                        SuggestionRowView(
                            suggestion: suggestion,
                            isSelected: selectedSuggestions.contains(suggestion.id)
                        ) {
                            toggleSelection(suggestion.id)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedSuggestions.contains(id) {
            selectedSuggestions.remove(id)
        } else {
            selectedSuggestions.insert(id)
        }
    }
}

// MARK: - Suggestion Row View

struct SuggestionRowView: View {
    let suggestion: ImprovementSuggestion
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Selection indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .green : .gray)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(suggestion.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    ImpactBadge(impact: suggestion.impact)
                }
                
                // Additional details
                if !suggestion.targetTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("対象タスク:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ForEach(Array(suggestion.targetTasks.prefix(3)), id: \.self) { taskId in
                            Text("• Task ID: \(taskId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if suggestion.targetTasks.count > 3 {
                            Text("他\(suggestion.targetTasks.count - 3)件...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green.opacity(0.1) : Color(.systemBackground))
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Impact Badge

struct ImpactBadge: View {
    let impact: ImprovementImpact
    
    private var badgeInfo: (String, Color) {
        switch impact.type {
        case .low:
            return ("低", .yellow)
        case .medium:
            return ("中", .orange)
        case .high:
            return ("高", .red)
        case .critical:
            return ("緊急", .purple)
        }
    }
    
    var body: some View {
        Text(badgeInfo.0)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeInfo.1.opacity(0.2))
            .foregroundColor(badgeInfo.1)
            .cornerRadius(6)
    }
}