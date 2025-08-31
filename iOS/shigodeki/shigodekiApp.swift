//
//  shigodekiApp.swift
//  shigodeki
//
//  Created by Hiroshi Kodera on 2025-08-27.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        print("🧩 App Build: \(BuildInfo.current.buildString)")
        
        // 🔧 Ensure we're using production Firebase (not emulator)
        #if DEBUG
        print("🔧 Firebase: Using production backend for dev environment")
        print("🔧 Firebase Project: \(FirebaseApp.app()?.options.projectID ?? "unknown")")
        
        // Verify Firestore connection
        let db = Firestore.firestore()
        print("🔧 Firestore: Backend configured for project")
        
        // Test connectivity with retry mechanism
        Task {
            await testFirestoreConnectionWithRetry(db: db)
        }
        #endif
        
        return true
    }
    
    // MARK: - Firebase Connection Testing
    private func testFirestoreConnectionWithRetry(db: Firestore, attempt: Int = 1, maxAttempts: Int = 3) async {
        do {
            let document = try await db.collection("test").document("connection").getDocument()
            print("✅ Firestore: Connection test successful on attempt \(attempt)")
        } catch {
            print("⚠️ Firestore: Connection test failed (attempt \(attempt)/\(maxAttempts)) - \(error.localizedDescription)")
            
            if attempt < maxAttempts {
                let delay = TimeInterval(pow(2.0, Double(attempt))) // Exponential backoff
                print("🔄 Firestore: Retrying connection in \(delay) seconds...")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await testFirestoreConnectionWithRetry(db: db, attempt: attempt + 1, maxAttempts: maxAttempts)
            } else {
                print("❌ Firestore: All connection attempts failed, enabling offline mode")
                await enableOfflineModeGracefully(db: db)
            }
        }
    }
    
    private func enableOfflineModeGracefully(db: Firestore) async {
        do {
            try await db.disableNetwork()
            print("📴 Firestore: Offline mode enabled after connection failures")
        } catch {
            print("⚠️ Firestore: Failed to enable offline mode - \(error.localizedDescription)")
        }
    }
}

@main
struct shigodekiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

// MARK: - Build Info
private struct BuildInfo {
    let buildString: String
    static let current: BuildInfo = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
        let ts = formatter.string(from: Date())
        return BuildInfo(buildString: ts)
    }()
}
