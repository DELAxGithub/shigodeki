//
//  TagInputComponents.swift
//  shigodeki
//
//  Extracted from TagInputView.swift for CLAUDE.md compliance
//  Tag input UI components and selection interface
//

import SwiftUI

// MARK: - Selected Tags Display

struct SelectedTagsDisplayView: View {
    let selectedTags: [String]
    let availableTags: [TaskTag]
    let onRemoveTag: (String) -> Void
    
    var body: some View {
        if !selectedTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("選択中のタグ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedTags, id: \.self) { tagName in
                            let tagMaster = availableTags.first { $0.name == tagName }
                            
                            if let tag = tagMaster {
                                TagChip(tag: tag, isSelected: true) {
                                    onRemoveTag(tagName)
                                }
                            } else {
                                TagChip(tagName: tagName, isSelected: true) {
                                    onRemoveTag(tagName)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 1) // Prevent clipping
                }
            }
        }
    }
}

// MARK: - Available Tags Grid

struct AvailableTagsGridView: View {
    let filteredTags: [TaskTag]
    let selectedTags: [String]
    let searchText: String
    let canCreateTag: Bool
    let onToggleTag: (String) -> Void
    let onShowCreateTag: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                
                // Create option at top when applicable
                if canCreateTag {
                    Button(action: onShowCreateTag) {
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
                    .interactiveEffect()
                    .accessibilityLabel("新しいタグ「\(searchText)」を作成")
                }
                
                // Existing tags
                ForEach(filteredTags) { tag in
                    TagChip(
                        tag: tag,
                        isSelected: selectedTags.contains(tag.name)
                    ) {
                        onToggleTag(tag.name)
                    }
                }
            }
            .padding(.horizontal, 1) // Prevent clipping
        }
    }
}

// MARK: - Tag Color Selection Grid

struct TagColorSelectionView: View {
    @Binding var selectedColor: String
    let availableColors: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("色")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(availableColors, id: \.self) { color in
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
                    .interactiveEffect()
                    .accessibilityLabel("色を選択: \(color)")
                }
            }
        }
    }
}

// MARK: - Tag Preview Section

struct TagPreviewSection: View {
    let tagName: String
    let selectedColor: String
    let emoji: String
    let projectId: String
    let createdBy: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プレビュー")
                .font(.headline)
            
            HStack {
                let previewTag = TaskTag(
                    name: tagName.isEmpty ? "タグ名" : tagName,
                    color: selectedColor,
                    emoji: emoji.isEmpty ? nil : emoji,
                    projectId: projectId,
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
}

// MARK: - Create Tag Form Content

struct CreateTagFormContent: View {
    @Binding var tagName: String
    @Binding var emoji: String
    @Binding var selectedColor: String
    let projectId: String
    let createdBy: String
    
    var body: some View {
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
            TagColorSelectionView(
                selectedColor: $selectedColor,
                availableColors: TaskTag.defaultColors
            )
            
            // Preview
            TagPreviewSection(
                tagName: tagName,
                selectedColor: selectedColor,
                emoji: emoji,
                projectId: projectId,
                createdBy: createdBy
            )
        }
    }
}

// MARK: - Create Tag Action Button

struct CreateTagActionButton: View {
    let tagName: String
    let isCreating: Bool
    let onCreateTag: () -> Void
    
    var body: some View {
        Button(action: onCreateTag) {
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
    }
}
