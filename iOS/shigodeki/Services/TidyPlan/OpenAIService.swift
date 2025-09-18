import Foundation

enum TidyPlanError: Error {
    case planningFailed
    case networkError(Int)
    case invalidJSON
}

final class OpenAIService {
    private let apiKey: String
    private let model = "gpt-4o"
    private let timeout: TimeInterval = 30.0
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func generatePlan(from imageData: Data, locale: UserLocale, context: String? = nil) async throws -> Plan {
        let base64Image = imageData.base64EncodedString()
        let request = try buildRequest(base64Image: base64Image, locale: locale, context: context)
        var lastError: Error?
        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            do {
                let data = try await performRequest(request)
                return try parsePlanResponse(data, locale: locale)
            } catch let TidyPlanError.networkError(code) {
                // Handle rate limiting with simple exponential backoff
                if code == 429 && attempt < maxAttempts {
                    let delayMs = Int(pow(2.0, Double(attempt - 1))) * 1500 // 1500ms, 3000ms
                    print("[OpenAIService] 429 rate limited. Retrying in \(delayMs)ms (attempt \(attempt)/\(maxAttempts))")
                    try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                    continue
                }
                lastError = TidyPlanError.networkError(code)
                break
            } catch {
                lastError = error
                break
            }
        }
        if let err = lastError { throw err }
        throw TidyPlanError.planningFailed
    }
    
    private func buildRequest(base64Image: String, locale: UserLocale, context: String?) throws -> URLRequest {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        
        let body = createRequestBody(base64Image: base64Image, locale: locale, context: context)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }
    
    private func createRequestBody(base64Image: String, locale: UserLocale, context: String?) -> [String: Any] {
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": createPrompt(for: locale, context: context)
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64Image)"
                        ]
                    ]
                ]
            ]
        ]
        
        return [
            "model": model,
            "messages": messages,
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "tidy_plan",
                    "schema": TidySchema.jsonSchema
                ]
            ],
            "max_tokens": 2000
        ]
    }
    
    private func performRequest(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw TidyPlanError.networkError(statusCode)
        }
        return data
    }
    
    private func parsePlanResponse(_ data: Data, locale: UserLocale) throws -> Plan {
        let openAIResponse = try JSONDecoder().decode(OpenAIPlanResponse.self, from: data)
        guard let message = openAIResponse.choices.first?.message else {
            throw TidyPlanError.invalidJSON
        }

        if let jsonPlan = message.content.first(where: { $0.type == "output_json" && $0.outputJSON != nil })?.outputJSON {
            return jsonPlan.validated()
        }

        if let text = message.content.first(where: { $0.text?.isEmpty == false })?.text {
            do {
                return try PlanNormalization.normalizePlan(from: text, defaultLocale: locale)
            } catch {
                throw TidyPlanError.invalidJSON
            }
        }

        throw TidyPlanError.invalidJSON
    }

    private func createPrompt(for locale: UserLocale, context: String?) -> String {
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
        }\n\n制約:\n- project は必須。写真およびコンテクストに合う title を設定。\n- locale.lang と locale.region が無い場合は ja / JP を推奨。\n- tasks は 1〜8 件。title が空のものは禁止。\n- due は "YYYY-MM-DD" 形式または null。\n- priority は low / normal / high のいずれか、判断できなければ null。\n- rationale は背景や根拠を 200 文字以内で記述。\n- JSON 以外は絶対に出力しない。\n- 200 件を超えるタスクは生成しない。\n\n【タスク生成ガイド】\n- プロジェクト・フェーズ・タスクリストの目的と既存タスクを最優先。\n- 5〜25分程度で完了できる粒度に分割。\n- 写真から得られるヒントは補助に用い、文脈と矛盾しないように調整。\n\(ctx)\n写真とコンテクストを解析し、このスキーマに完全準拠した JSON のみを返してください。
        """
    }
}

// MARK: - OpenAI Response Models

private struct OpenAIPlanResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: [Content]

        struct Content: Decodable {
            let type: String
            let text: String?
            let outputJSON: Plan?

            enum CodingKeys: String, CodingKey {
                case type
                case text
                case outputJSON = "output_json"
            }
        }
    }
}
