//
//  AnalysisTypeCard.swift
//  shigodeki
//
//  Extracted from ProjectAIAnalysisView.swift for CLAUDE.md compliance
//  Analysis type selection card component
//

import SwiftUI

struct AnalysisTypeCard: View {
    let analysisType: AnalysisType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(analysisType.color.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: analysisType.icon)
                        .font(.title3)
                        .foregroundColor(analysisType.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(analysisType.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(analysisType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(analysisType.color)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? analysisType.color.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? analysisType.color : Color.clear, lineWidth: 2)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}