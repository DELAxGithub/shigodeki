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
                return try parsePlanResponse(data)
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
    
    private func parsePlanResponse(_ data: Data) throws -> Plan {
        let openAIResponse = try JSONDecoder().decode(TidyPlanOpenAIResponse.self, from: data)
        guard let content = openAIResponse.choices.first?.message.content else {
            throw TidyPlanError.invalidJSON
        }
        let planData = content.data(using: .utf8)!
        let plan = try JSONDecoder().decode(Plan.self, from: planData)
        return plan.validated()
    }
    
    private func createPrompt(for locale: UserLocale, context: String?) -> String {
        let ctx = (context?.isEmpty == false) ? "\n【コンテクスト】\n\(context!)\n" : ""
        return """
        あなたは片付け・引越し前整理の日本語アシスタントです。写真とコンテクストを解析し、処分・譲渡・保管などの具体的タスクを日本語で提案してください。\n\n【出力要件】\n- JSONのみを返す（テキストや説明は不要）\n- スキーマに従う（tasks配列の各要素に必ず id, title, exit_tag）\n- title は実行可能で短い日本語命令文\n- checklist は手順を箇条書き（各1行）\n- priority は 1〜4（4=緊急）\n- effort_min は 5〜120 の目安\n- \(locale.city), \(locale.country) に関連するリンクがあれば links に含める\n\n【タスクの観点】\n- 何を捨てる/売る/譲る/保管するかを明確に\n- 5〜25分程度で進められる粒度に分割\n\(ctx)\n写真を解析して、スキーマ準拠のJSONのみを出力してください。
        """
    }
}

// MARK: - OpenAI Response Models

private struct TidyPlanOpenAIResponse: Codable {
    let choices: [Choice]
    struct Choice: Codable { let message: Message }
    struct Message: Codable { let content: String }
}
