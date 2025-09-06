//
//  TagInputView.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - Lightweight coordinator view
//  UI components extracted to TagInputComponents.swift
//  Business logic extracted to TagCreationService.swift
//

import SwiftUI

// MARK: - TagInputView

struct TagInputView: View {
    @State private var searchText: String = ""
    @State private var showingCreateTag = false
    @Binding var selectedTags: [String]
    
    let availableTags: [TaskTag]
    let projectId: String
    let ownerId: String
    let ownerType: ProjectOwnerType
    let createdBy: String
    let onTagCreated: (TaskTag) -> Void
    
    @StateObject private var tagService = TagCreationService()
    
    // MARK: - Computed Properties
    
    var filteredTags: [TaskTag] {
        tagService.filterTags(availableTags, searchText: searchText)
    }
    
    var canCreateTag: Bool {
        tagService.canCreateTag(searchText: searchText, availableTags: availableTags)
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
            SelectedTagsDisplayView(
                selectedTags: selectedTags,
                availableTags: availableTags,
                onRemoveTag: removeTag
            )
            
            // Available Tags & Create Option
            AvailableTagsGridView(
                filteredTags: filteredTags,
                selectedTags: selectedTags,
                searchText: searchText,
                canCreateTag: canCreateTag,
                onToggleTag: toggleTag,
                onShowCreateTag: { showingCreateTag = true }
            )
        }
        .sheet(isPresented: $showingCreateTag) {
            CreateTagView(
                initialName: searchText,
                projectId: projectId,
                createdBy: createdBy,
                tagService: tagService,
                onTagCreated: handleTagCreated
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleTag(_ tagName: String) {
        tagService.toggleTagSelection(tagName, in: &selectedTags)
    }
    
    private func removeTag(_ tagName: String) {
        tagService.removeTagFromSelection(tagName, from: &selectedTags)
    }
    
    private func handleTagCreated(_ newTag: TaskTag) {
        onTagCreated(newTag)
        tagService.addTagToSelection(newTag.name, to: &selectedTags)
        searchText = ""
    }
}

// MARK: - CreateTagView

struct CreateTagView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tagName: String
    @State private var selectedColor: String = TaskTag.randomColor()
    @State private var emoji: String = ""
    
    let projectId: String
    let createdBy: String
    let tagService: TagCreationService
    let onTagCreated: (TaskTag) -> Void
    
    init(initialName: String = "", projectId: String, createdBy: String, tagService: TagCreationService, onTagCreated: @escaping (TaskTag) -> Void) {
        self._tagName = State(initialValue: initialName)
        self.projectId = projectId
        self.createdBy = createdBy
        self.tagService = tagService
        self.onTagCreated = onTagCreated
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    CreateTagFormContent(
                        tagName: $tagName,
                        emoji: $emoji,
                        selectedColor: $selectedColor,
                        projectId: projectId,
                        createdBy: createdBy
                    )
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Error Message
                    if let errorMessage = tagService.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 32)
                    
                    // Create Button
                    VStack(spacing: 16) {
                        CreateTagActionButton(
                            tagName: tagName,
                            isCreating: tagService.isCreating,
                            onCreateTag: createTag
                        )
                        
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
        Task {
            do {
                let newTag = try await tagService.createTag(
                    name: tagName,
                    color: selectedColor,
                    emoji: emoji,
                    projectId: projectId,
                    createdBy: createdBy
                )
                onTagCreated(newTag)
                dismiss()
            } catch {
                // Error handling is managed by tagService
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleTags = [
        TaskTag(name: "重要", color: "#FF3B30", emoji: "🔥", projectId: "project1", createdBy: "user1"),
        TaskTag(name: "緊急", color: "#FF9500", emoji: "⚡", projectId: "project1", createdBy: "user1"),
        TaskTag(name: "会議", color: "#007AFF", emoji: "🗣️", projectId: "project1", createdBy: "user1")
    ]
    
    TagInputView(
        selectedTags: .constant(["重要"]),
        availableTags: sampleTags,
        projectId: "project1",
        ownerId: "family1",
        ownerType: .family,
        createdBy: "user1",
        onTagCreated: { _ in }
    )
    .padding()
}