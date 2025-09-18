//
//  FeatureFlags.swift
//  shigodeki
//
//  Centralized feature toggle helpers. Values default to conservative (off) unless
//  overridden by UserDefaults or RemoteConfigGate.
//

import Foundation

enum FeatureFlags {
    private static func resolvedBool(for key: String, default fallback: Bool) -> Bool {
        return RemoteConfigGate.shared.bool(forKey: key, default: fallback)
    }

    // Phase 4 KPI dashboards
    static var kpiDashboardsEnabled: Bool {
        resolvedBool(for: "kpiDashboardsEnabled", default: false)
    }

    // Unified Preview pipeline (TaskDraft -> Preview -> Save)
    static var unifiedPreviewEnabled: Bool {
        resolvedBool(for: "unifiedPreviewEnabled", default: false)
    }

    static var previewTemplateEnabled: Bool {
        resolvedBool(for: "previewTemplateEnabled", default: false)
    }

    static var previewAIEnabled: Bool {
        resolvedBool(for: "previewAIEnabled", default: false)
    }

    static var previewPhotoEnabled: Bool {
        resolvedBool(for: "previewPhotoEnabled", default: false)
    }

    // Monetization toggles
    static var purchasesEnabled: Bool {
        resolvedBool(for: "purchasesEnabled", default: false)
    }

    static var proSubscriptionEnabled: Bool {
        resolvedBool(for: "proSubscriptionEnabled", default: false)
    }

    static var templateIAPEnabled: Bool {
        resolvedBool(for: "templateIAPEnabled", default: false)
    }

    static var paywallEnabled: Bool {
        resolvedBool(for: "paywallEnabled", default: false)
    }

    static var debugAllowExternalAPIKey: Bool {
        resolvedBool(for: "debugAllowExternalAPIKey", default: false)
    }
}
