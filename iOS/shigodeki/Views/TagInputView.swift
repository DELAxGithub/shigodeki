//
//  TagInputView.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import SwiftUI

// MARK: - TagInputView

struct TagInputView: View {
    @State private var searchText: String = ""
    @State private var showingCreateTag = false
    @Binding var selectedTags: [String]
    
    let availableTags: [TaskTag]
    let familyId: String
    let createdBy: String
    let onTagCreated: (TaskTag) -> Void
    
    // MARK: - Computed Properties
    
    var filteredTags: [TaskTag] {
        if searchText.isEmpty {
            return availableTags.sorted { $0.usageCount > $1.usageCount }
        }
        return availableTags.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.usageCount > $1.usageCount }
    }
    
    var canCreateTag: Bool {
        !searchText.isEmpty && !availableTags.contains { 
            $0.name.lowercased() == searchText.lowercased() 
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search Field
            TextField("タグを検索または新規作成...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("タグ検索フィールド")
                .accessibilityHint("タグ名を入力して検索するか、新しいタグを作成します")
            
            // Selected Tags Display
            if !selectedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("選択中のタグ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedTags, id: \.self) { tagName in
                                // Find the full tag info or use simple name
                                let tagMaster = availableTags.first { $0.name == tagName }
                                
                                if let tag = tagMaster {
                                    TagChip(tag: tag, isSelected: true) {
                                        removeTag(tagName)
                                    }
                                } else {
                                    TagChip(tagName: tagName, isSelected: true) {
                                        removeTag(tagName)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 1) // Prevent clipping
                    }
                }
            }
            
            // Available Tags & Create Option
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    
                    // UX Improvement: Show create option at top when applicable
                    if canCreateTag {
                        Button(action: {
                            showingCreateTag = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption2)
                                Text("\"\(searchText)\"を作成")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("新しいタグ「\(searchText)」を作成")
                    }
                    
                    // Existing tags
                    ForEach(filteredTags) { tag in
                        TagChip(
                            tag: tag,
                            isSelected: selectedTags.contains(tag.name)
                        ) {
                            toggleTag(tag.name)
                        }
                    }
                }
                .padding(.horizontal, 1) // Prevent clipping
            }
        }
        .sheet(isPresented: $showingCreateTag) {
            CreateTagView(
                initialName: searchText,
                familyId: familyId,
                createdBy: createdBy,
                onTagCreated: { newTag in
                    onTagCreated(newTag)
                    // Auto-select the newly created tag
                    if !selectedTags.contains(newTag.name) {
                        selectedTags.append(newTag.name)
                    }
                    // Clear search to show all tags again
                    searchText = ""
                }
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleTag(_ tagName: String) {
        if let index = selectedTags.firstIndex(of: tagName) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tagName)
        }
    }
    
    private func removeTag(_ tagName: String) {
        selectedTags.removeAll { $0 == tagName }
    }
}

// MARK: - CreateTagView

struct CreateTagView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tagName: String
    @State private var selectedColor: String = TaskTag.randomColor()
    @State private var emoji: String = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    let familyId: String
    let createdBy: String
    let onTagCreated: (TaskTag) -> Void
    
    init(initialName: String = "", familyId: String, createdBy: String, onTagCreated: @escaping (TaskTag) -> Void) {
        self._tagName = State(initialValue: initialName)
        self.familyId = familyId
        self.createdBy = createdBy
        self.onTagCreated = onTagCreated
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
                            
                            TextField("例: 重要", text: $tagName)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }
                        
                        // Emoji (Optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("絵文字（任意）")
                                .font(.headline)
                            
                            TextField("🔥", text: $emoji)
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
                        
                        // Preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("プレビュー")
                                .font(.headline)
                            
                            HStack {
                                let previewTag = TaskTag(
                                    name: tagName.isEmpty ? "タグ名" : tagName,
                                    color: selectedColor,
                                    emoji: emoji.isEmpty ? nil : emoji,
                                    familyId: familyId,
                                    createdBy: createdBy
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
                    
                    // Create Button
                    VStack(spacing: 16) {
                        Button(action: createTag) {
                            HStack {
                                if isCreating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 4)
                                }
                                Text(isCreating ? "作成中..." : "タグを作成")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                        
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
            .navigationTitle("新しいタグ")
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
    
    private func createTag() {
        let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "タグ名を入力してください"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                let tagManager = TagManager()
                let tagId = try await tagManager.createTag(
                    name: trimmedName,
                    color: selectedColor,
                    emoji: emoji.isEmpty ? nil : emoji,
                    familyId: familyId,
                    createdBy: createdBy
                )
                
                // Create the tag object to pass back
                var newTag = TaskTag(
                    name: trimmedName,
                    color: selectedColor,
                    emoji: emoji.isEmpty ? nil : emoji,
                    familyId: familyId,
                    createdBy: createdBy
                )
                newTag.id = tagId
                
                await MainActor.run {
                    onTagCreated(newTag)
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isCreating = false
                    if let tagError = error as? TagError {
                        errorMessage = tagError.errorDescription
                    } else {
                        errorMessage = "タグの作成に失敗しました"
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleTags = [
        TaskTag(name: "重要", color: "#FF3B30", emoji: "🔥", familyId: "family1", createdBy: "user1"),
        TaskTag(name: "緊急", color: "#FF9500", emoji: "⚡", familyId: "family1", createdBy: "user1"),
        TaskTag(name: "会議", color: "#007AFF", emoji: "🗣️", familyId: "family1", createdBy: "user1")
    ]
    
    TagInputView(
        selectedTags: .constant(["重要"]),
        availableTags: sampleTags,
        familyId: "family1",
        createdBy: "user1",
        onTagCreated: { _ in }
    )
    .padding()
}