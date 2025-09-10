import SwiftUI

struct ProjectTypePickerView: View {
    @Binding var selectedType: ProjectType?
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("プロジェクトタイプ")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("AIがより適切なタスクを生成するために\nプロジェクトの種類を選択してください")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Project types grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(ProjectType.allCases) { projectType in
                            ProjectTypeCard(
                                projectType: projectType,
                                isSelected: selectedType == projectType
                            ) {
                                selectedType = projectType
                                dismiss()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("プロジェクトタイプ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                if selectedType != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完了") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct ProjectTypeCard: View {
    let projectType: ProjectType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(projectType.color.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: projectType.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(projectType.color)
                }
                
                VStack(spacing: 4) {
                    Text(projectType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(projectType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? projectType.color.opacity(0.1) : Color(.systemGray6))
                    .stroke(isSelected ? projectType.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .interactiveEffect()
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - ProjectType Extension

extension ProjectType {
    var description: String {
        switch self {
        case .work:
            return "ビジネス目標と専門的なワークフロー"
        case .personal:
            return "個人の目標とワークライフバランス"
        case .family:
            return "家族の協力と年齢に適したタスク"
        case .creative:
            return "芸術的プロセスと創造的なマイルストーン"
        case .learning:
            return "研究段階と知識構築のステップ"
        case .health:
            return "段階的な進歩と持続可能性"
        case .travel:
            return "計画段階と旅行ロジスティクス"
        case .home:
            return "実践的なステップと安全性"
        case .financial:
            return "研究、分析、体系的な金融ステップ"
        case .social:
            return "グループ調整と社会的ダイナミクス"
        case .custom:
            return "柔軟で幅広く適用可能"
        }
    }
}

#Preview {
    ProjectTypePickerView(selectedType: .constant(.work))
}
