import SwiftUI

struct ProjectInfoSection: View {
    let project: Project
    let ownerDisplayName: String
    let memberCount: Int
    let createdAtOverride: Date?
    
    var body: some View {
        Section(header: Text("プロジェクト情報")) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text("作成者")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ownerDisplayName.isEmpty ? "読み込み中..." : ownerDisplayName)
                        .font(.subheadline)
                        .foregroundColor(ownerDisplayName.isEmpty ? .secondary : .primary)
                }
            }
            
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text("メンバー数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(memberCount)人")
                        .font(.subheadline)
                }
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text("作成日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ProjectInfoSection.formatDate(createdAtOverride ?? project.createdAt))
                        .font(.subheadline)
                }
            }
            
            if let lastModified = project.lastModifiedAt {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("最終更新")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ProjectInfoSection.formatDate(lastModified))
                            .font(.subheadline)
                    }
                }
            }
        }
    }
    
    static func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "不明" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}
