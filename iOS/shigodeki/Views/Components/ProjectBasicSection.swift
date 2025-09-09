import SwiftUI

struct ProjectBasicSection: View {
    @Binding var projectName: String
    @Binding var projectDescription: String
    @Binding var isCompleted: Bool
    @Binding var isUpdating: Bool
    @Binding var showingDeleteConfirmation: Bool
    let onFieldChange: () -> Void
    
    var body: some View {
        Group {
            Section(header: Text("基本情報")) {
                TextField("プロジェクト名", text: $projectName)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(false)
                    .onChange(of: projectName) { _, _ in onFieldChange() }
                
                ZStack(alignment: .topLeading) {
                    if projectDescription.isEmpty {
                        VStack {
                            HStack {
                                Text("プロジェクトの説明")
                                    .foregroundColor(Color(.placeholderText))
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(.top, 8)
                        .padding(.leading, 4)
                    }
                    
                    TextEditor(text: $projectDescription)
                        .frame(minHeight: 80)
                        .onChange(of: projectDescription) { _, _ in onFieldChange() }
                }
            }
            
            Section(header: Text("ステータス")) {
                Toggle("完了済み", isOn: $isCompleted)
                    .onChange(of: isCompleted) { _, _ in onFieldChange() }
                
                if isCompleted {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("完了済みのプロジェクトは読み取り専用になります")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("危険な操作")) {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("プロジェクトを削除")
                            .foregroundColor(.red)
                    }
                }
                .disabled(isUpdating)
            }
        }
    }
}
