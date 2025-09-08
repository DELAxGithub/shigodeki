//
//  FamilyProjectOperations.swift
//  shigodeki
//
//  Extracted from FamilyDetailView.swift for better code organization
//  Handles family project loading and invite code management
//

import SwiftUI
import FirebaseFirestore

@MainActor 
class FamilyProjectOperations: ObservableObject {
    private let projectManager: ProjectManager
    private let familyManager: FamilyManager
    
    @Published var familyProjects: [Project] = []
    @Published var currentInviteCode: String = ""
    private var listener: ListenerRegistration?
    
    init(projectManager: ProjectManager, familyManager: FamilyManager) {
        self.projectManager = projectManager
        self.familyManager = familyManager
    }
    
    func updateManagers(projectManager: ProjectManager, familyManager: FamilyManager) {
        // Note: In a production app, you'd want to implement proper manager updating
        // For now, this is a placeholder to satisfy the interface
    }
    
    func loadFamilyProjects(family: Family) {
        // Realtime: listen projects owned by this family (ownerType == family)
        listener?.remove(); listener = nil
        guard let familyId = family.id, !familyId.isEmpty else {
            familyProjects = []; return
        }
        let db = Firestore.firestore()
        let query = db.collection("projects")
            .whereField("ownerId", isEqualTo: familyId)
            .whereField("ownerType", isEqualTo: ProjectOwnerType.family.rawValue)
        listener = query.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self = self else { return }
                if let error = error {
                    print("❌ Error loading family projects: \(error)")
                    self.familyProjects = []
                    return
                }
                let projects: [Project] = snapshot?.documents.compactMap { doc in
                    var p = try? doc.data(as: Project.self, decoder: Firestore.Decoder())
                    p?.id = doc.documentID
                    return p
                } ?? []
                self.familyProjects = projects
            }
        }
    }
    
    func loadInviteCode(family: Family) {
        Task {
            guard let familyId = family.id else {
                print("❌ [FamilyProjectOperations] No family ID available")
                return
            }
            
            do {
                let db = Firestore.firestore()
                
                // families/{id}.latestInviteCode から読み込み
                let familyDoc = try await db.collection("families").document(familyId).getDocument()
                
                if let latestCode = familyDoc.data()?["latestInviteCode"] as? String {
                    let displayCode = "\(InviteCodeSpec.displayPrefix)\(latestCode)"
                    currentInviteCode = displayCode
                    print("✅ [FamilyProjectOperations] Loaded invite code: \(displayCode)")
                    return
                }
                
                // latestInviteCode が無ければその場で作成
                print("ℹ️ [FamilyProjectOperations] No latestInviteCode found, creating new invitation")
                let unifiedService = UnifiedInvitationService()
                let code = try await unifiedService.createInvitation(targetId: familyId, type: .family)
                let normalizedCode = try InvitationCodeNormalizer.normalize(code)
                
                // families/{id}.latestInviteCode に保存
                try await db.collection("families").document(familyId).updateData([
                    "latestInviteCode": normalizedCode
                ])
                
                let displayCode = "\(InviteCodeSpec.displayPrefix)\(normalizedCode)"
                currentInviteCode = displayCode
                print("✅ [FamilyProjectOperations] Created and saved new invite code: \(displayCode)")
                
            } catch {
                print("❌ [FamilyProjectOperations] Error loading invite code: \(error)")
                currentInviteCode = "読み込み失敗"
            }
        }
    }
    
    func leaveFamily(_ family: Family, currentUserId: String) async throws {
        try await familyManager.leaveFamily(familyId: family.id ?? "", userId: currentUserId)
    }
}
