//
//  OfflineManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore
import os.log

class OfflineManager {
    static let shared = OfflineManager()
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "com.hiroshikodera.shigodeki", category: "OfflineManager")
    
    @Published var isOfflineMode: Bool = false
    
    private init() {
        configureOfflineSettings()
    }
    
    private func configureOfflineSettings() {
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings()
        // Note: Offline persistence is enabled by default in the new Firebase SDK
        db.settings = settings
    }
    
    func enableOfflineMode() async {
        do {
            try await db.enableNetwork()
            await MainActor.run {
                self.isOfflineMode = false
            }
            logger.info("✅ Network enabled successfully")
        } catch {
            logger.error("❌ Failed to enable network: \(error.localizedDescription, privacy: .public)")
            // Still update state to reflect attempt
            await MainActor.run {
                self.isOfflineMode = true
            }
        }
    }
    
    func disableOfflineMode() async {
        do {
            try await db.disableNetwork()
            await MainActor.run {
                self.isOfflineMode = true
            }
            logger.info("📴 Offline mode enabled successfully")
        } catch {
            logger.error("❌ Failed to enable offline mode: \(error.localizedDescription, privacy: .public)")
            // Keep previous state if operation failed
        }
    }
}