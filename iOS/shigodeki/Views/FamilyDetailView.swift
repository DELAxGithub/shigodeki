//
//  FamilyDetailView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//  Refactored to follow CLAUDE.md principles: Composition over large files
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
    @State private var showingLeaveConfirmation = false
    @State private var showingCreateProject = false
    
    // Live family document listener
    @State private var liveFamily: Family?
    @State private var familyListener: ListenerRegistration?

    // Composed operations
    @StateObject private var memberOperations = FamilyMemberOperations(
        familyManager: FamilyManager(),
        authManager: AuthenticationManager.shared
    )
    @StateObject private var projectOperations = FamilyProjectOperations(
        projectManager: ProjectManager(),
        familyManager: FamilyManager()
    )
    
    private var isCurrentUserCreator: Bool {
        guard let userId = authManager?.currentUser?.id else { return false }
        return family.members.first == userId
    }
    
    var body: some View {
        // Prefer live family snapshot when available
        let currentFamily = liveFamily ?? family
        List {
            // Family Info Section
            FamilyInfoSection(family: currentFamily)
            
            // Members Section
            FamilyMembersSection(
                family: currentFamily,
                memberOperations: memberOperations,
                isCurrentUserCreator: isCurrentUserCreator,
                onRemoveMember: removeMember
            )
            
            // Projects Section
            FamilyProjectsSection(
                family: currentFamily,
                projectOperations: projectOperations,
                showingCreateProject: $showingCreateProject
            )
            
            // Actions Section
            FamilyActionsSection(
                family: currentFamily,
                isCurrentUserCreator: isCurrentUserCreator,
                showingInviteCode: $showingInviteCode,
                showingLeaveConfirmation: $showingLeaveConfirmation,
                onLoadInviteCode: {
                    projectOperations.loadInviteCode(family: currentFamily)
                }
            )
        }
        .navigationTitle(currentFamily.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            setupManagers()
            startFamilyListener()
            memberOperations.loadFamilyMembers(family: currentFamily)
            projectOperations.loadFamilyProjects(family: currentFamily)
        }
        .onChange(of: liveFamily?.members ?? []) { _ in
            // Members changed -> reload member list and projects
            if let lf = liveFamily {
                memberOperations.loadFamilyMembers(family: lf)
                projectOperations.loadFamilyProjects(family: lf)
            }
        }
        .onDisappear {
            familyListener?.remove(); familyListener = nil
        }
        .sheet(isPresented: $showingInviteCode) {
            InviteCodeView(inviteCode: projectOperations.currentInviteCode, familyName: family.name)
        }
        .sheet(isPresented: $showingCreateProject) {
            CreateProjectView(projectManager: projectManager ?? ProjectManager(), defaultOwnerType: .family, defaultFamilyId: family.id)
        }
        .alert("家族グループから退出", isPresented: $showingLeaveConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("退出", role: .destructive) {
                leaveFamily()
            }
        } message: {
            Text("本当に「\(family.name)」から退出しますか？この操作は取り消せません。")
        }
    }
    
    private func setupManagers() {
        authManager = AuthenticationManager.shared
        familyManager = FamilyManager()
        projectManager = ProjectManager()
        
        // Update operations with actual managers
        memberOperations.updateManagers(
            familyManager: familyManager!,
            authManager: authManager!
        )
        projectOperations.updateManagers(
            projectManager: projectManager!,
            familyManager: familyManager!
        )
    }

    private func startFamilyListener() {
        guard let id = family.id else { return }
        let ref = Firestore.firestore().collection("families").document(id)
        familyListener?.remove()
        familyListener = ref.addSnapshotListener { snapshot, error in
            guard let data = snapshot?.data() else { return }
            var f = Family(
                name: data["name"] as? String ?? "",
                members: data["members"] as? [String] ?? []
            )
            f.id = snapshot?.documentID
            f.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
            f.lastUpdatedAt = (data["lastUpdatedAt"] as? Timestamp)?.dateValue()
            f.devEnvironmentTest = data["devEnvironmentTest"] as? String
            liveFamily = f
        }
    }
    
    private func removeMember(_ member: User) {
        Task {
            do {
                try await memberOperations.removeMember(member, from: family)
            } catch {
                print("❌ Error removing member: \(error)")
            }
        }
    }
    
    private func leaveFamily() {
        Task {
            do {
                guard let currentUserId = authManager?.currentUser?.id else { return }
                try await projectOperations.leaveFamily(family, currentUserId: currentUserId)
                // Issue #49 Fix: Navigate back after successful family leave
                dismiss()
            } catch {
                print("❌ Error leaving family: \(error)")
            }
        }
    }
}

// MARK: - Family Info Section Component
struct FamilyInfoSection: View {
    let family: Family
    
    var body: some View {
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
    }
}

// MARK: - Family Members Section Component  
struct FamilyMembersSection: View {
    let family: Family
    @ObservedObject var memberOperations: FamilyMemberOperations
    let isCurrentUserCreator: Bool
    let onRemoveMember: (User) -> Void
    
    var body: some View {
        Section("メンバー (家族: \(family.members.count)人, 読み込み済み: \(memberOperations.familyMembers.count)人)") {
            if memberOperations.isLoadingMembers {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("メンバー情報を読み込み中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if !memberOperations.familyMembers.isEmpty {
                ForEach(Array(memberOperations.familyMembers.enumerated()), id: \.element.id) { index, member in
                    if member.name.contains("エラー") || member.name.contains("Load Error") {
                        // Error member with retry functionality
                        ErrorMemberRow(
                            member: member,
                            isRetrying: memberOperations.retryingMembers.contains(member.id ?? ""),
                            onRetry: {
                                memberOperations.retryMemberLoad(memberId: member.id ?? "")
                            }
                        )
                    } else {
                        // Normal member
                        NavigationLink(destination: MemberDetailView(member: member)) {
                            MemberRowView(
                                member: member,
                                isCreator: member.id == family.members.first,
                                canRemove: isCurrentUserCreator && member.id != family.members.first,
                                onRemove: { onRemoveMember(member) }
                            )
                        }
                    }
                }
            } else {
                Text("メンバー情報を読み込み中...")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - Error Member Row Component
struct ErrorMemberRow: View {
    let member: User
    let isRetrying: Bool
    let onRetry: () -> Void
    
    var body: some View {
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
            
            if isRetrying {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onRetry()
        }
    }
}

// MARK: - Family Projects Section Component
struct FamilyProjectsSection: View {
    let family: Family
    @ObservedObject var projectOperations: FamilyProjectOperations
    @Binding var showingCreateProject: Bool
    
    var body: some View {
        if !projectOperations.familyProjects.isEmpty {
            Section("プロジェクト") {
                ForEach(projectOperations.familyProjects) { project in
                    NavigationLink(destination: ProjectDetailView(project: project, projectManager: ProjectManager())) {
                        ProjectRowView(project: project)
                    }
                }
                
                Button(action: { showingCreateProject = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("新しいプロジェクトを作成")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

// MARK: - Family Actions Section Component
struct FamilyActionsSection: View {
    let family: Family
    let isCurrentUserCreator: Bool
    @Binding var showingInviteCode: Bool
    @Binding var showingLeaveConfirmation: Bool
    let onLoadInviteCode: () -> Void
    
    var body: some View {
        Section("アクション") {
            if isCurrentUserCreator {
                Button(action: {
                    onLoadInviteCode()
                    showingInviteCode = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.blue)
                        Text("メンバーを招待")
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Button(action: { showingLeaveConfirmation = true }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                    Text("家族グループから退出")
                        .foregroundColor(.red)
                }
            }
        }
    }
}
