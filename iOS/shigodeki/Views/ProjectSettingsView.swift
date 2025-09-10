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
    
    // Issue #64 Fix: User display name resolution
    @State private var ownerDisplayName: String = ""

    // Live project + members listener
    @State private var liveProject: Project?
    @State private var projectListener: ListenerRegistration?
    @State private var membersListener: ListenerRegistration?
    @State private var liveMemberCount: Int = 0
    
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
                    ProjectInvitationSection(
                        selectedInviteRole: $selectedInviteRole,
                        isUpdating: $isUpdating,
                        onCreateInvite: {
                            Task { await createInvite() }
                        }
                    )
                    
                    ProjectOwnerSection(
                        selectedOwnerType: $selectedOwnerType,
                        selectedFamilyId: $selectedFamilyId,
                        isUpdating: $isUpdating,
                        familyManager: familyManager,
                        onChangeOwner: changeOwner
                    )
                    
                    ProjectBasicSection(
                        projectName: $projectName,
                        projectDescription: $projectDescription,
                        isCompleted: $isCompleted,
                        isUpdating: $isUpdating,
                        showingDeleteConfirmation: $showingDeleteConfirmation,
                        onFieldChange: updateHasChanges
                    )
                    
                    ProjectInfoSection(
                        project: liveProject ?? project,
                        ownerDisplayName: ownerDisplayName,
                        memberCount: liveMemberCount > 0 ? liveMemberCount : project.memberIds.count,
                        createdAtOverride: liveProject?.createdAt
                    )
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
                            .ignoresSafeArea()
                        
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
                // Issue #64 Fix: Load owner display name
                await loadOwnerDisplayName()
                updateHasChanges() // Issue #65 Fix: Initialize hasChanges state
                startProjectListeners()
            }
            .onDisappear {
                projectListener?.remove(); projectListener = nil
                membersListener?.remove(); membersListener = nil
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
            .dismissKeyboardOnTap()
            .keyboardToolbarDone()
        }
        .sheet(isPresented: $showingInviteSheet) {
            ProjectInvitationSheet(
                project: project,
                inviteCode: createdInviteCode
            )
        }
        .presentationDragIndicator(.visible)
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
    
    
    
    // Issue #64 Fix: Load owner display name from Firestore
    private func loadOwnerDisplayName() async {
        do {
            let db = Firestore.firestore()
            if project.ownerType == .family {
                // Family-owned project: show family name
                let famDoc = try await db.collection("families").document(project.ownerId).getDocument()
                let famName = famDoc.data()? ["name"] as? String ?? "家族情報が見つかりません"
                await MainActor.run { ownerDisplayName = famName }
            } else {
                // Individual-owned project: show user name/email
                let userDoc = try await db.collection("users").document(project.ownerId).getDocument()
                if userDoc.exists, let data = userDoc.data() {
                    let displayName = data["displayName"] as? String ?? data["name"] as? String ?? data["email"] as? String ?? "ユーザー名不明"
                    await MainActor.run { ownerDisplayName = displayName }
                } else {
                    await MainActor.run { ownerDisplayName = "ユーザー情報が見つかりません" }
                }
            }
        } catch {
            print("Error loading owner display name: \(error)")
            await MainActor.run {
                ownerDisplayName = "ユーザー情報の取得に失敗"
            }
        }
    }

    private func startProjectListeners() {
        guard let id = project.id else { return }
        liveMemberCount = project.memberIds.count
        // Project document listener
        let docRef = Firestore.firestore().collection("projects").document(id)
        projectListener?.remove()
        projectListener = docRef.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                guard snapshot?.data() != nil else { return }
                var proj = try? snapshot?.data(as: Project.self, decoder: Firestore.Decoder())
                proj?.id = snapshot?.documentID
                self.liveProject = proj
            }
        }
        // Members subcollection count listener
        membersListener?.remove()
        membersListener = docRef.collection("members").addSnapshotListener { snapshot, error in
            Task { @MainActor in
                self.liveMemberCount = snapshot?.documents.count ?? self.liveMemberCount
            }
        }
    }
}

#Preview {
    let sampleProject = Project(name: "Sample Project", description: "A sample project for preview", ownerId: "user1")
    ProjectSettingsView(project: sampleProject, projectManager: ProjectManager())
}
