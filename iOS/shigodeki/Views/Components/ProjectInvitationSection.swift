import SwiftUI

struct ProjectInvitationSection: View {
    @Binding var selectedInviteRole: Role
    @Binding var isUpdating: Bool
    let onCreateInvite: () -> Void
    
    var body: some View {
        Section(header: Text("招待")) {
            Picker("権限", selection: $selectedInviteRole) {
                ForEach(Role.allCases, id: \.self) { role in
                    Text(role.displayName).tag(role)
                }
            }
            Button {
                onCreateInvite()
            } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("招待コードを作成")
                }
            }
            .disabled(isUpdating)
        }
    }
}

struct ProjectInvitationSheet: View {
    let project: Project
    let inviteCode: String
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            Text("招待コード")
                .font(.title2).bold()
            Text(inviteCode)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .onTapGesture { UIPasteboard.general.string = inviteCode }
            Text("タップしてコピー").font(.caption).foregroundColor(.secondary)
            Button {
                let act = UIActivityViewController(activityItems: ["プロジェクト『\(project.name)』への招待コード: \(inviteCode)"], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let win = scene.windows.first {
                    win.rootViewController?.present(act, animated: true)
                }
            } label: {
                Label("招待コードを共有", systemImage: "square.and.arrow.up")
                    .padding().frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }
}