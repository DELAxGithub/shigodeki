import Foundation

/// Service responsible for AI provider selection and client routing
struct AIClientRouter {
    
    /// Creates an AI client for the specified provider
    static func getClient(for provider: KeychainManager.APIProvider) -> AIClient {
        switch provider {
        case .openAI:
            return OpenAIClient()
        case .claude:
            return ClaudeClient()
        case .gemini:
            return GeminiClient()
        }
    }
    
    /// Updates available providers and returns the selected provider
    static func updateAvailableProviders(currentProvider: KeychainManager.APIProvider) -> (providers: [KeychainManager.APIProvider], selected: KeychainManager.APIProvider) {
        let availableProviders = KeychainManager.shared.getConfiguredProviders()
        
        // Update selected provider if current one is not available
        let selectedProvider: KeychainManager.APIProvider
        if availableProviders.contains(currentProvider) {
            selectedProvider = currentProvider
        } else {
            selectedProvider = availableProviders.first ?? .openAI
        }
        
        return (availableProviders, selectedProvider)
    }
}