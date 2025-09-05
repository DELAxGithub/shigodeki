import SwiftUI

// MARK: - Template Statistics

struct TemplateStats {
    let template: ProjectTemplate
    
    var totalPhases: Int { template.phases.count }
    var totalTasks: Int { template.phases.flatMap { $0.taskLists.flatMap { $0.tasks } }.count }
    var estimatedHours: Int { template.phases.flatMap { $0.taskLists.flatMap { $0.tasks } }.compactMap { $0.estimatedHours }.reduce(0, +) }
    var averageTasksPerPhase: Int { totalPhases > 0 ? totalTasks / totalPhases : 0 }
}

// MARK: - Supporting Views

struct PhaseNavigationButton: View {
    let phase: ProjectPhase
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
                
                Text(phase.name)
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
    let phase: ProjectPhase
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(phase.name)
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
                    
                    ForEach(phase.taskLists.prefix(3), id: \.id) { taskList in
                        TaskListPreview(taskList: taskList)
                    }
                    
                    if phase.taskLists.count > 3 {
                        Text("他に\(phase.taskLists.count - 3)個のタスクリスト...")
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
    let taskList: TaskList
    @State private var isExpanded = false
    
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
            
            if isExpanded && !taskList.tasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(taskList.tasks.prefix(5), id: \.id) { task in
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
                    
                    if taskList.tasks.count > 5 {
                        Text("他に\(taskList.tasks.count - 5)個のタスク...")
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
            .fill(priority.color)
            .frame(width: 6, height: 6)
    }
}

// MARK: - Extensions

extension TaskPriority {
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }
}