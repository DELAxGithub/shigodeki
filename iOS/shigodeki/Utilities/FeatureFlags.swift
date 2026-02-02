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

    // Navigation refresh & entry points
    static var dashboardRefreshEnabled: Bool {
        resolvedBool(for: "dashboardRefreshEnabled", default: false)
    }

    static var taskAddModalEnabled: Bool {
        resolvedBool(for: "taskAddModal", default: true)
    }

    // Phase 4 KPI dashboards
    static var kpiDashboardsEnabled: Bool {
        resolvedBool(for: "kpiDashboardsEnabled", default: false)
    }

    static var projectCardsSummaryEnabled: Bool {
        resolvedBool(for: "projectCardsSummaryEnabled", default: false)
    }

    // Unified Preview pipeline (TaskDraft -> Preview -> Save)
    static var unifiedPreviewEnabled: Bool {
        resolvedBool(for: "unifiedPreviewEnabled", default: true)
    }

    static var previewTemplateEnabled: Bool {
        resolvedBool(for: "previewTemplateEnabled", default: true)
    }

    static var previewAIEnabled: Bool {
        resolvedBool(for: "previewAIEnabled", default: true)
    }

    static var previewPhotoEnabled: Bool {
        resolvedBool(for: "previewPhotoEnabled", default: true)
    }

    static var undoEnabled: Bool {
        resolvedBool(for: "undoEnabled", default: true)
    }

    static var offlineBadgesEnabled: Bool {
        resolvedBool(for: "offlineBadgesEnabled", default: true)
    }

    static var taskOrderIndexEnabled: Bool {
        resolvedBool(for: "taskOrderIndexEnabled", default: false)
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
