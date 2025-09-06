//
//  TemplateEditorComponents.swift
//  shigodeki
//
//  Extracted from TemplateCustomizationComponents.swift for CLAUDE.md compliance
//  Template editing and customization form components
//

import SwiftUI

// MARK: - Template Name Editor

struct TemplateNameEditor: View {
    @Binding var name: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("テンプレート名")
                .font(.headline)
            
            TextField(placeholder, text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.body)
        }
    }
}

// MARK: - Template Description Editor

struct TemplateDescriptionEditor: View {
    @Binding var description: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("説明")
                .font(.headline)
            
            TextField(placeholder, text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .lineLimit(3...6)
        }
    }
}

// MARK: - Category Selector

struct CategorySelector: View {
    @Binding var selectedCategory: TemplateCategory
    let categories: [TemplateCategory]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カテゴリ")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        CategoryButton(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct CategoryButton: View {
    let category: TemplateCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? category.color.opacity(0.2) : Color(.systemGray6))
                .foregroundColor(isSelected ? category.color : .secondary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Difficulty Selector

struct DifficultySelector: View {
    @Binding var selectedDifficulty: TemplateDifficulty
    let difficulties: [TemplateDifficulty]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("難易度")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(difficulties, id: \.self) { difficulty in
                    DifficultyButton(
                        difficulty: difficulty,
                        isSelected: selectedDifficulty == difficulty
                    ) {
                        selectedDifficulty = difficulty
                    }
                }
            }
        }
    }
}

struct DifficultyButton: View {
    let difficulty: TemplateDifficulty
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                DifficultyIcon(difficulty: difficulty)
                
                Text(difficulty.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? difficulty.color.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? difficulty.color : .secondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct DifficultyIcon: View {
    let difficulty: TemplateDifficulty
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...4, id: \.self) { level in
                Circle()
                    .fill(level <= difficulty.stars ? difficulty.color : Color(.systemGray5))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Tags Editor

struct TemplateTagsEditor: View {
    @Binding var tags: [String]
    @State private var newTag: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("タグ")
                .font(.headline)
            
            TagInputField(newTag: $newTag, onAddTag: addTag)
            
            if !tags.isEmpty {
                TagsFlowLayout(tags: tags, onRemoveTag: removeTag)
            }
        }
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
            newTag = ""
        }
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

struct TagInputField: View {
    @Binding var newTag: String
    let onAddTag: () -> Void
    
    var body: some View {
        HStack {
            TextField("新しいタグを入力", text: $newTag)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onAddTag)
            
            Button("追加", action: onAddTag)
                .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

struct TagsFlowLayout: View {
    let tags: [String]
    let onRemoveTag: (String) -> Void
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                TagChip(
                    tagName: tag,
                    action: { onRemoveTag(tag) }
                )
            }
        }
    }
}