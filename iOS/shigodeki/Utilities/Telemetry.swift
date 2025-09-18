//
//  Telemetry.swift
//  shigodeki
//
//  Minimal telemetry facade.
//

import Foundation

enum TelemetryEvent: String {
    case onTaskAddOptionChosen
    case onPreviewShown
    case onPreviewAccepted
    case onTaskAdded
    case onUndo
    case onSyncQueued
    case onSyncSucceeded
    case onSyncFailed
    case onSyncRetryTapped
    case onAIGenerationAttempt
    case onAIGenerationParsed
    case onAIGenerationFallback
    case onProPaywallShown
    case onProPriceRetry
    case onProPurchaseResult
}

struct TelemetryPayload: Encodable {
    let screen: String?
    let option: String?
    let depth: Int?
    let previewSource: String?
    let aiProvider: String?
    let aiParse: String?
    let fellBack: Bool?
    let jsonMode: Bool?
    let reason: String?
    let context: String?

    init(
        screen: String? = nil,
        option: String? = nil,
        depth: Int? = nil,
        previewSource: String? = nil,
        aiProvider: String? = nil,
        aiParse: String? = nil,
        fellBack: Bool? = nil,
        jsonMode: Bool? = nil,
        reason: String? = nil,
        context: String? = nil
    ) {
        self.screen = screen
        self.option = option
        self.depth = depth
        self.previewSource = previewSource
        self.aiProvider = aiProvider
        self.aiParse = aiParse
        self.fellBack = fellBack
        self.jsonMode = jsonMode
        self.reason = reason
        self.context = context
    }
}

enum Telemetry {
    static func fire(_ event: TelemetryEvent, _ payload: TelemetryPayload = TelemetryPayload()) {
        #if DEBUG
        print("📈 \(event.rawValue) payload=\(payload)")
        #endif
    }
}

extension TelemetryPayload: CustomStringConvertible {
    var description: String {
        var parts: [String] = []
        if let screen { parts.append("screen=\(screen)") }
        if let option { parts.append("option=\(option)") }
        if let depth { parts.append("depth=\(depth)") }
        if let previewSource { parts.append("previewSource=\(previewSource)") }
        if let aiProvider { parts.append("aiProvider=\(aiProvider)") }
        if let aiParse { parts.append("aiParse=\(aiParse)") }
        if let fellBack { parts.append("fellBack=\(fellBack)") }
        if let jsonMode { parts.append("jsonMode=\(jsonMode)") }
        if let reason { parts.append("reason=\(reason)") }
        if let context { parts.append("context=\(context)") }
        return "{" + parts.joined(separator: ", ") + "}"
    }
}
