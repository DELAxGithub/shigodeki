//
//  TemplateHeaderComponents.swift
//  shigodeki
//
//  Extracted from TemplateCustomizationComponents.swift for CLAUDE.md compliance
//  Template header and statistics display components
//

import SwiftUI

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.primaryBlue)
                .font(.title3)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
}

// MARK: - Statistics Components

struct StatChip: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

struct TemplateStatsRow: View {
    let template: ProjectTemplate
    
    var body: some View {
        HStack(spacing: 8) {
            StatChip(icon: "list.bullet", value: "\(template.phases.count)")
            StatChip(icon: "checkmark.square", value: "\(totalTasks)")
            StatChip(icon: "clock", value: difficultyText)
            
            Spacer()
        }
    }
    
    private var totalTasks: Int {
        template.phases.reduce(0) { total, phase in 
            total + phase.taskLists.reduce(0) { $0 + $1.tasks.count }
        }
    }
    
    private var difficultyText: String {
        template.metadata.difficulty.displayName
    }
}

// MARK: - Template Header

struct TemplateHeader: View {
    let template: ProjectTemplate
    let showStats: Bool
    
    init(template: ProjectTemplate, showStats: Bool = true) {
        self.template = template
        self.showStats = showStats
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let description = template.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                CategoryBadge(category: template.category)
            }
            
            if showStats {
                TemplateStatsRow(template: template)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Category Badge

struct CategoryBadge: View {
    let category: TemplateCategory
    
    var body: some View {
        Text(category.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(category.color.opacity(0.2))
            .foregroundColor(category.color)
            .cornerRadius(8)
    }
}