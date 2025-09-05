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
    
    func goOnline() async {
        do {
            try await db.enableNetwork()
            await MainActor.run {
                self.isOfflineMode = false
            }
            logger.info("✅ Network re-enabled successfully. App is ONLINE.")
        } catch {
            logger.error("❌ Failed to enable network: \(error.localizedDescription, privacy: .public)")
            // Still update state to reflect attempt
            await MainActor.run {
                self.isOfflineMode = false
            }
        }
    }
    
    func goOffline() async {
        do {
            try await db.disableNetwork()
            await MainActor.run {
                self.isOfflineMode = true
            }
            logger.info("📴 Network disabled successfully. App is OFFLINE.")
        } catch {
            logger.error("❌ Failed to disable network: \(error.localizedDescription, privacy: .public)")
            // Keep previous state if operation failed
        }
    }
}