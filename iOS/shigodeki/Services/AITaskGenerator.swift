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
        
        do {
            let enhancedPrompt = AITaskPromptBuilder.buildEnhancedPrompt(userPrompt: prompt, projectType: projectType)
            let client = AIClientRouter.getClient(for: selectedProvider)
            
            progressMessage = "Connecting to \(selectedProvider.displayName)..."
            
            let suggestions = try await client.generateTaskSuggestions(for: enhancedPrompt)
            
            progressMessage = "Processing suggestions..."
            
            // 🚨 CTO修正: UX改善のための人工的遅延を撤廃
            // レスポンシブなUIのため、遅延なしで即座に結果を表示
            
            generatedSuggestions = suggestions
            progressMessage = "Task suggestions generated successfully!"
            
        } catch let aiError as AIClientError {
            error = aiError
            progressMessage = ""
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
    func generateTaskDetails(for task: ShigodekiTask) async -> String? {
        guard !isGenerating else { return nil }
        
        updateAvailableProviders()
        guard !availableProviders.isEmpty else { return nil }
        
        let prompt = AITaskPromptBuilder.buildTaskDetailPrompt(for: task)
        
        do {
            let detailText = try await generateText(prompt: prompt)
            return detailText
        } catch {
            self.error = error as? AIClientError ?? .networkError(error)
            return nil
        }
    }
    
    
    // Generic text generation method for analysis and other purposes
    func generateText(prompt: String) async throws -> String {
        guard !isGenerating else { throw AIClientError.serviceUnavailable }
        
        updateAvailableProviders()
        
        guard !availableProviders.isEmpty else {
            throw AIClientError.apiKeyNotConfigured
        }
        
        isGenerating = true
        error = nil
        progressMessage = "Generating analysis..."
        
        defer { isGenerating = false }
        
        do {
            // Get universal client directly from provider
            let universalClient = getUniversalClient(for: selectedProvider)
            
            progressMessage = "Connecting to \(selectedProvider.displayName)..."
            
            let response = try await universalClient.generateText(
                prompt: prompt,
                system: "You are a helpful AI assistant. Provide detailed, accurate, and helpful responses.",
                temperature: 0.7
            )
            
            progressMessage = "Processing response..."
            
            return response
            
        } catch let aiError as AIClientError {
            error = aiError
            progressMessage = ""
            throw aiError
        } catch {
            let networkError = AIClientError.networkError(error)
            self.error = networkError
            progressMessage = ""
            throw networkError
        }
    }
    
    private func getUniversalClient(for provider: KeychainManager.APIProvider) -> UniversalAIClient {
        switch provider {
        case .openAI:
            return OpenAIClient()
        case .claude:
            return ClaudeClient()
        }
    }
    
    func updateAvailableProviders() {
        let result = AIClientRouter.updateAvailableProviders(currentProvider: selectedProvider)
        availableProviders = result.providers
        selectedProvider = result.selected
    }
    
    // MARK: - Private Methods
    
    
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