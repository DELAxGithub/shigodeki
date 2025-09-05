import SwiftUI

/// API設定が必要な場合の案内表示
struct AIConfigurationPromptView: View {
    let guidance: ConfigurationGuidance
    let onNavigateToSettings: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 警告アイコンと案内メッセージ
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(guidance.message)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            // 設定画面への案内ボタン
            Button {
                onNavigateToSettings()
            } label: {
                Label("AI設定を開く", systemImage: "gear")
                    .font(.caption)
            }
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.small)
            
            // 詳細説明
            Text(guidance.actionRequired)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI設定が必要")
        .accessibilityHint("AI機能を使用するためのAPIキー設定が必要です")
    }
}

#Preview {
    AIConfigurationPromptView(
        guidance: ConfigurationGuidance.createDefault(),
        onNavigateToSettings: {
            print("Navigate to settings")
        }
    )
    .padding()
}