import SwiftUI

/// AI処理中の状態表示
struct AIStatusIndicatorView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .accessibilityHidden(true)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI処理中")
        .accessibilityValue(message)
    }
}

#Preview {
    VStack(spacing: 16) {
        AIStatusIndicatorView(message: "AIがタスクを分析中です...")
        
        AIStatusIndicatorView(message: "Connecting to OpenAI...")
        
        AIStatusIndicatorView(message: "Processing suggestions...")
    }
    .padding()
}