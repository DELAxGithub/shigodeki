//
//  PhotoDraftFlowView.swift
//  shigodeki
//
//  Step 0 placeholder. Photo-based draft generation will be wired later.
//

import SwiftUI

struct PhotoDraftFlowView: View {
    let contextHint: String?
    let onComplete: (TaskDraftSource, [TaskDraft]) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "camera")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("写真からのタスク生成は近日公開予定です")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Button("閉じる", action: onCancel)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("写真から提案")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    PhotoDraftFlowView(contextHint: nil, onComplete: { _, _ in }, onCancel: {})
}
