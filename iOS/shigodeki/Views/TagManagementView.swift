//
//  TagManagementView.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import SwiftUI

// MARK: - TagManagementView

struct TagManagementView: View {
    @StateObject private var tagManager = TagManager()
    @State private var showingCreateTag = false
    @State private var editingTag: TaskTag?
    @State private var tagToDelete: TaskTag?
    @State private var showingDeleteConfirmation = false
    @State private var searchText = ""

    let projectId: String
    let createdBy: String
    
    // Computed properties
    var sortedTags: [TaskTag] {
        let filtered = tagManager.tags.filter { tag in
            tag.projectId == projectId && (searchText.isEmpty || tag.name.localizedCaseInsensitiveContains(searchText))
        }
        return filtered.sorted { $0.usageCount > $1.usageCount }
    }
    
    var unusedTags: [TaskTag] {
        sortedTags.filter { $0.isUnused }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Content
                if tagManager.isLoading {
                    ProgressView("タグを読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sortedTags.isEmpty && !searchText.isEmpty {
                    emptySearchView
                } else if sortedTags.isEmpty {
                    emptyStateView
                } else {
                    tagListView
                }
            }
            .navigationTitle("タグ管理")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !unusedTags.isEmpty {
                        cleanupButton
                    }
                    createButton
                }
            }
            .onAppear {
                Task {
                    await tagManager.loadTags(projectId: projectId)
                    tagManager.startListening(projectId: projectId)
                }
            }
            .onDisappear {
                tagManager.stopListening()
            }
        }
        .sheet(isPresented: $showingCreateTag) {
            CreateTagView(
                projectId: projectId,
                createdBy: createdBy,
                onTagCreated: { _ in
                    // Tag will be automatically updated via listener
                }
            )
        }
        .sheet(item: $editingTag) { tag in
            EditTagView(tag: tag, onTagUpdated: { _ in
                // Tag will be automatically updated via listener 
            })
        }
        .alert("タグを削除しますか？", isPresented: $showingDeleteConfirmation, presenting: tagToDelete) { tag in
            deleteConfirmationAlert(for: tag)
        } message: { tag in
            deleteConfirmationMessage(for: tag)
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("タグを検索...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var tagListView: some View {
        List {
            if !searchText.isEmpty && !sortedTags.isEmpty {
                Section {
                    ForEach(sortedTags) { tag in
                        TagManagementRow(
                            tag: tag,
                            onEdit: { editingTag = tag },
                            onDelete: { confirmDelete(tag) }
                        )
                    }
                } header: {
                    Text("\(sortedTags.count)件のタグが見つかりました")
                }
            } else {
                // Group by usage
                let usedTags = sortedTags.filter { !$0.isUnused }
                let unusedTagsList = unusedTags
                
                if !usedTags.isEmpty {
                    Section {
                        ForEach(usedTags) { tag in
                            TagManagementRow(
                                tag: tag,
                                onEdit: { editingTag = tag },
                                onDelete: { confirmDelete(tag) }
                            )
                        }
                    } header: {
                        Text("使用中のタグ (\(usedTags.count))")
                    }
                }
                
                if !unusedTagsList.isEmpty {
                    Section {
                        ForEach(unusedTagsList) { tag in
                            TagManagementRow(
                                tag: tag,
                                onEdit: { editingTag = tag },
                                onDelete: { confirmDelete(tag) }
                            )
                        }
                    } header: {
                        Text("未使用のタグ (\(unusedTagsList.count))")
                    } footer: {
                        Text("未使用のタグは一括削除できます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tag")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("タグがありません")
                    .font(.headline)
                
                Text("タグを作成して、タスクを整理しましょう")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showingCreateTag = true }) {
                Text("最初のタグを作成")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    @ViewBuilder
    private var emptySearchView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("「\(searchText)」に一致するタグがありません")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text("検索条件を変更するか、新しいタグを作成してください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    @ViewBuilder
    private var createButton: some View {
        Button(action: { showingCreateTag = true }) {
            Image(systemName: "plus")
        }
        .accessibilityLabel("新しいタグを作成")
    }
    
    @ViewBuilder
    private var cleanupButton: some View {
        Button(action: cleanupUnusedTags) {
            Image(systemName: "trash")
        }
        .foregroundColor(.red)
        .accessibilityLabel("未使用タグを削除")
    }
    
    // MARK: - Helper Methods
    
    private func confirmDelete(_ tag: TaskTag) {
        tagToDelete = tag
        showingDeleteConfirmation = true
    }
    
    @ViewBuilder
    private func deleteConfirmationAlert(for tag: TaskTag) -> some View {
        Group {
            Button("削除", role: .destructive) {
                Task {
                    do {
                        try await tagManager.deleteTag(tag)
                    } catch {
                        print("Failed to delete tag: \(error)")
                    }
                }
            }
            
            Button("キャンセル", role: .cancel) {
                tagToDelete = nil
            }
        }
    }
    
    @ViewBuilder
    private func deleteConfirmationMessage(for tag: TaskTag) -> some View {
        if tag.usageCount > 0 {
            Text("このタグは\(tag.usageCount)個のタスクで使用されています。削除すると、これらのタスクからタグが解除されます。")
        } else {
            Text("このタグを削除してもよろしいですか？")
        }
    }
    
    private func cleanupUnusedTags() {
        Task {
            do {
                try await tagManager.cleanupUnusedTags(projectId: projectId)
            } catch {
                print("Failed to cleanup unused tags: \(error)")
            }
        }
    }
}

// MARK: - TagManagementRow

struct TagManagementRow: View {
    let tag: TaskTag
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Tag Preview
            TagChip(tag: tag, size: .medium, isSelected: false) {
                // No action - just preview
            }
            .allowsHitTesting(false)
            
            // Tag Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tag.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    if tag.usageCount > 0 {
                        Text("\(tag.usageCount)回使用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    } else {
                        Text("未使用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("作成日: \(tag.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "不明")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let lastUsed = tag.lastUsedFormatted {
                        Text("最終使用: \(lastUsed)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Action Buttons
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("タグを編集")
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("タグを削除")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - EditTagView

struct EditTagView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tagName: String
    @State private var selectedColor: String
    @State private var emoji: String
    @State private var isUpdating = false
    @State private var errorMessage: String?
    
    let tag: TaskTag
    let onTagUpdated: (TaskTag) -> Void
    
    init(tag: TaskTag, onTagUpdated: @escaping (TaskTag) -> Void) {
        self.tag = tag
        self.onTagUpdated = onTagUpdated
        self._tagName = State(initialValue: tag.name)
        self._selectedColor = State(initialValue: tag.color)
        self._emoji = State(initialValue: tag.emoji ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Tag Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("タグ名")
                                .font(.headline)
                            
                            TextField("タグ名を入力", text: $tagName)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }
                        
                        // Emoji
                        VStack(alignment: .leading, spacing: 8) {
                            Text("絵文字（任意）")
                                .font(.headline)
                            
                            TextField("🏷️", text: $emoji)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }
                        
                        // Color Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("色")
                                .font(.headline)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                                ForEach(TaskTag.defaultColors, id: \.self) { color in
                                    Button(action: {
                                        selectedColor = color
                                    }) {
                                        Circle()
                                            .fill(Color(hex: color) ?? Color.accentColor)
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("色を選択: \(color)")
                                }
                            }
                        }
                        
                        // Usage Stats
                        VStack(alignment: .leading, spacing: 8) {
                            Text("使用状況")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("使用回数: \(tag.usageCount)回")
                                    .font(.subheadline)
                                
                                if let lastUsed = tag.lastUsedFormatted {
                                    Text("最終使用: \(lastUsed)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("作成日: \(tag.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "不明")")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        // Preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("プレビュー")
                                .font(.headline)
                            
                            HStack {
                                let previewTag = TaskTag(
                                    name: tagName.isEmpty ? "タグ名" : tagName,
                                    color: selectedColor,
                                    emoji: emoji.isEmpty ? nil : emoji,
                                    projectId: tag.projectId,
                                    createdBy: tag.createdBy
                                )
                                
                                TagChip(tag: previewTag, isSelected: false) {
                                    // No action in preview
                                }
                                
                                TagChip(tag: previewTag, isSelected: true) {
                                    // No action in preview
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 32)
                    
                    // Update Button
                    VStack(spacing: 16) {
                        Button(action: updateTag) {
                            HStack {
                                if isUpdating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 4)
                                }
                                Text(isUpdating ? "更新中..." : "更新")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUpdating)
                        
                        Button("キャンセル") {
                            dismiss()
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("タグ編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func updateTag() {
        let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "タグ名を入力してください"
            return
        }
        
        isUpdating = true
        errorMessage = nil
        
        Task {
            do {
                let tagManager = TagManager()
                try await tagManager.updateTag(
                    tag,
                    name: trimmedName != tag.name ? trimmedName : nil,
                    color: selectedColor != tag.color ? selectedColor : nil,
                    emoji: emoji != (tag.emoji ?? "") ? (emoji.isEmpty ? nil : emoji) : nil
                )
                
                // Create updated tag for callback
                var updatedTag = tag
                updatedTag.name = trimmedName
                updatedTag.color = selectedColor
                updatedTag.emoji = emoji.isEmpty ? nil : emoji
                updatedTag.displayName = emoji.isEmpty ? trimmedName : "\(emoji) \(trimmedName)"
                
                await MainActor.run {
                    onTagUpdated(updatedTag)
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isUpdating = false
                    if let tagError = error as? TagError {
                        errorMessage = tagError.errorDescription
                    } else {
                        errorMessage = "タグの更新に失敗しました"
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TagManagementView(
        projectId: "project1",
        createdBy: "user1"
    )
}