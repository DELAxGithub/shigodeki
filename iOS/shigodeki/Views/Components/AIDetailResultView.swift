import SwiftUI

/// AI詳細提案結果の表示と操作
struct AIDetailResultView: View {
    let result: AIDetailResult
    let onApply: (String) -> Void
    let onEdit: (String) -> Void
    let onReject: () -> Void
    
    @State private var showingEditSheet = false
    @State private var editedContent: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // AI提案内容表示
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                    Text("AI提案")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(result.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(result.content)
                    .font(.body)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .accessibilityLabel("AI提案内容")
                    .accessibilityValue(result.content)
            }
            
            // 操作ボタン
            HStack(spacing: 12) {
                // 適用ボタン
                Button {
                    onApply(result.content)
                } label: {
                    Label("適用", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
                .accessibilityHint("AI提案をタスクに適用します")
                
                // 編集して適用ボタン
                Button {
                    editedContent = result.content
                    showingEditSheet = true
                } label: {
                    Label("編集", systemImage: "pencil.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
                .accessibilityHint("AI提案を編集してから適用します")
                
                // 却下ボタン
                Button {
                    onReject()
                } label: {
                    Label("却下", systemImage: "xmark.circle")
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
                .accessibilityHint("AI提案を却下します")
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingEditSheet) {
            AIEditSheet(
                content: editedContent,
                onSave: { editedText in
                    onApply(editedText)
                },
                onCancel: {
                    showingEditSheet = false
                }
            )
        }
    }
}

/// AI提案の編集シート
private struct AIEditSheet: View {
    @State var content: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("AI提案の編集") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("提案を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("適用") {
                        onSave(content)
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    AIDetailResultView(
        result: AIDetailResult(content: "このタスクを完了するには、以下の手順で進めることをお勧めします：\n\n1. 要件を明確化\n2. 設計書を作成\n3. 実装を開始\n4. テストを実行\n\n各ステップで品質を確認しながら進めてください。"),
        onApply: { content in
            print("Apply: \(content)")
        },
        onEdit: { content in
            print("Edit: \(content)")
        },
        onReject: {
            print("Reject")
        }
    )
    .padding()
}