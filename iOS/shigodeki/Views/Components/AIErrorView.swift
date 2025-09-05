import SwiftUI

/// AI機能のエラー表示と復旧操作
struct AIErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onOpenSettings: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // エラーメッセージ表示
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                Text("エラー: \(message)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("エラーが発生しました")
            .accessibilityValue(message)
            
            // 復旧操作ボタン
            HStack(spacing: 12) {
                // 再試行ボタン
                Button {
                    onRetry()
                } label: {
                    Label("再試行", systemImage: "arrow.clockwise")
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
                .accessibilityHint("AI機能の再試行を行います")
                
                // 設定画面ボタン
                Button {
                    onOpenSettings()
                } label: {
                    Label("設定", systemImage: "gear")
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
                .accessibilityHint("AI設定画面を開きます")
            }
            
            // ヘルプテキスト
            Text("APIキーの設定を確認するか、しばらく時間をおいて再試行してください。")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: 20) {
        AIErrorView(
            message: "APIキーが無効です",
            onRetry: {
                print("Retry")
            },
            onOpenSettings: {
                print("Open settings")
            }
        )
        
        AIErrorView(
            message: "ネットワークエラーが発生しました",
            onRetry: {
                print("Retry")
            },
            onOpenSettings: {
                print("Open settings")
            }
        )
        
        AIErrorView(
            message: "API利用上限に達しました",
            onRetry: {
                print("Retry")
            },
            onOpenSettings: {
                print("Open settings")
            }
        )
    }
    .padding()
}