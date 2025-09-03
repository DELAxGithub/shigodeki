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
    @EnvironmentObject var sharedManagers: SharedManagerStore
    // Issue #49 Fix: Add dismiss environment for screen navigation after family leave
    @Environment(\.dismiss) private var dismiss
    @State private var authManager: AuthenticationManager?
    @State private var familyManager: FamilyManager?
    @State private var projectManager: ProjectManager?
    @State private var showingInviteCode = false
    @State private var currentInviteCode: String = ""
    @State private var showingLeaveConfirmation = false
    @State private var familyMembers: [User] = []
    @State private var isLoadingMembers = false
    @State private var familyProjects: [Project] = []
    @State private var showingCreateProject = false
    // Issue #44: Add retry mechanism for failed member loads
    @State private var retryingMembers: Set<String> = []
    
    private var isCurrentUserCreator: Bool {
        guard let userId = authManager?.currentUser?.id else { return false }
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
                        HStack {
                            // Issue #44: Check if this is an error member and show retry option
                            if member.name.contains("エラー") || member.name.contains("Load Error") {
                                // Error member with retry functionality
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.title3)
                                        .foregroundColor(.red)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(member.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("タップして再試行")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        
                                        if !member.email.isEmpty && !member.email.contains("エラー") {
                                            Text(member.email)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if retryingMembers.contains(member.id ?? "") {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    retryMemberLoad(memberId: member.id ?? "")
                                }
                            } else {
                                // Normal member - show navigation link
                                NavigationLink(destination: MemberDetailView(member: member).environmentObject(sharedManagers)) {
                                    HStack {
                                        Image(systemName: member.id == family.members.first ? "crown.fill" : "person.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(member.id == family.members.first ? .orange : .blue)
                                            .frame(width: 30)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(member.name)
                                                    .font(.headline)
                                                
                                                if member.id == family.members.first {
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
                                                // Issue #48 Fix: Show appropriate date label based on member role
                                                let dateLabel = member.id == family.members.first ? "作成日" : "参加日"
                                                Text("\(dateLabel): \(DateFormatter.shortDate.string(from: createdAt))")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // 削除ボタン（作成者のみ表示、エラーメンバー以外）
                            if isCurrentUserCreator && member.id != authManager?.currentUser?.id && !member.name.contains("エラー") && !member.name.contains("Load Error") {
                                Button(action: { removeMember(member) }) {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else if !family.members.isEmpty {
                    // Fallback: メンバーのユーザープロファイルが未作成/未取得でもIDで占位表示
                    ForEach(Array(family.members.enumerated()), id: \.offset) { index, userId in
                        HStack {
                            Image(systemName: userId == family.members.first ? "crown.fill" : "person.circle")
                                .foregroundColor(userId == family.members.first ? .orange : .blue)
                            VStack(alignment: .leading) {
                                Text("ユーザーID: \(String(userId.prefix(8)))...")
                                    .font(.subheadline)
                                Text("ユーザープロファイル読み込み中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // データが読み込めない場合の再試行ボタン
                    Button("メンバー情報を再読み込み") {
                        loadFamilyMembers()
                    }
                    .foregroundColor(.blue)
                    .padding(.top, 8)
                }
            }
            
            // Projects Section
            if !familyProjects.isEmpty, let pm = projectManager {
                Section("プロジェクト") {
                    ForEach(familyProjects) { proj in
                        NavigationLink(destination: ProjectDetailView(project: proj, projectManager: pm)) {
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
        .loadingOverlay(isLoadingMembers || (familyManager?.isLoading ?? false), message: "読み込み中...")
        .navigationTitle("家族詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("プロジェクト作成") {
                    showingCreateProject = true
                }
                .disabled(projectManager == nil)
            }
        }
            .task {
                if authManager == nil { authManager = await sharedManagers.getAuthManager() }
                if familyManager == nil { 
                    familyManager = await sharedManagers.getFamilyManager()
                    // FamilyManager の家族リストが空の場合はロードを実行
                    if let fm = familyManager, await fm.families.isEmpty, let userId = authManager?.currentUser?.id {
                        await fm.loadFamiliesForUser(userId: userId)
                    }
                }
                if projectManager == nil { projectManager = await sharedManagers.getProjectManager() }
                loadFamilyMembers()
                loadFamilyProjects()
            }
            .onChange(of: projectManager?.projects) { _ in
                // ProjectManager のプロジェクト一覧が変更された時に家族プロジェクトを更新
                loadFamilyProjects()
            }
        .sheet(isPresented: $showingInviteCode) {
            InviteCodeView(inviteCode: currentInviteCode, familyName: family.name)
        }
        .sheet(isPresented: $showingCreateProject) {
            if let pm = projectManager {
                CreateProjectView(projectManager: pm, defaultOwnerType: .family, defaultFamilyId: family.id)
            }
        }
        .onChange(of: showingCreateProject) { isShowing in
            // プロジェクト作成画面が閉じられた時にプロジェクト一覧を再読み込み
            if !isShowing {
                loadFamilyProjects()
            }
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
        Task {
            await loadMembersInternal(memberIds: family.members)
        }
    }
    
    // Issue #44: Extracted member loading logic for reuse in retry functionality
    private func loadMembersInternal(memberIds: [String]) async {
        do {
            let db = Firestore.firestore()
            let decoder = Firestore.Decoder()
            
            print("🔍 [Issue #44] Loading \(memberIds.count) family members")
            
            // 順序を保証するため、順次処理でユーザー情報を取得
            var loadedMembers: [User] = []
            
            for memberId in memberIds {
                print("🔍 [Issue #44] Loading member: \(memberId)")
                do {
                    let userDoc = try await db.collection("users").document(memberId).getDocument()
                    
                    if userDoc.exists {
                        do {
                            // 最新のUserモデルでデコードを試行
                            var user = try userDoc.data(as: User.self, decoder: decoder)
                            user.id = memberId
                            loadedMembers.append(user)
                            print("✅ [Issue #44] Successfully loaded user: \(user.name)")
                        } catch {
                            // デコードに失敗した場合、手動でフィールドを取得してフォールバック
                            print("⚠️ [Issue #44] Decode failed for user \(memberId), using manual parsing: \(error)")
                            if let data = userDoc.data() {
                                var user = User(
                                    name: data["name"] as? String ?? "Unknown User",
                                    email: data["email"] as? String ?? "",
                                    projectIds: data["projectIds"] as? [String] ?? [],
                                    roleAssignments: [:] // 複雑なRoleデータは初期化時は空にする
                                )
                                user.id = memberId
                                user.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                                user.lastActiveAt = (data["lastActiveAt"] as? Timestamp)?.dateValue()
                                loadedMembers.append(user)
                                print("✅ [Issue #44] Successfully parsed user manually: \(user.name)")
                            }
                        }
                    } else {
                        // ユーザードキュメントが存在しない場合のフォールバック
                        var placeholderUser = User(
                            name: "ユーザーが見つかりません",
                            email: "ユーザーID: \(String(memberId.prefix(8)))",
                            projectIds: [],
                            roleAssignments: [:]
                        )
                        placeholderUser.id = memberId
                        loadedMembers.append(placeholderUser)
                        print("⚠️ [Issue #44] User document not found for ID: \(memberId)")
                    }
                } catch {
                    print("❌ [Issue #44] Error loading user \(memberId): \(error)")
                    
                    // Issue #44 Fix: Create user-friendly error messages based on error type
                    let errorName: String
                    let errorDescription = error.localizedDescription.lowercased()
                    
                    if errorDescription.contains("network") || errorDescription.contains("connection") {
                        errorName = "接続エラー"
                    } else if errorDescription.contains("permission") || errorDescription.contains("denied") {
                        errorName = "アクセス権限がありません"
                    } else if errorDescription.contains("timeout") {
                        errorName = "読み込みタイムアウト"
                    } else {
                        errorName = "エラーにより読み込めませんでした"
                    }
                    
                    var errorUser = User(
                        name: errorName,
                        email: "ユーザーID: \(String(memberId.prefix(8)))",
                        projectIds: [],
                        roleAssignments: [:]
                    )
                    errorUser.id = memberId
                    loadedMembers.append(errorUser)
                }
            }
            
            await MainActor.run {
                familyMembers = loadedMembers
                isLoadingMembers = false
                print("✅ [Issue #44] Successfully loaded \(loadedMembers.count) members")
                
                // Log summary of member loading results
                let successCount = loadedMembers.filter { !$0.name.contains("エラー") && !$0.name.contains("見つかりません") }.count
                let errorCount = loadedMembers.count - successCount
                print("📊 [Issue #44] Loading summary: \(successCount) success, \(errorCount) errors")
            }
            
        } catch {
            await MainActor.run { 
                isLoadingMembers = false 
                print("❌ [Issue #44] Critical error in loadFamilyMembers: \(error)")
            }
        }
    }
    
    // Issue #44: Retry mechanism for individual failed member loads
    private func retryMemberLoad(memberId: String) {
        print("🔄 [Issue #44] Retrying member load for: \(memberId)")
        retryingMembers.insert(memberId)
        
        Task {
            await loadSingleMember(memberId: memberId)
            await MainActor.run {
                retryingMembers.remove(memberId)
            }
        }
    }
    
    // Issue #44: Load a single member and update the family members array
    private func loadSingleMember(memberId: String) async {
        do {
            let db = Firestore.firestore()
            let decoder = Firestore.Decoder()
            
            print("🔄 [Issue #44] Retrying single member: \(memberId)")
            
            let userDoc = try await db.collection("users").document(memberId).getDocument()
            
            var newUser: User
            
            if userDoc.exists {
                do {
                    // 最新のUserモデルでデコードを試行
                    var user = try userDoc.data(as: User.self, decoder: decoder)
                    user.id = memberId
                    newUser = user
                    print("✅ [Issue #44] Retry successful for user: \(user.name)")
                } catch {
                    // デコードに失敗した場合、手動でフィールドを取得してフォールバック
                    print("⚠️ [Issue #44] Retry: Decode failed, using manual parsing: \(error)")
                    if let data = userDoc.data() {
                        var user = User(
                            name: data["name"] as? String ?? "Unknown User",
                            email: data["email"] as? String ?? "",
                            projectIds: data["projectIds"] as? [String] ?? [],
                            roleAssignments: [:]
                        )
                        user.id = memberId
                        user.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                        user.lastActiveAt = (data["lastActiveAt"] as? Timestamp)?.dateValue()
                        newUser = user
                        print("✅ [Issue #44] Retry successful with manual parsing: \(user.name)")
                    } else {
                        // Still failed, create error user
                        newUser = User(
                            name: "エラーにより読み込めませんでした",
                            email: "ユーザーID: \(String(memberId.prefix(8)))",
                            projectIds: [],
                            roleAssignments: [:]
                        )
                        newUser.id = memberId
                        print("❌ [Issue #44] Retry failed: manual parsing also failed")
                    }
                }
            } else {
                // ユーザードキュメントが存在しない場合
                newUser = User(
                    name: "ユーザーが見つかりません",
                    email: "ユーザーID: \(String(memberId.prefix(8)))",
                    projectIds: [],
                    roleAssignments: [:]
                )
                newUser.id = memberId
                print("⚠️ [Issue #44] Retry: User document still not found: \(memberId)")
            }
            
            // Update the specific member in the family members array
            await MainActor.run {
                if let index = familyMembers.firstIndex(where: { $0.id == memberId }) {
                    familyMembers[index] = newUser
                    print("✅ [Issue #44] Updated member at index \(index): \(newUser.name)")
                }
            }
            
        } catch {
            print("❌ [Issue #44] Retry failed for \(memberId): \(error)")
            
            // Create error user for failed retry
            let errorName: String
            let errorDescription = error.localizedDescription.lowercased()
            
            if errorDescription.contains("network") || errorDescription.contains("connection") {
                errorName = "接続エラー (再試行失敗)"
            } else if errorDescription.contains("permission") || errorDescription.contains("denied") {
                errorName = "アクセス権限がありません"
            } else {
                errorName = "エラーにより読み込めませんでした"
            }
            
            let errorUser = User(
                name: errorName,
                email: "ユーザーID: \(String(memberId.prefix(8)))",
                projectIds: [],
                roleAssignments: [:]
            )
            
            await MainActor.run {
                if let index = familyMembers.firstIndex(where: { $0.id == memberId }) {
                    var updatedUser = errorUser
                    updatedUser.id = memberId
                    familyMembers[index] = updatedUser
                }
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
                    try await familyManager?.generateInvitationCode(familyId: familyId, familyName: family.name)
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
                try await familyManager?.removeMemberFromFamily(familyId: familyId, userId: memberId)
                await MainActor.run {
                    loadFamilyMembers()
                }
            } catch {
                print("Error removing member: \(error)")
            }
        }
    }
    
    private func leaveFamily() {
        guard let familyId = family.id, let userId = authManager?.currentUser?.id else { return }
        
        Task.detached {
            do {
                // FamilyManager が家族リストを持っていない場合は先にロード
                if let fm = familyManager, await fm.families.isEmpty {
                    print("🔄 Loading families before exit attempt")
                    await fm.loadFamiliesForUser(userId: userId)
                }
                
                // 楽観的更新を使用して即座にUIから退出させる
                try await familyManager?.leaveFamilyOptimistic(familyId: familyId, userId: userId)
                
                await MainActor.run {
                    // 退出成功時は画面を閉じる（管理者・一般メンバー共通）
                    print("✅ Family exit successful - dismissing screen")
                    // Issue #49 Fix: Automatically dismiss FamilyDetailView after successful leave
                    dismiss()
                }
            } catch {
                print("Error leaving family: \(error)")
                // エラー時はUIをロールバック（既にleaveFamilyOptimisticでハンドリング）
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
                    // Issue #48 Fix: Show appropriate date label based on member role
                    let dateLabel = isCreator ? "作成日" : "参加日"
                    Text("\(dateLabel): \(DateFormatter.shortDate.string(from: createdAt))")
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
