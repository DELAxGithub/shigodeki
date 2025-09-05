import Foundation
import FirebaseFirestore

class FamilyListenerService {
    private let db = Firestore.firestore()
    private var familyListeners: [ListenerRegistration] = []
    
    func startListeningToFamilies(userId: String, onFamiliesUpdated: @escaping ([Family]) -> Void, onError: @escaping (String) -> Void) {
        stopListeningToFamilies()
        
        Task { @MainActor in
            do {
                // Get user's family IDs
                let userDoc = try await db.collection("users").document(userId).getDocument()
                guard let userData = userDoc.data(),
                      let familyIds = userData["familyIds"] as? [String] else {
                    print("👤 FamilyManager: No family IDs found for user, setting empty families")
                    onFamiliesUpdated([])
                    return
                }
                
                print("📋 FamilyManager: Found \(familyIds.count) family IDs, loading initial data...")
                
                // FIRST: Load initial data immediately
                var initialFamilies: [Family] = []
                for familyId in familyIds {
                    do {
                        let familyDoc = try await db.collection("families").document(familyId).getDocument()
                        if let data = familyDoc.data() {
                            var family = Family(
                                name: data["name"] as? String ?? "",
                                members: data["members"] as? [String] ?? []
                            )
                            family.id = familyDoc.documentID
                            family.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                            family.lastUpdatedAt = (data["lastUpdatedAt"] as? Timestamp)?.dateValue()
                            family.devEnvironmentTest = data["devEnvironmentTest"] as? String
                            initialFamilies.append(family)
                            print("✅ FamilyManager: Loaded initial family: \(family.name)")
                        }
                    } catch {
                        print("❌ FamilyManager: Error loading initial family \(familyId): \(error)")
                    }
                }
                
                // Update families array with initial data
                onFamiliesUpdated(initialFamilies)
                print("🚀 FamilyManager: Initial load complete with \(initialFamilies.count) families")
                
                // THEN: Set up listeners for real-time updates
                for familyId in familyIds {
                    let listener = db.collection("families").document(familyId)
                        .addSnapshotListener { documentSnapshot, error in
                            Task { @MainActor in
                                if let error = error {
                                    print("Family listener error: \(error)")
                                    onError("家族データの同期中にエラーが発生しました")
                                    return
                                }
                                
                                guard let document = documentSnapshot,
                                      let data = document.data() else {
                                    return
                                }
                                
                                var family = Family(
                                    name: data["name"] as? String ?? "",
                                    members: data["members"] as? [String] ?? []
                                )
                                family.id = document.documentID
                                family.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                                family.lastUpdatedAt = (data["lastUpdatedAt"] as? Timestamp)?.dateValue()
                                family.devEnvironmentTest = data["devEnvironmentTest"] as? String
                                
                                // This would need to be handled in the main manager
                                // For now, just print the updated family
                                print("📱 Family updated: \(family.name)")
                            }
                        }
                    
                    familyListeners.append(listener)
                }
                
            } catch {
                print("Error setting up family listeners: \(error)")
                onError("家族データの監視設定に失敗しました")
            }
        }
    }
    
    func stopListeningToFamilies() {
        familyListeners.forEach { $0.remove() }
        familyListeners.removeAll()
    }
    
    func cleanupInactiveListeners() {
        // This would require more sophisticated tracking to identify which listener belongs to which family
        // For now, we'll keep all listeners active
        familyListeners.removeAll { _ in false }
    }
    
    deinit {
        stopListeningToFamilies()
    }
}