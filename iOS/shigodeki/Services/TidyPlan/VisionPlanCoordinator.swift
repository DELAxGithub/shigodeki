import Foundation

protocol VisionPlanService {
    func generatePlan(from imageData: Data, locale: UserLocale, context: String?) async throws -> Plan
}

enum VisionPlanError: Error {
    case providerUnavailable
    case invalidResponse
}

struct VisionPlanCoordinator {
    private let keychain = KeychainManager.shared
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func generatePlan(from imageData: Data, locale: UserLocale, allowNetwork: Bool, context: String?) async -> Plan {
        guard allowNetwork else {
            Telemetry.fire(
                .onAIGenerationFallback,
                TelemetryPayload(fellBack: true, reason: "network_disabled")
            )
            return FallbackPlanner.generatePlan(locale: locale)
        }

        let providers = preferredProviders()
        guard providers.isEmpty == false else {
            Telemetry.fire(
                .onAIGenerationFallback,
                TelemetryPayload(fellBack: true, reason: "no_provider")
            )
            return FallbackPlanner.generatePlan(locale: locale)
        }

        var lastFailureReason: String = "unknown"

        for (provider, apiKey) in providers {
            Telemetry.fire(
                .onAIGenerationAttempt,
                TelemetryPayload(aiProvider: provider.rawValue, jsonMode: true)
            )
            guard let service = makeService(for: provider, apiKey: apiKey) else { continue }
            do {
                let plan = try await service.generatePlan(from: imageData, locale: locale, context: context)
                Telemetry.fire(
                    .onAIGenerationParsed,
                    TelemetryPayload(aiProvider: provider.rawValue, aiParse: "ok", fellBack: false)
                )
                return plan.validated()
            } catch let normalizeError as PlanNormalizationError {
                print("[VisionPlanCoordinator] Provider \(provider.displayName) normalization failed: \(normalizeError)")
                let parseResult = telemetryLabel(for: normalizeError)
                Telemetry.fire(
                    .onAIGenerationParsed,
                    TelemetryPayload(aiProvider: provider.rawValue, aiParse: parseResult)
                )
                lastFailureReason = parseResult
                continue
            } catch let clientError as AIClientError {
                let reason = telemetryReason(for: clientError)
                print("[VisionPlanCoordinator] Provider \(provider.displayName) client error: \(clientError)")
                Telemetry.fire(
                    .onAIGenerationParsed,
                    TelemetryPayload(aiProvider: provider.rawValue, aiParse: "json_error", reason: reason)
                )
                lastFailureReason = reason
                continue
            } catch {
                print("[VisionPlanCoordinator] Provider \(provider.displayName) failed: \(error)")
                let reason = "error_\(provider.rawValue)"
                Telemetry.fire(
                    .onAIGenerationParsed,
                    TelemetryPayload(aiProvider: provider.rawValue, aiParse: "json_error", reason: reason)
                )
                lastFailureReason = reason
                continue
            }
        }

        Telemetry.fire(
            .onAIGenerationFallback,
            TelemetryPayload(fellBack: true, reason: lastFailureReason)
        )
        return FallbackPlanner.generatePlan(locale: locale)
    }

    private func preferredProviders() -> [(KeychainManager.APIProvider, String)] {
        var ordered: [(KeychainManager.APIProvider, String)] = []
        var seen = Set<KeychainManager.APIProvider>()

        if let preferred = keychain.getDefaultProvider(),
           let key = keychain.getAPIKeyIfAvailable(for: preferred),
           !key.isEmpty {
            ordered.append((preferred, key))
            seen.insert(preferred)
        }

        for provider in KeychainManager.APIProvider.allCases where !seen.contains(provider) {
            if let key = keychain.getAPIKeyIfAvailable(for: provider), !key.isEmpty {
                ordered.append((provider, key))
            }
        }

        return ordered
    }

    private func makeService(for provider: KeychainManager.APIProvider, apiKey: String) -> VisionPlanService? {
        switch provider {
        case .openAI:
            return OpenAIVisionPlanService(apiKey: apiKey)
        case .claude:
            return ClaudeVisionPlanService(apiKey: apiKey, session: session)
        case .gemini:
            return GeminiVisionPlanService(apiKey: apiKey, session: session)
        }
    }
}

private func telemetryLabel(for error: PlanNormalizationError) -> String {
    switch error {
    case .missingProject:
        return "missing_project"
    case .invalidJSON, .missingTasks:
        return "json_error"
    }
}

private func telemetryReason(for error: AIClientError) -> String {
    switch error {
    case .apiKeyNotConfigured:
        return "api_key_missing"
    case .rateLimitExceeded:
        return "rate_limited"
    case .quotaExceeded:
        return "quota_exceeded"
    case .serviceUnavailable:
        return "service_unavailable"
    case .invalidResponse:
        return "invalid_response"
    case .invalidJSON:
        return "invalid_json"
    case .networkError:
        return "network_error"
    }
}

struct VisionPlanContextBuilder {
    static func build(
        project: Project?,
        phase: Phase?,
        taskList: TaskList?,
        existingTasks: [ShigodekiTask] = [],
        additionalNotes: [String] = []
    ) -> String {
        var sections: [String] = []

        if let project {
            var projectLines = ["【プロジェクト】\(project.name)"]
            if let description = project.description, description.isEmpty == false {
                projectLines.append("説明: \(description)")
            }
            sections.append(projectLines.joined(separator: "\n"))
        }

        if let phase {
            var phaseLines = ["【フェーズ】\(phase.name)"]
            if let description = phase.description, description.isEmpty == false {
                phaseLines.append("目的: \(description)")
            }
            sections.append(phaseLines.joined(separator: "\n"))
        }

        if let taskList {
            sections.append("【タスクリスト】\(taskList.name)")
        }

        let trimmedTasks = existingTasks
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .prefix(6)

        if trimmedTasks.isEmpty == false {
            let bulletList = trimmedTasks
                .map { "・\($0.title)" }
                .joined(separator: "\n")
            sections.append("【既存タスク】\n\(bulletList)")
        }

        if additionalNotes.isEmpty == false {
            let usableNotes = additionalNotes.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            if usableNotes.isEmpty == false {
                sections.append(usableNotes.joined(separator: "\n"))
            }
        }

        return sections.joined(separator: "\n\n")
    }
}

private struct VisionPromptBuilder {
    static func build(locale: UserLocale, context: String?) -> String {
        let ctx = (context?.isEmpty == false) ? "\n【コンテクスト】\n\(context!)\n" : ""
        return """
        あなたは提供された写真とコンテクストをもとに、プロジェクトやフェーズの目的に沿った実行可能なタスクを日本語で提案するアシスタントです。写真の内容を観察しつつ、プロジェクト情報・フェーズ情報・既存タスクを最優先に考慮してください。片付けが目的でない場合は、学習や作業などコンテクストに合わせたタスクを生成します。\n\nYou MUST output a single JSON object matching this exact schema. No explanations, no code fences, no additional text.\n\n{
          "project": { "title": string, "locale": { "lang": string, "region": string } },
          "tasks": [
            {
              "title": string,
              "due": string|null,
              "priority": "low"|"normal"|"high"|null,
              "rationale": string|null
            }
          ]
        }\n\n制約:\n- project は必須。写真およびコンテクストに合う title を設定。\n- locale.lang と locale.region が無い場合は ja / JP を推奨。\n- tasks は 1〜8 件。title は空欄不可。\n- due は "YYYY-MM-DD" 形式の日付か null。\n- priority は low / normal / high のいずれか、迷う場合は null。\n- rationale はタスクの背景・目的を 200 文字以内で記述。\n- JSON 以外は絶対に出力しない。\n- 200 件を超えるタスクは生成しない。\n\n【タスク生成ガイド】\n- プロジェクト・フェーズ・タスクリストの目的と既存タスクを最優先。\n- 5〜25分程度で完了できる粒度に分割。\n- 写真から得られるヒントは補助的に用い、文脈と矛盾しないように調整。\n\(ctx)\n写真とコンテクストを解析し、このスキーマに完全準拠した JSON だけを出力してください。
        """
    }
}

private final class OpenAIVisionPlanService: VisionPlanService {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func generatePlan(from imageData: Data, locale: UserLocale, context: String?) async throws -> Plan {
        let service = OpenAIService(apiKey: apiKey)
        return try await service.generatePlan(from: imageData, locale: locale, context: context)
    }
}

private final class ClaudeVisionPlanService: VisionPlanService {
    private let apiKey: String
    private let session: URLSession
    private let model = "claude-3-haiku-20240307"

    init(apiKey: String, session: URLSession) {
        self.apiKey = apiKey
        self.session = session
    }

    func generatePlan(from imageData: Data, locale: UserLocale, context: String?) async throws -> Plan {
        let prompt = VisionPromptBuilder.build(locale: locale, context: context)
        let base64 = imageData.base64EncodedString()

        let body = ClaudeVisionRequest(
            model: model,
            maxTokens: 2000,
            messages: [
                ClaudeVisionRequestMessage(role: "user", content: [
                    .text(prompt),
                    .image(mediaType: "image/jpeg", data: base64)
                ])
            ],
            responseFormat: ClaudeResponseFormat(type: "json")
        )

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw VisionPlanError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            break
        case 401:
            throw AIClientError.apiKeyNotConfigured
        case 429:
            throw AIClientError.rateLimitExceeded
        case 402:
            throw AIClientError.quotaExceeded
        case 503:
            throw AIClientError.serviceUnavailable
        default:
            throw VisionPlanError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(ClaudeVisionResponse.self, from: data)
        guard let content = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw PlanNormalizationError.invalidJSON
        }

        return try PlanNormalization.normalizePlan(from: content, defaultLocale: locale)
    }
}

private final class GeminiVisionPlanService: VisionPlanService {
    private let apiKey: String
    private let session: URLSession
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"

    init(apiKey: String, session: URLSession) {
        self.apiKey = apiKey
        self.session = session
    }

    func generatePlan(from imageData: Data, locale: UserLocale, context: String?) async throws -> Plan {
        let prompt = VisionPromptBuilder.build(locale: locale, context: context)
        let base64 = imageData.base64EncodedString()

        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(parts: [
                    GeminiPart(text: prompt, inlineData: nil),
                    GeminiPart(text: nil, inlineData: GeminiInlineData(mimeType: "image/jpeg", data: base64))
                ])
            ],
            generationConfig: GeminiGenerationConfig(temperature: 0.3, maxOutputTokens: 2048, responseMimeType: "application/json")
        )

        var components = URLComponents(string: baseURL)
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else {
            throw VisionPlanError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw VisionPlanError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            break
        case 401:
            throw AIClientError.apiKeyNotConfigured
        case 429:
            throw AIClientError.rateLimitExceeded
        case 402:
            throw AIClientError.quotaExceeded
        case 503:
            throw AIClientError.serviceUnavailable
        default:
            throw VisionPlanError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let raw = decoded.candidates.first?.content.parts.compactMap({ $0.text }).joined(separator: "\n") else {
            throw PlanNormalizationError.invalidJSON
        }

        return try PlanNormalization.normalizePlan(from: raw, defaultLocale: locale)
    }
}

// MARK: - Claude Models

private struct ClaudeVisionRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeVisionRequestMessage]
    let responseFormat: ClaudeResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case responseFormat = "response_format"
    }
}

private struct ClaudeVisionRequestMessage: Codable {
    enum Content: Codable {
        case text(String)
        case image(mediaType: String, data: String)

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case source
        }

        enum SourceKeys: String, CodingKey {
            case type
            case mediaType = "media_type"
            case data
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let value):
                try container.encode("text", forKey: .type)
                try container.encode(value, forKey: .text)
            case .image(let mediaType, let data):
                try container.encode("image", forKey: .type)
                var source = container.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
                try source.encode("base64", forKey: .type)
                try source.encode(mediaType, forKey: .mediaType)
                try source.encode(data, forKey: .data)
            }
        }

        init(from decoder: Decoder) throws {
            fatalError("ClaudeVisionRequestMessage.Content should not be decoded")
        }
    }

    let role: String
    let content: [Content]
}

private struct ClaudeVisionResponse: Codable {
    let content: [ClaudeVisionResponseContent]
}

private struct ClaudeVisionResponseContent: Codable {
    let type: String
    let text: String?
}

private struct ClaudeResponseFormat: Codable {
    let type: String
}

// MARK: - Gemini Models

private struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String?
    let inlineData: GeminiInlineData?

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

private struct GeminiInlineData: Codable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

private struct GeminiGenerationConfig: Codable {
    let temperature: Double
    let maxOutputTokens: Int
    let responseMimeType: String?
    
    enum CodingKeys: String, CodingKey {
        case temperature
        case maxOutputTokens = "max_output_tokens"
        case responseMimeType = "response_mime_type"
    }
}

private struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Codable {
    let content: GeminiContent
}
