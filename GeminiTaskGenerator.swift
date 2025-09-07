// (ファイルパスは仮のものです)

import Foundation
import GoogleGenerativeAI

/// Gemini APIを使用してタスク詳細を生成するクラス
final class GeminiTaskGenerator: AITaskGenerator {
    private let client: GenerativeModel

    init(apiKey: String) {
        // Google AI for Developers SDK を使用
        self.client = GenerativeModel(name: "gemini-pro", apiKey: apiKey)
    }

    func generateTaskDetails(for task: ShigodekiTask) async throws -> String {
        let prompt = """
        あなたは優秀なプロジェクトマネージャーです。
        以下のタスクについて、具体的な実行ステップや考慮事項を詳細に記述してください。

        タスク名: \(task.title)
        タスク説明: \(task.description ?? "なし")
        """

        do {
            let response = try await client.generateContent(prompt)
            guard let text = response.text else {
                throw AIClientError.invalidResponse
            }
            return text
        } catch let error as GenerateContentError {
            // SDKのエラーをアプリ固有のAIClientErrorに変換する
            // (例: .rateLimitExceeded, .serviceUnavailable など)
            throw AIClientError.apiError(message: error.localizedDescription)
        } catch {
            throw AIClientError.unknown(error)
        }
    }
}