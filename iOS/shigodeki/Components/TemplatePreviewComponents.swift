import SwiftUI

// MARK: - Template Statistics

struct TemplatePreviewStats {
    let template: ProjectTemplate
    
    var totalPhases: Int { template.phases.count }
    var totalTasks: Int { template.phases.flatMap { $0.taskLists.flatMap { $0.tasks } }.count }
    var estimatedHours: Int { 
        template.phases.flatMap { $0.taskLists.flatMap { $0.tasks } }
            .compactMap { task in 
                if let hours = task.estimatedHours {
                    return Int(hours)
                } else {
                    return nil
                }
            }.reduce(0, +)
    }
    var averageTasksPerPhase: Int { totalPhases > 0 ? totalTasks / totalPhases : 0 }
}

// MARK: - Supporting Views

struct PhaseNavigationButton: View {
    let phase: PhaseTemplate
    let index: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 30, height: 30)
                    
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                Text(phase.title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .lineLimit(1)
                    .frame(width: 60)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PhaseDetailView: View {
    let phase: PhaseTemplate
    let teaserConfig: TemplateTeaserConfig?
    let isLocked: Bool

    private var displayedTaskLists: [TaskListTemplate] {
        if let config = teaserConfig {
            return Array(phase.taskLists.prefix(config.maxTaskLists))
        }
        return Array(phase.taskLists.prefix(3))
    }

    private var hasHiddenTaskLists: Bool {
        if let config = teaserConfig {
            return phase.taskLists.count > config.maxTaskLists
        }
        return phase.taskLists.count > 3
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(phase.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let description = phase.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            if !phase.taskLists.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("タスクリスト (\(phase.taskLists.count))")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(displayedTaskLists, id: \.id) { taskList in
                        TaskListPreview(
                            taskList: taskList,
                            teaserConfig: teaserConfig,
                            isLocked: isLocked
                        )
                    }

                    if isLocked && hasHiddenTaskLists {
                        LockedContentNotice()
                            .padding(.leading, 8)
                    } else if !isLocked && hasHiddenTaskLists {
                        Text("他に\(phase.taskLists.count - displayedTaskLists.count)個のタスクリスト...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct TaskListPreview: View {
    let taskList: TaskListTemplate
    let teaserConfig: TemplateTeaserConfig?
    let isLocked: Bool
    @State private var isExpanded = false

    private var displayedTasks: [TaskTemplate] {
        if let config = teaserConfig {
            return Array(taskList.tasks.prefix(config.maxTasksPerList))
        }
        return Array(taskList.tasks.prefix(5))
    }

    private var hasHiddenTasks: Bool {
        if let config = teaserConfig {
            return taskList.tasks.count > config.maxTasksPerList
        }
        return taskList.tasks.count > 5
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Circle()
                        .fill(taskList.color.swiftUIColor)
                        .frame(width: 12, height: 12)
                    
                    Text(taskList.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("\(taskList.tasks.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "list.bullet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded && !displayedTasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(displayedTasks, id: \.id) { task in
                        HStack(spacing: 8) {
                            PriorityIndicator(priority: task.priority)

                            Text(task.title)
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if let hours = task.estimatedHours {
                                Text("\(hours)h")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color(.systemGray5))
                                    )
                            }
                        }
                        .padding(.leading, 20)
                    }
                    
                    if isLocked && hasHiddenTasks {
                        LockedContentNotice()
                            .padding(.leading, 20)
                    } else if !isLocked && taskList.tasks.count > displayedTasks.count {
                        Text("他に\(taskList.tasks.count - displayedTasks.count)個のタスク...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct LockedContentNotice: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundColor(.orange)
            
            Text(NSLocalizedString("template.preview.locked_notice", tableName: nil, bundle: .main, value: "残りのコンテンツはPROでロック解除できます", comment: "Indicates additional content is locked"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
        )
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct MetadataRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

struct PriorityIndicator: View {
    let priority: TaskPriority
    
    var body: some View {
        Circle()
            .fill(priority.displayColor)
            .frame(width: 6, height: 6)
    }
}

// MARK: - Extensions

extension TaskPriority {
    var displayColor: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }
}
