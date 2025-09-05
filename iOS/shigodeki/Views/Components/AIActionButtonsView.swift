import SwiftUI

/// AI機能が利用可能な場合のアクションボタン
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
        VStack(spacing: 8) {
            // サブタスク分割ボタン
            Button {
                onGenerateSubtasks()
            } label: {
                Label("AIでサブタスク分割", systemImage: "wand.and.stars")
            }
            .disabled(isDisabled)
            .accessibilityHint("AIがタスクを複数のサブタスクに分割します")
            
            // 詳細提案ボタン
            Button {
                onGenerateDetails()
            } label: {
                Label("AIで詳細提案", systemImage: "text.magnifyingglass")
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