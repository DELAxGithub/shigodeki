//
//  AssigneeSectionView.swift
//  shigodeki
//
//  Component for task assignee selection with project members
//  Implements SwiftUI Picker for member assignment functionality
//

import SwiftUI
import FirebaseFirestore

struct AssigneeSectionView: View {
    let members: [ProjectMember]
    @Binding var assignedTo: String?
    
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @State private var userNames: [String: String] = [:]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("担当者")
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "person.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Picker("担当者を選択", selection: $assignedTo) {
                Text("未割り当て")
                    .tag(nil as String?)
                
                ForEach(members, id: \.userId) { member in
                    Text(memberDisplayName(member))
                        .tag(member.userId as String?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if let assignedId = assignedTo {
                let assignedMember = members.first { $0.userId == assignedId }
                let display = assignedMember.map { memberDisplayName($0) } ?? userNames[assignedId]
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("担当: \(display ?? "読み込み中...")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("担当者選択")
        .accessibilityHint("タスクの担当者を選択できます")
        .onAppear {
            Task {
                if let assignedId = assignedTo { await ensureNameFor(userId: assignedId) }
                await loadUserNames()
            }
        }
        .onChange(of: members) { _, _ in
            Task {
                await loadUserNames()
            }
        }
        .onChange(of: assignedTo) { _, newValue in
            Task { if let uid = newValue { await ensureNameFor(userId: uid) } }
        }
    }
    
    private func memberDisplayName(_ member: ProjectMember) -> String {
        // まずdisplayNameを確認
        if let displayName = member.displayName, !displayName.isEmpty {
            return displayName
        }
        
        // 次にキャッシュされたユーザー名を確認
        if let userName = userNames[member.userId], !userName.isEmpty {
            return userName
        }
        
        // fallbackとしてuserIdを返す
        return member.userId
    }
    
    @MainActor
    private func loadUserNames() async {
        // displayNameがないメンバーのuserIdを収集
        let userIdsToLoad = members.compactMap { member in
            if member.displayName == nil || member.displayName!.isEmpty {
                return member.userId
            }
            return nil
        }
        
        guard !userIdsToLoad.isEmpty else { return }
        
        // Firestoreからユーザー情報を取得
        for userId in userIdsToLoad {
            do {
                let userDoc = try await Firestore.firestore().collection("users").document(userId).getDocument()
                if let data = userDoc.data(),
                   let name = data["name"] as? String, !name.isEmpty {
                    userNames[userId] = name
                }
            } catch {
                // エラーが発生しても継続（サイレントに失敗）
                print("⚠️ AssigneeSectionView: Failed to load user name for \(userId): \(error)")
            }
        }
    }

    private func ensureNameFor(userId: String) async {
        if userNames[userId] != nil { return }
        do {
            let doc = try await Firestore.firestore().collection("users").document(userId).getDocument()
            if let data = doc.data(), let name = data["name"] as? String, !name.isEmpty {
                await MainActor.run { userNames[userId] = name }
            }
        } catch {
            // ignore
        }
    }
}

#Preview {
    @Previewable @State var selectedAssignee: String? = nil

    let sampleMembers = [
        ProjectMember(userId: "user1", projectId: "project1", role: .owner, displayName: "田中太郎"),
        ProjectMember(userId: "user2", projectId: "project1", role: .editor, displayName: "佐藤花子"),
        ProjectMember(userId: "user3", projectId: "project1", role: .viewer)
    ]

    VStack {
        AssigneeSectionView(
            members: sampleMembers,
            assignedTo: $selectedAssignee
        )
        .environmentObject(SharedManagerStore.shared)
        .padding()

        Divider()

        Text("Selected: \(selectedAssignee ?? "None")")
            .font(.caption)
            .padding()
    }
}
