//
//  ProjectSettingsView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI
import FirebaseFirestore

struct ProjectSettingsView: View {
    let project: Project
    @ObservedObject var projectManager: ProjectManager
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @State private var authManager: AuthenticationManager?
    @State private var familyManager: FamilyManager?
    
    @State private var projectName: String
    @State private var projectDescription: String
    @State private var isCompleted: Bool
    @State private var isUpdating = false
    @State private var showingDeleteConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var hasChanges = false
    
    // Invitations
    @StateObject private var invitationManager = ProjectInvitationManager()
    @State private var selectedInviteRole: Role = .editor
    @State private var showingInviteSheet = false
    @State private var createdInviteCode: String = ""
    
    // Owner change UI
    @State private var selectedOwnerType: ProjectOwnerType
    @State private var selectedFamilyId: String?
    
    // Creator display name
    @State private var creatorDisplayName: String = ""
    
    init(project: Project, projectManager: ProjectManager) {
        self.project = project
        self.projectManager = projectManager
        self._projectName = State(initialValue: project.name)
        self._projectDescription = State(initialValue: project.description ?? "")
        self._isCompleted = State(initialValue: project.isCompleted)
        self._selectedOwnerType = State(initialValue: project.ownerType)
        self._selectedFamilyId = State(initialValue: project.ownerType == .family ? project.ownerId : nil)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "gear")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("プロジェクト設定")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(project.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                
                Form {
                    // Invitation Section
                    Section(header: Text("招待")) {
                        Picker("権限", selection: $selectedInviteRole) {
                            ForEach(Role.allCases, id: \.self) { role in
                                Text(role.displayName).tag(role)
                            }
                        }
                        Button {
                            Task { await createInvite() }
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("招待コードを作成")
                            }
                        }
                        .disabled(isUpdating)
                    }
                    // Owner Section
                    Section(header: Text("所有者")) {
                        Picker("所有者タイプ", selection: $selectedOwnerType) {
                            Text(ProjectOwnerType.individual.displayName).tag(ProjectOwnerType.individual)
                            Text(ProjectOwnerType.family.displayName).tag(ProjectOwnerType.family)
                        }
                        .pickerStyle(.segmented)
                        
                        if selectedOwnerType == .family {
                            if (familyManager?.families.isEmpty ?? true) {
                                Text("家族グループがありません。家族タブから作成/参加してください。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Picker("家族グループ", selection: Binding(get: { selectedFamilyId ?? "" }, set: { selectedFamilyId = $0.isEmpty ? nil : $0 })) {
                                    Text("選択してください").tag("")
                                    ForEach(familyManager?.families ?? []) { fam in
                                        Text(fam.name).tag(fam.id ?? "")
                                    }
                                }
                            }
                        }
                        
                        Button {
                            changeOwner()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("所有者を変更")
                            }
                        }
                        .disabled(isUpdating || (selectedOwnerType == .family && (selectedFamilyId ?? "").isEmpty))
                    }
                    Section(header: Text("基本情報")) {
                        TextField("プロジェクト名", text: $projectName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(false)
                            .onChange(of: projectName) { _, _ in updateHasChanges() }
                        
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
                                .onChange(of: projectDescription) { _, _ in updateHasChanges() }
                        }
                    }
                    
                    Section(header: Text("ステータス")) {
                        Toggle("完了済み", isOn: $isCompleted)
                            .onChange(of: isCompleted) { _, _ in updateHasChanges() }
                        
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
                    
                    Section(header: Text("プロジェクト情報")) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("作成者")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(creatorDisplayName)
                                    .font(.subheadline)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("メンバー数")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(project.memberIds.count)人")
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
                                Text(formatDate(project.createdAt))
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
                                    Text(formatDate(lastModified))
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                    
                    // Danger Zone
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
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(isUpdating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        updateProject()
                    }
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUpdating || !hasChanges)
                }
            }
            .overlay(
                Group {
                    if isUpdating {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("更新中...")
                                .font(.headline)
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    }
                }
            )
            .task {
                if authManager == nil { authManager = await sharedManagers.getAuthManager() }
                if familyManager == nil { familyManager = await sharedManagers.getFamilyManager() }
                if let uid = authManager?.currentUser?.id {
                    await familyManager?.loadFamiliesForUser(userId: uid)
                }
                await loadCreatorDisplayName()
                updateHasChanges() // Initialize hasChanges state
            }
            .confirmationDialog(
                "プロジェクトを削除",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    deleteProject()
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("このプロジェクトとすべてのデータが完全に削除されます。この操作は取り消せません。")
            }
            .alert("エラー", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingInviteSheet) {
            VStack(spacing: 24) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                Text("招待コード")
                    .font(.title2).bold()
                Text(createdInviteCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .onTapGesture { UIPasteboard.general.string = createdInviteCode }
                Text("タップしてコピー").font(.caption).foregroundColor(.secondary)
                Button {
                    let act = UIActivityViewController(activityItems: ["プロジェクト『\(project.name)』への招待コード: \(createdInviteCode)"], applicationActivities: nil)
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
    
    private func changeOwner() {
        guard let projectId = project.id else { return }
        guard let actor = authManager?.currentUser?.id else { return }
        let newOwnerId: String = (selectedOwnerType == .individual) ? actor : (selectedFamilyId ?? "")
        guard !newOwnerId.isEmpty else { return }
        isUpdating = true
        Task {
            do {
                try await projectManager.changeOwner(projectId: projectId, to: selectedOwnerType, ownerId: newOwnerId, performedBy: actor)
                await MainActor.run { isUpdating = false }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func updateHasChanges() {
        let newHasChanges = projectName.trimmingCharacters(in: .whitespacesAndNewlines) != project.name ||
                           projectDescription.trimmingCharacters(in: .whitespacesAndNewlines) != (project.description ?? "") ||
                           isCompleted != project.isCompleted
        hasChanges = newHasChanges
    }
    
    private func updateProject() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "プロジェクト名を入力してください"
            showingError = true
            return
        }
        
        isUpdating = true
        
        Task {
            do {
                var updatedProject = project
                updatedProject.name = trimmedName
                
                let trimmedDescription = projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                updatedProject.description = trimmedDescription.isEmpty ? nil : trimmedDescription
                updatedProject.isCompleted = isCompleted
                updatedProject.lastModifiedAt = Date()
                
                if isCompleted && !project.isCompleted {
                    updatedProject.completedAt = Date()
                } else if !isCompleted && project.isCompleted {
                    updatedProject.completedAt = nil
                }
                
                _ = try await projectManager.updateProject(updatedProject)
                
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func deleteProject() {
        guard let projectId = project.id else {
            errorMessage = "プロジェクトIDが見つかりません"
            showingError = true
            return
        }
        
        isUpdating = true
        
        Task {
            do {
                try await projectManager.deleteProject(id: projectId)
                
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func createInvite() async {
        guard project.id != nil else { return }
        guard let uid = authManager?.currentUser?.id else { return }
        isUpdating = true
        do {
            let inv = try await invitationManager.createInvitation(for: project, role: selectedInviteRole, invitedByUserId: uid, invitedByName: authManager?.currentUser?.name ?? uid)
            await MainActor.run {
                createdInviteCode = inv.inviteCode
                showingInviteSheet = true
                isUpdating = false
            }
        } catch {
            await MainActor.run {
                isUpdating = false
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func loadCreatorDisplayName() async {
        do {
            // ユーザー情報をFirestoreから取得
            if let authMgr = authManager {
                // Firestoreからユーザー情報を取得 - project.createdByを使用
                let db = Firestore.firestore()
                let creatorId = project.ownerId
                let userDoc = try await db.collection("users").document(creatorId).getDocument()
                
                if userDoc.exists, let userData = userDoc.data() {
                    let displayName = userData["displayName"] as? String
                    let email = userData["email"] as? String
                    
                    await MainActor.run {
                        creatorDisplayName = displayName ?? email ?? "不明なユーザー"
                    }
                } else {
                    await MainActor.run {
                        creatorDisplayName = "不明なユーザー"
                    }
                }
            } else {
                await MainActor.run {
                    creatorDisplayName = "不明なユーザー"
                }
            }
        } catch {
            print("Error loading creator display name: \(error)")
            await MainActor.run {
                creatorDisplayName = "読み込みエラー"
            }
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "不明" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

#Preview {
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    ProjectSettingsView(project: sampleProject, projectManager: ProjectManager())
}
