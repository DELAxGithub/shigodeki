import Foundation
import SwiftUI
import os.log

/// AI機能の状態管理を一元化するマネージャー
/// State Patternを適用し、不正な状態組み合わせを防止
@MainActor
final class AIStateManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// AI機能の現在状態（State Pattern適用）
    @Published private(set) var state: AIState = .idle
    
    // MARK: - Private Properties
    
    private let aiGenerator: AITaskGenerator
    private let keychainManager: KeychainManager
    private let logger = Logger(subsystem: "com.company.shigodeki", category: "AIStateManager")
    
    // MARK: - Initialization
    
    // 依存性をオプショナルにし、nilの場合はデフォルトのインスタンスを生成する堅牢なパターン
    init(aiGenerator: AITaskGenerator? = nil, 
         keychainManager: KeychainManager = KeychainManager.shared) {
        // aiGeneratorが外部から注入されなかった場合、新しいインスタンスを生成する
        self.aiGenerator = aiGenerator ?? AITaskGenerator()
        self.keychainManager = keychainManager
    }
    
    // MARK: - Public Methods
    
    /// API設定状況を確認し、適切な状態に遷移
    func checkConfiguration() {
        logger.info("🔍 AIStateManager: Starting configuration check")
        print("🔍 AIStateManager: Starting configuration check")
        state = .checkingConfiguration
        
        Task {
            let providers = keychainManager.getConfiguredProviders()
            logger.debug("🔑 AIStateManager: Found providers")
            print("🔑 AIStateManager: Found \(providers.count) configured providers")
            
            await MainActor.run {
                if providers.isEmpty {
                    let guidance = ConfigurationGuidance.createDefault()
                    logger.warning("⚠️ AIStateManager: No providers configured")
                    print("⚠️ AIStateManager: No providers configured, transitioning to needsConfiguration")
                    state = .needsConfiguration(guidance: guidance)
                } else {
                    logger.info("✅ AIStateManager: Configuration valid")
                    print("✅ AIStateManager: Configuration valid, transitioning to ready")
                    state = .ready
                }
            }
        }
    }
    
    /// タスクの詳細提案をAIに生成させる
    func generateDetail(for task: ShigodekiTask) {
        guard case .ready = state else { 
            logger.warning("⚠️ AIStateManager: generateDetail called but state not ready")
            print("⚠️ AIStateManager: generateDetail called but state is not ready: \(state)")
            return 
        }
        
        let taskId = task.id ?? "unknown"
        logger.info("🤖 AIStateManager: Starting task detail generation")
        print("🤖 AIStateManager: Starting task detail generation for task: \(taskId)")
        state = .loading(message: "AIがタスクを分析中です...")
        
        Task {
            do {
                if let detailText = await aiGenerator.generateTaskDetails(for: task) {
                    logger.info("✅ AIStateManager: Successfully generated task details")
                    print("✅ AIStateManager: Successfully generated task details")
                    let result = AIDetailResult(content: detailText)
                    await MainActor.run {
                        state = .suggestion(result: result)
                    }
                } else {
                    logger.error("❌ AIStateManager: Task detail generation returned nil")
                    print("❌ AIStateManager: Task detail generation returned nil")
                    await MainActor.run {
                        state = .error(message: "AI提案の生成に失敗しました")
                    }
                }
            } catch {
                logger.error("❌ AIStateManager: Error generating task details")
                print("❌ AIStateManager: Error generating task details: \(error.localizedDescription)")
                await MainActor.run {
                    if let aiError = error as? AIClientError {
                        state = .error(message: aiError.localizedDescription)
                    } else {
                        state = .error(message: "予期しないエラーが発生しました")
                    }
                }
            }
        }
    }
    
    /// AI提案を適用して準備完了状態に戻る
    func applyResult(_ result: String) {
        logger.info("✅ AIStateManager: Applying AI result")
        print("✅ AIStateManager: Applying AI result and transitioning to ready")
        state = .ready
    }
    
    /// AI提案を却下して準備完了状態に戻る
    func dismissResult() {
        logger.info("❌ AIStateManager: Dismissing AI result")
        print("❌ AIStateManager: Dismissing AI result and transitioning to ready")
        state = .ready
    }
    
    /// エラー状態から設定確認をやり直す
    func retry() {
        logger.info("🔄 AIStateManager: Retrying from error state")
        print("🔄 AIStateManager: Retrying from error state")
        checkConfiguration()
    }
}

// MARK: - State Definition

extension AIStateManager {
    
    /// AI機能の状態を表現するenum（State Pattern）
    enum AIState: Equatable {
        /// 初期状態
        case idle
        /// 設定確認中
        case checkingConfiguration
        /// API設定が必要
        case needsConfiguration(guidance: ConfigurationGuidance)
        /// AI機能利用可能
        case ready
        /// AI処理中
        case loading(message: String)
        /// AI提案表示中
        case suggestion(result: AIDetailResult)
        /// エラー状態
        case error(message: String)
        
        // Equatable conformance
        static func == (lhs: AIState, rhs: AIState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.checkingConfiguration, .checkingConfiguration),
                 (.ready, .ready):
                return true
            case let (.needsConfiguration(lhsGuidance), .needsConfiguration(rhsGuidance)):
                return lhsGuidance == rhsGuidance
            case let (.loading(lhsMessage), .loading(rhsMessage)):
                return lhsMessage == rhsMessage
            case let (.suggestion(lhsResult), .suggestion(rhsResult)):
                return lhsResult == rhsResult
            case let (.error(lhsMessage), .error(rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
}

// MARK: - Supporting Types

/// API設定案内情報
struct ConfigurationGuidance: Equatable {
    let message: String
    let actionRequired: String
    
    static func createDefault() -> ConfigurationGuidance {
        return ConfigurationGuidance(
            message: "APIキーが設定されていません",
            actionRequired: "AI設定を開いてAPIキーを設定してください"
        )
    }
}

/// AI詳細提案結果
struct AIDetailResult: Equatable {
    let content: String
    let timestamp: Date
    
    init(content: String) {
        self.content = content
        self.timestamp = Date()
    }
    
    // Equatable conformance (comparing content only for simplicity)
    static func == (lhs: AIDetailResult, rhs: AIDetailResult) -> Bool {
        return lhs.content == rhs.content
    }
}