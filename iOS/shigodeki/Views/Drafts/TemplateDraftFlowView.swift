import SwiftUI

struct TemplateDraftFlowView: View {
    let onComplete: (TaskDraftSource, [TaskDraft]) -> Void
    let onCancel: () -> Void

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("ライフイベントテンプレート")) {
                    ForEach(TemplateQuickPick.allCases, id: \.self) { quickPick in
                        Button {
                            select(quickPick)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(quickPick.title)
                                    .font(.headline)
                                Text(quickPick.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .navigationTitle("テンプレート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", action: onCancel)
                }
            }
            .alert("エラー", isPresented: Binding(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func select(_ quickPick: TemplateQuickPick) {
        let drafts = TemplateDraftBuilder.build(for: quickPick)
        guard drafts.isEmpty == false else {
            errorMessage = "テンプレートの読み込みに失敗しました"
            return
        }
        onComplete(.template, drafts)
    }
}

#Preview {
    TemplateDraftFlowView(onComplete: { _, _ in }, onCancel: {})
}
