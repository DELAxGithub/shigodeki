//
//  TemplateCustomizationComponents.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - Main customization view only
//  UI components extracted to TemplateHeaderComponents.swift and TemplateEditorComponents.swift
//

import SwiftUI

// MARK: - Main Customization View

struct TemplateEditorView: View {
    @State private var customizedTemplate: ProjectTemplate
    @State private var isModified = false
    @Environment(\.dismiss) private var dismiss
    
    let originalTemplate: ProjectTemplate
    let onSave: (ProjectTemplate) -> Void
    
    init(template: ProjectTemplate, onSave: @escaping (ProjectTemplate) -> Void) {
        self.originalTemplate = template
        self._customizedTemplate = State(initialValue: template)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            TemplateEditorContent(
                template: $customizedTemplate,
                isModified: $isModified,
                originalTemplate: originalTemplate
            )
            .navigationTitle("テンプレート編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(customizedTemplate)
                        dismiss()
                    }
                    .disabled(!isModified)
                }
            }
        }
    }
}

// MARK: - Content View

struct TemplateEditorContent: View {
    @Binding var template: ProjectTemplate
    @Binding var isModified: Bool
    let originalTemplate: ProjectTemplate
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TemplateHeader(template: template)
                
                VStack(spacing: 16) {
                    // Note: Template name is immutable, using display only
                    VStack(alignment: .leading, spacing: 8) {
                        Text("テンプレート名")
                            .font(.headline)
                        
                        Text(template.name)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Note: Template description is immutable, using display only
                    VStack(alignment: .leading, spacing: 8) {
                        Text("説明")
                            .font(.headline)
                        
                        Text(template.description ?? "説明なし")
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Note: Template category is immutable, using display only
                    VStack(alignment: .leading, spacing: 8) {
                        Text("カテゴリ")
                            .font(.headline)
                        
                        CategoryBadge(category: template.category)
                    }
                    
                    // Note: Template difficulty is immutable, using display only
                    VStack(alignment: .leading, spacing: 8) {
                        Text("難易度")
                            .font(.headline)
                        
                        HStack(spacing: 6) {
                            DifficultyIcon(difficulty: template.metadata.difficulty)
                            
                            Text(template.metadata.difficulty.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(template.metadata.difficulty.color.opacity(0.2))
                        .foregroundColor(template.metadata.difficulty.color)
                        .cornerRadius(8)
                    }
                    
                    // Note: Template tags are immutable, using display only
                    VStack(alignment: .leading, spacing: 8) {
                        Text("タグ")
                            .font(.headline)
                        
                        if !template.metadata.tags.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading, spacing: 8) {
                                ForEach(template.metadata.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray5))
                                        .foregroundColor(.primary)
                                        .cornerRadius(12)
                                }
                            }
                        } else {
                            Text("タグなし")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func checkModifications() {
        isModified = template != originalTemplate
    }
}