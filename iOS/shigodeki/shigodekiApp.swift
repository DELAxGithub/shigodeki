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
import StoreKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        print("🧩 App Build: \(BuildInfo.current.buildString)")

        // Log Firebase project at runtime to verify correct config in all builds
        print("🔧 Firebase Project: \(FirebaseApp.app()?.options.projectID ?? "unknown")")

        FeatureFlagOverrides.applyLaunchArguments()
        RemoteConfigGate.shared.start()
        
        #if DEBUG
        print("🔧 Firebase: Using production backend for dev environment")
        // Note: Firestore connection test moved to AuthenticationManager (requires auth)
        #endif
        
        return true
    }
}

@main
struct shigodekiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    let persistenceController = PersistenceController.shared
    @StateObject private var purchaseEnvironment = PurchaseEnvironmentHolder()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.entitlementStore, purchaseEnvironment.entitlementStore)
                .environment(\.templatePurchaseCoordinator, purchaseEnvironment.templateCoordinator)
                .environment(\.purchaseProductCatalog, purchaseEnvironment.productCatalog)
                .environment(\.proSubscriptionCoordinator, purchaseEnvironment.proCoordinator)
                .task {
                    purchaseEnvironment.start()
                }
        }
    }
}

private final class PurchaseEnvironmentHolder: ObservableObject {
    @MainActor private var cachedStoreKitService: StoreKitPurchaseService?
    @MainActor private var cachedEntitlementStore: EntitlementStore?
    @MainActor private var cachedTemplateCoordinator: TemplatePurchaseCoordinating?
    @MainActor private var cachedProductCatalog: PurchaseProductCataloging?
    @MainActor private var cachedProCoordinator: ProSubscriptionCoordinating?

    @MainActor
    private var storeKitService: StoreKitPurchaseService? {
        guard #available(iOS 15.0, *) else { return nil }
        if cachedStoreKitService == nil {
            cachedStoreKitService = StoreKitPurchaseService()
        }
        return cachedStoreKitService
    }

    @MainActor
    var entitlementStore: EntitlementStore? {
        guard FeatureFlags.purchasesEnabled else { return nil }
        guard #available(iOS 15.0, *) else { return nil }
        if cachedEntitlementStore == nil, let service = storeKitService {
            cachedEntitlementStore = EntitlementStore(purchaseService: service)
        }
        return cachedEntitlementStore
    }

    @MainActor
    var templateCoordinator: TemplatePurchaseCoordinating? {
        guard #available(iOS 15.0, *) else { return nil }
        if cachedTemplateCoordinator == nil, let service = storeKitService {
            let refresher: EntitlementRefreshing = entitlementStore ?? NoopEntitlementRefresher()
            cachedTemplateCoordinator = TemplatePurchaseCoordinator(purchaseService: service, entitlementRefresher: refresher)
        }
        return cachedTemplateCoordinator
    }

    @MainActor
    var productCatalog: PurchaseProductCataloging? {
        guard #available(iOS 15.0, *) else { return nil }
        if cachedProductCatalog == nil, let service = storeKitService {
            cachedProductCatalog = PurchaseProductCatalog(purchaseService: service)
        }
        return cachedProductCatalog
    }

    @MainActor
    var proCoordinator: ProSubscriptionCoordinating? {
        guard FeatureFlags.proSubscriptionEnabled, FeatureFlags.purchasesEnabled else { return nil }
        guard #available(iOS 15.0, *) else { return nil }
        if cachedProCoordinator == nil, let service = storeKitService {
            let refresher: EntitlementRefreshing = entitlementStore ?? NoopEntitlementRefresher()
            cachedProCoordinator = ProSubscriptionCoordinator(purchaseService: service, entitlementRefresher: refresher)
        }
        return cachedProCoordinator
    }

    @MainActor
    func start() {
        guard FeatureFlags.purchasesEnabled else { return }
        guard #available(iOS 15.0, *), let store = entitlementStore else { return }
        store.start()
    }
}

@MainActor
private struct NoopEntitlementRefresher: EntitlementRefreshing {
    func refresh() async {}
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
