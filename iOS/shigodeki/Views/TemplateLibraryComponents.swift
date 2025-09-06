import SwiftUI

// MARK: - Supporting Views

struct CategoryCard: View {
    let category: TemplateCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(category.color.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(category.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Templates available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TemplateCard: View {
    let template: ProjectTemplate
    let onTap: () -> Void
    let onPreview: () -> Void
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(template.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        DifficultyBadge(difficulty: template.metadata.difficulty)
                    }
                    
                    if let description = template.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
            }
            
            HStack(spacing: 16) {
                StatItem(
                    icon: "list.number",
                    value: "\(template.phases.count)",
                    label: "phases",
                    color: .blue
                )
                
                StatItem(
                    icon: "checkmark.circle",
                    value: "\(template.phases.flatMap { $0.taskLists.flatMap { $0.tasks } }.count)",
                    label: "tasks",
                    color: .green
                )
                
                let estimatedHours = template.phases.flatMap { $0.taskLists.flatMap { $0.tasks } }.compactMap { $0.estimatedHours }.reduce(0, +)
                if estimatedHours > 0 {
                    StatItem(
                        icon: "clock",
                        value: "\(estimatedHours)h",
                        label: "time",
                        color: .orange
                    )
                }
                
                Spacer()
            }
            
            if !template.metadata.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(template.metadata.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray5))
                                )
                                .foregroundColor(.secondary)
                        }
                        
                        if template.metadata.tags.count > 3 {
                            Text("+\(template.metadata.tags.count - 3)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            
            HStack(spacing: 12) {
                Button("Preview", action: onPreview)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                
                Button("Select", action: onSelect)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .onTapGesture(perform: onTap)
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct DifficultyBadge: View {
    let difficulty: TemplateDifficulty
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<difficulty.stars, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
        )
    }
}

struct FilterChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}