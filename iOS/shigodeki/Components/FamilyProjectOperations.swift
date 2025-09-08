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
    
    init(projectManager: ProjectManager, familyManager: FamilyManager) {
        self.projectManager = projectManager
        self.familyManager = familyManager
    }
    
    func updateManagers(projectManager: ProjectManager, familyManager: FamilyManager) {
        // Note: In a production app, you'd want to implement proper manager updating
        // For now, this is a placeholder to satisfy the interface
    }
    
    func loadFamilyProjects(family: Family) {
        Task {
            do {
                // Get projects for the family members
                var allProjects: [Project] = []
                for memberId in family.members {
                    let memberProjects = try await projectManager.getUserProjects(userId: memberId)
                    allProjects.append(contentsOf: memberProjects)
                }
                
                // Remove duplicates and filter for family projects
                familyProjects = Array(Set(allProjects))
            } catch {
                print("❌ Error loading family projects: \(error)")
                familyProjects = []
            }
        }
    }
    
    func loadInviteCode(family: Family) {
        Task {
            // Fetch the actual invite code from Firestore
            guard let familyId = family.id else {
                print("❌ [FamilyProjectOperations] No family ID available")
                return
            }
            
            do {
                let db = Firestore.firestore()
                
                // Try to find existing invitation codes using family-scoped approach
                // 1. Try family-scoped invites collection (most reliable for family members)
                let familyScopedQuery = db.collection("families").document(familyId)
                    .collection("invites")
                    .limit(to: 1)
                
                let familyScopedDocs = try await familyScopedQuery.getDocuments()
                
                if let doc = familyScopedDocs.documents.first,
                   let normalizedCode = doc.data()["normalizedCode"] as? String {
                    let displayCode = "\(InviteCodeSpec.displayPrefix)\(normalizedCode)"
                    currentInviteCode = displayCode
                    print("✅ [FamilyProjectOperations] Loaded invite code from family scope: \(displayCode)")
                    return
                }
                
                // 2. Fallback: Legacy invitations collection (still uses queries for backward compatibility)
                let legacyQuery = db.collection("invitations")
                    .whereField("familyId", isEqualTo: familyId)
                    .whereField("isActive", isEqualTo: true)
                    .limit(to: 1)
                
                let legacyDocs = try await legacyQuery.getDocuments()
                
                if let doc = legacyDocs.documents.first {
                    let rawCode = doc.documentID
                    let normalizedCode = try InvitationCodeNormalizer.normalize(rawCode)
                    let displayCode = "\(InviteCodeSpec.displayPrefix)\(normalizedCode)"
                    
                    currentInviteCode = displayCode
                    print("✅ [FamilyProjectOperations] Loaded invite code from legacy: \(displayCode) (normalized: \(normalizedCode))")
                    return
                }
                
                // 3. If no invitation found, this shouldn't happen in normal flow
                print("⚠️ [FamilyProjectOperations] No active invitation found for family \(familyId)")
                currentInviteCode = "コード未発行"
                
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