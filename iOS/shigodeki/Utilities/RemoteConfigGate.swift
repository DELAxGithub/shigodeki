//
//  RemoteConfigGate.swift
//  shigodeki
//
//  Remote-config bridge used for feature kill switches. Loads defaults from
//  Firebase Remote Config while allowing local overrides via UserDefaults.
//

import Foundation
#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif

final class RemoteConfigGate {
    static let shared = RemoteConfigGate()
    private init() {}

    private let userDefaults = UserDefaults.standard
    #if canImport(FirebaseRemoteConfig)
    private var remoteConfig: RemoteConfig?
    #else
    private var remoteConfig: Any?
    #endif
    private var didStart = false

    private let flagDefaults: [String: Bool] = [
        "dashboardRefreshEnabled": false,
        "taskAddModal": false,
        "kpiDashboardsEnabled": false,
        "projectCardsSummaryEnabled": false,
        "unifiedPreviewEnabled": false,
        "previewTemplateEnabled": false,
        "previewAIEnabled": false,
        "previewPhotoEnabled": false,
        "undoEnabled": false,
        "offlineBadgesEnabled": false,
        "taskOrderIndexEnabled": false,
        "purchasesEnabled": false,
        "proSubscriptionEnabled": false,
        "templateIAPEnabled": false,
        "paywallEnabled": false,
        "debugAllowExternalAPIKey": false
    ]

    private lazy var remoteDefaults: [String: NSObject] = {
        flagDefaults.reduce(into: [String: NSObject]()) { result, entry in
            result[entry.key] = NSNumber(value: entry.value)
        }
    }()

    func start(minimumFetchInterval: TimeInterval = 3600) {
        guard didStart == false else { return }

        #if canImport(FirebaseRemoteConfig)
        let config = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = minimumFetchInterval
        #endif
        config.configSettings = settings
        config.setDefaults(remoteDefaults)

        remoteConfig = config
        didStart = true

        Task { await fetchAndActivate() }
        logResolvedFlags(source: "startup")
        #else
        didStart = true
        logResolvedFlags(source: "startup-no-remoteConfig")
        #endif
    }

    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if let override = userDefaults.object(forKey: key) as? Bool {
            return override
        }

        #if canImport(FirebaseRemoteConfig)
        if let config = remoteConfig as? RemoteConfig {
            let value = config.configValue(forKey: key)
            if value.source != .static {
                return value.boolValue
            }
        }
        #endif

        if let defaultFlagValue = flagDefaults[key] {
            return defaultFlagValue
        }

        return defaultValue
    }

    func logResolvedFlags(source: String = "manual") {
        #if DEBUG
        let header = "[Flags] Resolved (source: \(source))"
        let entries = flagDefaults.keys.sorted().map { key -> String in
            let resolved = bool(forKey: key, default: flagDefaults[key] ?? false)
            return "  \(key)=\(resolved)"
        }
        print(([header] + entries).joined(separator: "\n"))
        #endif
    }

    #if canImport(FirebaseRemoteConfig)
    private func fetchAndActivate() async {
        guard let config = remoteConfig else { return }

        await withCheckedContinuation { continuation in
            config.fetchAndActivate { status, error in
                #if DEBUG
                if let error {
                    print("[Flags] Remote Config fetch failed: \(error.localizedDescription)")
                } else {
                    print("[Flags] Remote Config fetch status: \(status.rawValue)")
                }
                #endif
                self.logResolvedFlags(source: "fetch")
                continuation.resume()
            }
        }
    }
    #else
    private func fetchAndActivate() async {}
    #endif
}
