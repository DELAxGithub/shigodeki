//
//  UserDataService.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

struct UserDataService {
    private let db = Firestore.firestore()
    
    // MARK: - User Data Management
    
    func loadUserData(uid: String) async -> User? {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            if document.exists, let data = document.data() {
                // Check if migration is needed and perform it
                await migrateUserDataIfNeeded(uid: uid, data: data)
                
                // Manual parsing from Firestore data with new User structure
                var user = User(
                    name: data["name"] as? String ?? "",
                    email: data["email"] as? String ?? "",
                    projectIds: data["projectIds"] as? [String] ?? [],
                    roleAssignments: data["roleAssignments"] as? [String: Role] ?? [:]
                )
                user.id = uid
                user.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                print("👤 User data loaded: \(user.name), projectIds: \(user.projectIds.count)")
                return user
            } else {
                print("⚠️ No user document found for UID: \(uid)")
                return nil
            }
        } catch {
            print("Error loading user data: \(error)")
            return nil
        }
    }
    
    func saveUserToFirestore(uid: String, name: String, email: String) async -> User? {
        var user = User(name: name, email: email, projectIds: [], roleAssignments: [:])
        user.id = uid
        user.createdAt = Date()
        
        let userData: [String: Any] = [
            "name": name,
            "email": email,
            "projectIds": user.projectIds,
            "roleAssignments": user.roleAssignments,
            "familyIds": user.familyIds ?? [],
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("users").document(uid).setData(userData)
            print("✅ User saved to Firestore successfully with new structure")
            print("👤 User details: name=\(name), email=\(email), uid=\(uid)")
            return user
        } catch {
            print("❌ Error saving user to Firestore: \(error)")
            return nil
        }
    }
    
    func updateUserName(uid: String, newName: String) async -> Bool {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return false
        }
        
        do {
            try await db.collection("users").document(uid).updateData([
                "name": trimmedName
            ])
            print("✅ User name updated successfully to: \(trimmedName)")
            return true
        } catch {
            print("❌ Failed to update user name: \(error)")
            return false
        }
    }
    
    // MARK: - User Data Migration
    
    private func migrateUserDataIfNeeded(uid: String, data: [String: Any]) async {
        // Check if migration is needed (missing projectIds or roleAssignments)
        let hasProjectIds = data["projectIds"] != nil
        let hasRoleAssignments = data["roleAssignments"] != nil
        
        if !hasProjectIds || !hasRoleAssignments {
            print("🔄 Migrating user data to new structure for UID: \(uid)")
            
            let migratedData: [String: Any] = [
                "name": data["name"] as? String ?? "",
                "email": data["email"] as? String ?? "",
                "projectIds": data["projectIds"] as? [String] ?? [],
                "roleAssignments": data["roleAssignments"] as? [String: Any] ?? [:],
                "familyIds": data["familyIds"] as? [String] ?? [],
                "createdAt": data["createdAt"] ?? FieldValue.serverTimestamp()
            ]
            
            do {
                try await db.collection("users").document(uid).setData(migratedData, merge: true)
                print("✅ User data migrated successfully")
            } catch {
                print("❌ User data migration failed: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func createMissingUserDocument(authUser: FirebaseAuth.User) async -> User? {
        let name = authUser.displayName ?? "Unknown User"
        let email = authUser.email ?? ""
        print("🔄 Creating missing user document for: \(name)")
        return await saveUserToFirestore(uid: authUser.uid, name: name, email: email)
    }
}