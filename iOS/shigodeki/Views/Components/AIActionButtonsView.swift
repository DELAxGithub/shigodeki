import SwiftUI

/// AI機能が利用可能な場合のアクションUI（誤タップを避けるため明確に分離したカード型）
struct AIActionButtonsView: View {
    let onGenerateSubtasks: () -> Void
    let onGenerateDetails: () -> Void
    let isDisabled: Bool
    
    init(onGenerateSubtasks: @escaping () -> Void,
         onGenerateDetails: @escaping () -> Void,
         isDisabled: Bool = false) {
        self.onGenerateSubtasks = onGenerateSubtasks
        self.onGenerateDetails = onGenerateDetails
        self.isDisabled = isDisabled
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // サブタスク分割（カード）
            ActionCard(action: {
                print("🟦 Button pressed: Generate Subtasks")
                onGenerateSubtasks()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.primaryBlue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AIでサブタスク分割")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        Text("実行可能な手順を自動作成")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondaryText)
                        .font(.caption)
                }
            }
            .disabled(isDisabled)
            .accessibilityHint("AIがタスクを複数のサブタスクに分割します")
            
            // 詳細提案（カード）
            ActionCard(action: {
                print("🟦 Button pressed: Generate Detail")
                onGenerateDetails()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "text.magnifyingglass")
                        .foregroundColor(.primaryBlue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AIで詳細提案")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        Text("説明文・手順・注意点を生成")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondaryText)
                        .font(.caption)
                }
            }
            .disabled(isDisabled)
            .accessibilityHint("AIがタスクの詳細な説明と手順を提案します")
        }
    }
}

#Preview {
    VStack {
        AIActionButtonsView(
            onGenerateSubtasks: {
                print("Generate subtasks")
            },
            onGenerateDetails: {
                print("Generate details")
            }
        )
        
        Divider()
        
        AIActionButtonsView(
            onGenerateSubtasks: { },
            onGenerateDetails: { },
            isDisabled: true
        )
        .opacity(0.6)
    }
    .padding()
}
