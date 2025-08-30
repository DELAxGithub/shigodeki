//
//  FamilyDetailView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI
import FirebaseFirestore

struct FamilyDetailView: View {
    let family: Family
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var familyManager = FamilyManager()
    @StateObject private var projectManager = ProjectManager()
    @State private var showingInviteCode = false
    @State private var currentInviteCode: String = ""
    @State private var showingLeaveConfirmation = false
    @State private var familyMembers: [User] = []
    @State private var isLoadingMembers = false
    @State private var familyProjects: [Project] = []
    @State private var showingCreateProject = false
    
    private var isCurrentUserCreator: Bool {
        guard let userId = authManager.currentUser?.id else { return false }
        return family.members.first == userId
    }
    
    var body: some View {
        List {
            // Family Info Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "house.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(family.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            if let createdAt = family.createdAt {
                                Text("作成日: \(DateFormatter.shortDate.string(from: createdAt))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Members Section
            Section("メンバー (\(family.members.count)人)") {
                if isLoadingMembers {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("メンバー情報を読み込み中...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } else if !familyMembers.isEmpty {
                    ForEach(Array(familyMembers.enumerated()), id: \.element.id) { index, member in
                        MemberRowView(
                            member: member,
                            isCreator: index == 0,
                            canRemove: isCurrentUserCreator && member.id != authManager.currentUser?.id
                        ) {
                            removeMember(member)
                        }
                    }
                } else if !family.members.isEmpty {
                    // Fallback: メンバーのユーザープロファイルが未作成/未取得でもIDで占位表示
                    ForEach(Array(family.members.enumerated()), id: \.offset) { index, userId in
                        HStack {
                            Image(systemName: index == 0 ? "crown.fill" : "person.circle")
                                .foregroundColor(index == 0 ? .orange : .blue)
                            VStack(alignment: .leading) {
                                Text("ユーザーID: \(userId)")
                                    .font(.subheadline)
                                Text("ユーザープロファイル未取得")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Projects Section
            if !familyProjects.isEmpty {
                Section("プロジェクト") {
                    ForEach(familyProjects) { proj in
                        NavigationLink(destination: ProjectDetailView(project: proj, projectManager: projectManager)) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                Text(proj.name)
                                Spacer()
                                OwnerBadge(ownerType: proj.ownerType)
                            }
                        }
                    }
                }
            }

            // Actions Section
            Section("アクション") {
                Button(action: { showingCreateProject = true }) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                            .foregroundColor(.blue)
                        Text("この家族のプロジェクトを作成")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Button(action: {
                    loadInviteCode()
                    showingInviteCode = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.blue)
                        Text("メンバーを招待")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: {
                    showingLeaveConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "arrow.right.square")
                            .foregroundColor(.red)
                        Text("家族グループから退出")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("家族詳細")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadFamilyMembers()
            loadFamilyProjects()
        }
        .sheet(isPresented: $showingInviteCode) {
            InviteCodeView(inviteCode: currentInviteCode, familyName: family.name)
        }
        .sheet(isPresented: $showingCreateProject) {
            CreateProjectView(projectManager: projectManager, defaultOwnerType: .family, defaultFamilyId: family.id)
        }
        .alert("グループから退出", isPresented: $showingLeaveConfirmation) {
            Button("退出", role: .destructive) {
                leaveFamily()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("本当に「\(family.name)」から退出しますか？")
        }
    }
    
    private func loadFamilyProjects() {
        guard let fid = family.id else { return }
        Task { @MainActor in
            do {
                let db = Firestore.firestore()
                let snapshot = try await db.collection("projects").whereField("ownerId", isEqualTo: fid).getDocuments()
                let decoder = Firestore.Decoder()
                let projects = try snapshot.documents.compactMap { doc in
                    try doc.data(as: Project.self, decoder: decoder)
                }.filter { $0.ownerType == .family }
                self.familyProjects = projects
            } catch {
                print("Error loading family projects: \(error)")
            }
        }
    }
    
    private func loadFamilyMembers() {
        guard family.id != nil else { return }
        
        isLoadingMembers = true
        
        Task.detached {
            do {
                let db = Firestore.firestore()
                var members: [User] = []
                
                for memberId in family.members {
                    let userDoc = try await db.collection("users").document(memberId).getDocument()
                    if let userData = userDoc.data() {
                        var user = User(
                            name: userData["name"] as? String ?? "Unknown",
                            email: userData["email"] as? String ?? "",
                            familyIds: userData["familyIds"] as? [String] ?? []
                        )
                        user.id = memberId
                        user.createdAt = (userData["createdAt"] as? Timestamp)?.dateValue()
                        members.append(user)
                    }
                }
                
                await MainActor.run {
                    familyMembers = members
                    isLoadingMembers = false
                }
                
            } catch {
                await MainActor.run {
                    isLoadingMembers = false
                }
                print("Error loading family members: \(error)")
            }
        }
    }
    
    private func loadInviteCode() {
        guard let familyId = family.id else { return }
        
        Task.detached {
            do {
                let db = Firestore.firestore()
                let inviteQuery = db.collection("invitations")
                    .whereField("familyId", isEqualTo: familyId)
                    .whereField("isActive", isEqualTo: true)
                    .limit(to: 1)
                
                let querySnapshot = try await inviteQuery.getDocuments()
                
                if let document = querySnapshot.documents.first,
                   let code = document.data()["code"] as? String {
                    await MainActor.run {
                        currentInviteCode = code
                    }
                } else {
                    // Generate new invite code if none exists
                    try await familyManager.generateInvitationCode(familyId: familyId, familyName: family.name)
                    // Reload to get the new code
                    await loadInviteCode()
                }
                
            } catch {
                print("Error loading invite code: \(error)")
            }
        }
    }
    
    private func removeMember(_ member: User) {
        guard let familyId = family.id, let memberId = member.id else { return }
        
        Task.detached {
            do {
                try await familyManager.removeMemberFromFamily(familyId: familyId, userId: memberId)
                await MainActor.run {
                    loadFamilyMembers()
                }
            } catch {
                print("Error removing member: \(error)")
            }
        }
    }
    
    private func leaveFamily() {
        guard let familyId = family.id, let userId = authManager.currentUser?.id else { return }
        
        Task.detached {
            do {
                try await familyManager.leaveFamily(familyId: familyId, userId: userId)
                // Navigate back
                await MainActor.run {
                    // The family list will automatically update due to listeners
                }
            } catch {
                print("Error leaving family: \(error)")
            }
        }
    }
}

struct MemberRowView: View {
    let member: User
    let isCreator: Bool
    let canRemove: Bool
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: isCreator ? "crown.fill" : "person.circle.fill")
                .font(.title3)
                .foregroundColor(isCreator ? .orange : .blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.name)
                        .font(.headline)
                    
                    if isCreator {
                        Text("作成者")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
                
                Text(member.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let createdAt = member.createdAt {
                    Text("参加日: \(DateFormatter.shortDate.string(from: createdAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct InviteCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let inviteCode: String
    let familyName: String
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("招待コード")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("このコードを共有して\n「\(familyName)」にメンバーを招待しましょう")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    Text(inviteCode)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .onTapGesture {
                            UIPasteboard.general.string = inviteCode
                        }
                    
                    Text("タップしてコピー")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        let activityVC = UIActivityViewController(
                            activityItems: ["家族グループ「\(familyName)」への招待コード: \(inviteCode)"],
                            applicationActivities: nil
                        )
                        
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first {
                            window.rootViewController?.present(activityVC, animated: true)
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("招待コードを共有")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text("招待コードの有効期限は7日間です")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("メンバーは「招待コードで参加」からこのコードを入力してグループに参加できます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("メンバーを招待")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FamilyDetailView(family: Family(name: "サンプル家族", members: ["user1", "user2"]))
}
