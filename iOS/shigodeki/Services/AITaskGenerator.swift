import Foundation
import SwiftUI

@MainActor
final class AITaskGenerator: ObservableObject {
    @Published var isGenerating = false
    @Published var generatedSuggestions: AITaskSuggestion?
    @Published var error: AIClientError?
    @Published var availableProviders: [KeychainManager.APIProvider] = []
    @Published var selectedProvider: KeychainManager.APIProvider = .openAI
    @Published var progressMessage = ""
    @Published var lastParseStatus: AITaskParseStatus = .ok
    
    private var currentClient: AIClient?
    private var universalClient: UniversalAIClient?
    
    init() {
        updateAvailableProviders()
    }
    
    // MARK: - Public Methods
    
    func generateTaskSuggestions(for prompt: String, projectType: ProjectType? = nil) async {
        guard !isGenerating else { return }
        
        updateAvailableProviders()
        
        guard !availableProviders.isEmpty else {
            error = .apiKeyNotConfigured
            return
        }

        isGenerating = true
        error = nil
        progressMessage = "Generating intelligent task suggestions..."
        lastParseStatus = .ok

        do {
            let enhancedPrompt = AITaskPromptBuilder.buildEnhancedPrompt(userPrompt: prompt, projectType: projectType)
            
            // Use failover-enabled generation
            let suggestions = try await generateTaskSuggestionsWithFailover(prompt: enhancedPrompt)
            
            progressMessage = "Processing suggestions..."
            
            // 🚨 CTO修正: UX改善のための人工的遅延を撤廃
            // レスポンシブなUIのため、遅延なしで即座に結果を表示
            
            generatedSuggestions = suggestions
            if lastParseStatus == .missingProject {
                progressMessage = "コンテクスト不足があったため、既定のプロジェクト名を使用しました"
            } else {
                progressMessage = "Task suggestions generated successfully!"
            }

        } catch let aiError as AIClientError {
            // Set final error message with next available info if all providers failed
            if let nextAvailable = ProviderThrottleCenter.shared.getNextAvailableMessage() {
                error = aiError
                progressMessage = "現在混雑しています。しばらく待ってから再試行してください（\(nextAvailable))"
            } else {
                error = aiError
                progressMessage = ""
            }
        } catch {
            self.error = .networkError(error)
            progressMessage = ""
        }
        
        isGenerating = false
    }
    
    func clearSuggestions() {
        generatedSuggestions = nil
        error = nil
        progressMessage = ""
    }
    
    // Generate detailed task description and implementation steps
    func generateTaskDetails(for task: ShigodekiTask) async throws -> String {
        guard !isGenerating else { 
            print("🚫 AITaskGenerator: generateTaskDetails called while already generating")
            throw AIClientError.serviceUnavailable 
        }
        
        updateAvailableProviders()
        guard !availableProviders.isEmpty else { 
            print("🚫 AITaskGenerator: No available providers for generateTaskDetails")
            throw AIClientError.apiKeyNotConfigured 
        }
        
        print("🤖 AITaskGenerator: Starting task detail generation for task: \(task.title)")
        let prompt = AITaskPromptBuilder.buildTaskDetailPrompt(for: task)
        
        do {
            let detailText = try await generateText(prompt: prompt)
            print("✅ AITaskGenerator: Successfully generated task details")
            return detailText
        } catch let aiError as AIClientError {
            print("❌ AITaskGenerator: AI client error: \(aiError.localizedDescription)")
            self.error = aiError
            throw aiError
        } catch {
            print("❌ AITaskGenerator: Network error: \(error.localizedDescription)")
            let networkError = AIClientError.networkError(error)
            self.error = networkError
            throw networkError
        }
    }
    
    
    // Generic text generation method for analysis and other purposes
    func generateText(prompt: String) async throws -> String {
        guard !isGenerating else { 
            print("🚫 AITaskGenerator: generateText called while already generating")
            throw AIClientError.serviceUnavailable 
        }
        
        updateAvailableProviders()
        
        guard !availableProviders.isEmpty else {
            print("🚫 AITaskGenerator: No available providers for generateText")
            throw AIClientError.apiKeyNotConfigured
        }
        
        print("🤖 AITaskGenerator: Starting text generation")
        isGenerating = true
        error = nil
        progressMessage = "Generating analysis..."
        
        defer { isGenerating = false }
        
        return try await generateTextWithFailover(
            prompt: prompt,
            system: "You are a helpful AI assistant. Provide detailed, accurate, and helpful responses.",
            temperature: 0.7
        )
    }
    
    private func getUniversalClient(for provider: KeychainManager.APIProvider) -> UniversalAIClient {
        switch provider {
        case .openAI:
            return OpenAIClient()
        case .claude:
            return ClaudeClient()
        case .gemini:
            return GeminiClient()
        }
    }
    
    func updateAvailableProviders() {
        let result = AIClientRouter.updateAvailableProviders(currentProvider: selectedProvider)
        availableProviders = result.providers
        // Respect user preferred provider if it is available
        if let preferred = KeychainManager.shared.getDefaultProvider(),
           result.providers.contains(preferred) {
            selectedProvider = preferred
        } else {
            selectedProvider = result.selected
        }
    }
    
    // MARK: - Private Methods
    
    /// Generate task suggestions with automatic provider failover
    private func generateTaskSuggestionsWithFailover(prompt: String) async throws -> AITaskSuggestion {
        let availableProviders = ProviderThrottleCenter.shared.getAvailableProviders(from: self.availableProviders)
        
        guard !availableProviders.isEmpty else {
            if ProviderThrottleCenter.shared.getNextAvailableMessage() != nil {
                throw AIClientError.rateLimitExceeded // Will be handled with next available message
            } else {
                throw AIClientError.apiKeyNotConfigured
            }
        }
        
        // Start with selected provider if not in cooldown, otherwise use first available
        var currentProvider = availableProviders.contains(selectedProvider) ? selectedProvider : availableProviders.first!
        var hasTriedFailover = false
        var lastError: AIClientError?
        var lastProvider: KeychainManager.APIProvider = currentProvider
        
        for attempt in 0...2 { // 3 attempts with backoff
            do {
                let client = AIClientRouter.getClient(for: currentProvider)
                
                progressMessage = "Connecting to \(currentProvider.displayName)..."
                Telemetry.fire(
                    .onAIGenerationAttempt,
                    TelemetryPayload(aiProvider: currentProvider.rawValue, jsonMode: true)
                )

                let result = try await client.generateTaskSuggestions(for: prompt)
                let normalizedStatus: AITaskParseStatus = (result.status == .legacy) ? .ok : result.status
                lastParseStatus = normalizedStatus

                Telemetry.fire(
                    .onAIGenerationParsed,
                    TelemetryPayload(
                        aiProvider: currentProvider.rawValue,
                        aiParse: normalizedStatus.rawValue,
                        fellBack: hasTriedFailover
                    )
                )

                return result.suggestion
                
            } catch let aiError as AIClientError {
                // Check if this is a retryable error that should trigger cooldown
                let shouldCooldown = aiError == .rateLimitExceeded || aiError == .quotaExceeded || aiError == .serviceUnavailable
                lastError = aiError
                lastProvider = currentProvider

                let parseLabel = (aiError == .invalidJSON) ? "invalid_json" : "error"
                Telemetry.fire(
                    .onAIGenerationParsed,
                    TelemetryPayload(
                        aiProvider: currentProvider.rawValue,
                        aiParse: parseLabel,
                        fellBack: hasTriedFailover,
                        reason: telemetryReason(for: aiError)
                    )
                )
                
                if shouldCooldown {
                    // Mark this provider for cooldown
                    ProviderThrottleCenter.shared.markCoolingDown(currentProvider)
                    
                    // Try to failover to another provider (once per request)
                    if !hasTriedFailover {
                        let stillAvailableProviders = ProviderThrottleCenter.shared.getAvailableProviders(from: self.availableProviders)
                        
                        if let nextProvider = stillAvailableProviders.first(where: { $0 != currentProvider }) {
                            hasTriedFailover = true
                            progressMessage = "プロバイダ切替で再試行中: \(currentProvider.displayName) → \(nextProvider.displayName)"
                            currentProvider = nextProvider
                            continue // Try with new provider
                        }
                    }
                    
                    // If no failover available, use exponential backoff
                    if attempt < 2 {
                        let delay = pow(2.0, Double(attempt)) + Double.random(in: 0...1)
                        progressMessage = "Rate limited... retry in \(Int(delay))s"
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                }
                
                // Non-retryable error or max retries reached
                throw aiError
            }
        }

        Telemetry.fire(
            .onAIGenerationFallback,
            TelemetryPayload(
                aiProvider: lastProvider.rawValue,
                aiParse: nil,
                fellBack: true,
                reason: telemetryReason(for: lastError ?? .serviceUnavailable)
            )
        )

        throw lastError ?? AIClientError.rateLimitExceeded
    }
    
    /// Generate text with automatic provider failover
    private func generateTextWithFailover(prompt: String, system: String, temperature: Double) async throws -> String {
        let availableProviders = ProviderThrottleCenter.shared.getAvailableProviders(from: self.availableProviders)
        
        guard !availableProviders.isEmpty else {
            throw AIClientError.apiKeyNotConfigured
        }
        
        // Start with selected provider if not in cooldown, otherwise use first available
        var currentProvider = availableProviders.contains(selectedProvider) ? selectedProvider : availableProviders.first!
        var hasTriedFailover = false
        
        for attempt in 0...2 { // 3 attempts with backoff
            do {
                let universalClient = getUniversalClient(for: currentProvider)
                
                progressMessage = "Connecting to \(currentProvider.displayName)..."
                let response = try await universalClient.generateText(
                    prompt: prompt,
                    system: system,
                    temperature: temperature
                )
                
                progressMessage = "Processing response..."
                print("✅ AITaskGenerator: Successfully generated text")
                
                return response
                
            } catch let aiError as AIClientError {
                // Check if this is a retryable error that should trigger cooldown
                let shouldCooldown = aiError == .rateLimitExceeded || aiError == .quotaExceeded || aiError == .serviceUnavailable
                
                if shouldCooldown {
                    // Mark this provider for cooldown
                    ProviderThrottleCenter.shared.markCoolingDown(currentProvider)
                    
                    // Try to failover to another provider (once per request)
                    if !hasTriedFailover {
                        let stillAvailableProviders = ProviderThrottleCenter.shared.getAvailableProviders(from: self.availableProviders)
                        
                        if let nextProvider = stillAvailableProviders.first(where: { $0 != currentProvider }) {
                            hasTriedFailover = true
                            progressMessage = "プロバイダ切替で再試行中: \(currentProvider.displayName) → \(nextProvider.displayName)"
                            currentProvider = nextProvider
                            continue // Try with new provider
                        }
                    }
                    
                    // If no failover available, use exponential backoff
                    if attempt < 2 {
                        let delay = pow(2.0, Double(attempt)) + Double.random(in: 0...1)
                        progressMessage = "Rate limited... retry in \(Int(delay))s"
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                }
                
                // Non-retryable error or max retries reached
                print("❌ AITaskGenerator: AI client error: \(aiError.localizedDescription)")
                error = aiError
                progressMessage = ""
                throw aiError
            } catch {
                print("❌ AITaskGenerator: Network error: \(error.localizedDescription)")
                let networkError = AIClientError.networkError(error)
                self.error = networkError
                progressMessage = ""
                throw networkError
            }
        }
        
        print("❌ AITaskGenerator: Exceeded maximum retries for rate limiting")
        let rateLimitError = AIClientError.rateLimitExceeded
        error = rateLimitError
        progressMessage = ""
        throw rateLimitError
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
        case .invalidJSON:
            return "invalid_json"
        case .invalidResponse:
            return "invalid_response"
        case .networkError:
            return "network_error"
        }
    }
}

// MARK: - Project Type Enum

enum ProjectType: String, CaseIterable, Identifiable {
    case work = "work"
    case personal = "personal"
    case family = "family"
    case creative = "creative"
    case learning = "learning"
    case health = "health"
    case travel = "travel"
    case home = "home"
    case financial = "financial"
    case social = "social"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .work: return "Work & Business"
        case .personal: return "Personal"
        case .family: return "Family"
        case .creative: return "Creative"
        case .learning: return "Learning"
        case .health: return "Health & Wellness"
        case .travel: return "Travel"
        case .home: return "Home & Household"
        case .financial: return "Financial"
        case .social: return "Social & Community"
        case .custom: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .family: return "house.fill"
        case .creative: return "paintbrush.fill"
        case .learning: return "book.fill"
        case .health: return "heart.fill"
        case .travel: return "airplane"
        case .home: return "wrench.and.screwdriver.fill"
        case .financial: return "dollarsign.circle.fill"
        case .social: return "person.3.fill"
        case .custom: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .work: return .blue
        case .personal: return .green
        case .family: return .orange
        case .creative: return .purple
        case .learning: return .indigo
        case .health: return .red
        case .travel: return .cyan
        case .home: return .brown
        case .financial: return .yellow
        case .social: return .pink
        case .custom: return .gray
        }
    }
}

// MARK: - Task Generation Helper

extension AITaskGenerator {
    
    /// Convert AI suggestions to Task objects for the app
    func convertSuggestionsToTasks(_ suggestions: AITaskSuggestion, for project: Project) -> [ShigodekiTask] {
        return AITaskConverter.convertSuggestionsToTasks(suggestions, for: project)
    }
}
