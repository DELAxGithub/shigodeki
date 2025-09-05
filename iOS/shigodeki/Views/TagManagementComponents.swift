import SwiftUI

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

// MARK: - TagSearchBar

struct TagSearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("タグを検索...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - TagListView

struct TagListView: View {
    let tags: [TaskTag]
    let onEdit: (TaskTag) -> Void
    let onDelete: (TaskTag) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(tags, id: \.id) { tag in
                    TagManagementRow(
                        tag: tag,
                        onEdit: { onEdit(tag) },
                        onDelete: { onDelete(tag) }
                    )
                    .background(Color(.systemBackground))
                    
                    if tag != tags.last {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }
}

// MARK: - Empty States

struct TagEmptyStateView: View {
    let onCreateTag: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("タグがまだありません")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("プロジェクト用のタグを作成して、タスクを整理しましょう")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: onCreateTag) {
                HStack {
                    Image(systemName: "plus")
                    Text("最初のタグを作成")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct TagEmptySearchView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("検索結果がありません")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("「\(searchText)」に一致するタグが見つかりませんでした")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Action Buttons

struct TagCreateButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus")
                Text("新しいタグ")
            }
        }
        .accessibilityLabel("新しいタグを作成")
    }
}

struct TagCleanupButton: View {
    let hasUnusedTags: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "trash")
                Text("未使用のタグを削除")
            }
        }
        .disabled(!hasUnusedTags)
        .accessibilityLabel("未使用のタグを削除")
    }
}