import SwiftUI

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
                    errorMessage = "タグの更新に失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }
}