//
//  OfflineManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore

class OfflineManager {
    static let shared = OfflineManager()
    private let db = Firestore.firestore()
    
    private init() {
        configureOfflineSettings()
    }
    
    private func configureOfflineSettings() {
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings()
        // Note: Offline persistence is enabled by default in the new Firebase SDK
        db.settings = settings
    }
    
    func enableOfflineMode() {
        try? db.enableNetwork { error in
            if let error = error {
                print("Failed to enable offline mode: \(error)")
            }
        }
    }
    
    func disableOfflineMode() {
        try? db.disableNetwork { error in
            if let error = error {
                print("Failed to disable offline mode: \(error)")
            }
        }
    }
}