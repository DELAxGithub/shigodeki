//
//  TagDisplayView.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import SwiftUI

// MARK: - TagDisplayView

struct TagDisplayView: View {
    let tags: [String]
    let tagMasters: [TaskTag]
    let maxDisplayCount: Int
    let size: TagChip.TagSize
    let onTagTapped: ((String) -> Void)?
    
    // Computed properties
    private var displayTags: [TaskTag] {
        let foundTags = tags.compactMap { tagName in
            tagMasters.first { $0.name == tagName }
        }
        return Array(foundTags.prefix(maxDisplayCount))
    }
    
    private var remainingCount: Int {
        max(0, tags.count - maxDisplayCount)
    }
    
    // MARK: - Initializers
    
    /// Full initializer for maximum control
    init(
        tags: [String],
        tagMasters: [TaskTag],
        maxDisplayCount: Int = 3,
        size: TagChip.TagSize = .small,
        onTagTapped: ((String) -> Void)? = nil
    ) {
        self.tags = tags
        self.tagMasters = tagMasters
        self.maxDisplayCount = maxDisplayCount
        self.size = size
        self.onTagTapped = onTagTapped
    }
    
    /// Convenience initializer for TaskRow usage
    init(
        tags: [String],
        tagMasters: [TaskTag],
        onTagTapped: ((String) -> Void)? = nil
    ) {
        self.init(
            tags: tags,
            tagMasters: tagMasters,
            maxDisplayCount: 3,
            size: .small,
            onTagTapped: onTagTapped
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        if tags.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 4) {
                // Display found tags
                ForEach(displayTags) { tag in
                    TagChip(tag: tag, size: size, isSelected: false) {
                        onTagTapped?(tag.name)
                    }
                }
                
                // Display tags that don't have master data (fallback)
                let displayedTagNames = Set(displayTags.map { $0.name })
                let remainingTagNames = Array(tags.filter { !displayedTagNames.contains($0) }.prefix(maxDisplayCount - displayTags.count))
                
                ForEach(remainingTagNames, id: \.self) { tagName in
                    TagChip(tagName: tagName, size: size, isSelected: false) {
                        onTagTapped?(tagName)
                    }
                }
                
                // Show remaining count if there are more tags
                if remainingCount > 0 {
                    remainingCountView
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var remainingCountView: some View {
        Text("+\(remainingCount)")
            .font(size == .small ? .caption2 : .caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, size == .small ? 4 : 6)
            .padding(.vertical, size == .small ? 2 : 3)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(size == .small ? 4 : 6)
            .onTapGesture {
                // Show all remaining tags - could trigger a sheet or expand view
                // For now, we'll call the first remaining tag
                if let firstRemainingTag = tags.dropFirst(maxDisplayCount).first {
                    onTagTapped?(firstRemainingTag)
                }
            }
    }
}

// MARK: - TaskRowTagsView (Specialized for TaskRow)

struct TaskRowTagsView: View {
    let task: ShigodekiTask
    let tagMasters: [TaskTag]
    let onTagTapped: ((String) -> Void)?
    
    var body: some View {
        Group {
            if !task.tags.isEmpty {
                TagDisplayView(
                    tags: task.tags,
                    tagMasters: tagMasters,
                    maxDisplayCount: 2, // More compact for task rows
                    size: .small,
                    onTagTapped: onTagTapped
                )
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - TaskDetailTagsView (Specialized for TaskDetail)

struct TaskDetailTagsView: View {
    let task: ShigodekiTask?
    let tags: [String]
    let tagMasters: [TaskTag]
    let isEditing: Bool
    let onTagTapped: ((String) -> Void)?
    let onEditTags: (() -> Void)?
    
    // Convenience initializer for backward compatibility
    init(task: ShigodekiTask, tagMasters: [TaskTag], isEditing: Bool, onTagTapped: ((String) -> Void)?, onEditTags: (() -> Void)?) {
        self.task = task
        self.tags = task.tags
        self.tagMasters = tagMasters
        self.isEditing = isEditing
        self.onTagTapped = onTagTapped
        self.onEditTags = onEditTags
    }
    
    // New initializer that accepts tags directly
    init(tags: [String], tagMasters: [TaskTag], isEditing: Bool, onTagTapped: ((String) -> Void)?, onEditTags: (() -> Void)?) {
        self.task = nil
        self.tags = tags
        self.tagMasters = tagMasters
        self.isEditing = isEditing
        self.onTagTapped = onTagTapped
        self.onEditTags = onEditTags
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("タグ")
                    .font(.headline)
                
                Spacer()
                
                if let onEditTags = onEditTags {
                    Button(action: onEditTags) {
                        Text(isEditing ? "完了" : "編集")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            
            if tags.isEmpty {
                Text("タグが設定されていません")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                TagDisplayView(
                    tags: tags,
                    tagMasters: tagMasters,
                    maxDisplayCount: 8, // More tags shown in detail view
                    size: .medium,
                    onTagTapped: onTagTapped
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Sample data
        let sampleTagMasters = [
            TaskTag(name: "重要", color: "#FF3B30", emoji: "🔥", projectId: "project1", createdBy: "user1"),
            TaskTag(name: "緊急", color: "#FF9500", emoji: "⚡", projectId: "project1", createdBy: "user1"),
            TaskTag(name: "会議", color: "#007AFF", emoji: "🗣️", projectId: "project1", createdBy: "user1"),
            TaskTag(name: "買い物", color: "#34C759", emoji: "🛒", projectId: "project1", createdBy: "user1")
        ]
        
        let sampleTask = ShigodekiTask(
            title: "Sample Task",
            createdBy: "user1",
            listId: "list1",
            phaseId: "phase1", 
            projectId: "project1",
            order: 0
        )
        
        let taskWithTags = createTaskWithTags(sampleTask, tags: ["重要", "緊急", "会議", "買い物", "その他1", "その他2"])
        
        VStack(alignment: .leading, spacing: 16) {
            Text("TagDisplayView Examples")
                .font(.title)
            
            // Basic usage
            VStack(alignment: .leading, spacing: 8) {
                Text("Basic (3 tags max)")
                    .font(.headline)
                TagDisplayView(
                    tags: ["重要", "緊急", "会議"],
                    tagMasters: sampleTagMasters
                ) { tagName in
                    print("Tapped tag: \(tagName)")
                }
            }
            
            // With overflow
            VStack(alignment: .leading, spacing: 8) {
                Text("With overflow (+2 more)")
                    .font(.headline)
                TagDisplayView(
                    tags: taskWithTags.tags,
                    tagMasters: sampleTagMasters,
                    maxDisplayCount: 3,
                    size: .medium
                ) { tagName in
                    print("Tapped tag: \(tagName)")
                }
            }
            
            // TaskRow usage
            VStack(alignment: .leading, spacing: 8) {
                Text("TaskRow style (compact)")
                    .font(.headline)
                TaskRowTagsView(
                    task: taskWithTags,
                    tagMasters: sampleTagMasters
                ) { tagName in
                    print("Tapped tag: \(tagName)")
                }
            }
            
            // TaskDetail usage
            VStack(alignment: .leading, spacing: 8) {
                Text("TaskDetail style")
                    .font(.headline)
                TaskDetailTagsView(
                    task: taskWithTags,
                    tagMasters: sampleTagMasters,
                    isEditing: false,
                    onTagTapped: { tagName in
                        print("Tapped tag: \(tagName)")
                    },
                    onEditTags: {
                        print("Edit tags tapped")
                    }
                )
            }
        }
        
        Spacer()
    }
    .padding()
}

// MARK: - Preview Helper

private func createTaskWithTags(_ task: ShigodekiTask, tags: [String]) -> ShigodekiTask {
    var modifiedTask = task
    modifiedTask.tags = tags
    return modifiedTask
}