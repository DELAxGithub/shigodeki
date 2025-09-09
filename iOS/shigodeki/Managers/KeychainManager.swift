import Foundation
import Security

/// Secure API key management using Keychain Services
final class KeychainManager {
    
    enum APIProvider: String, CaseIterable {
        case openAI = "openai"
        case claude = "claude"
        case gemini = "gemini"
        
        var displayName: String {
            switch self {
            case .openAI:
                return "OpenAI"
            case .claude:
                return "Anthropic Claude"
            case .gemini:
                return "Google Gemini"
            }
        }
    }
    
    enum KeychainError: Error, LocalizedError {
        case itemNotFound
        case duplicateItem
        case invalidItemFormat
        case unexpectedPasswordData
        case unhandledError(status: OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "API key not found in Keychain"
            case .duplicateItem:
                return "API key already exists"
            case .invalidItemFormat:
                return "Invalid API key format"
            case .unexpectedPasswordData:
                return "Unexpected password data format"
            case .unhandledError(let status):
                return "Keychain error: \(status)"
            }
        }
    }
    
    private let serviceName = "com.company.shigodeki.api-keys"
    private let defaults = UserDefaults.standard
    private let defaultProviderKey = "ai.defaultProvider"
    
    static let shared = KeychainManager()
    private init() {}
    
    // MARK: - Public Methods
    
    /// Store API key securely in Keychain
    func storeAPIKey(_ apiKey: String, for provider: APIProvider) throws {
        let account = provider.rawValue
        
        // Remove existing key first if it exists
        try? removeAPIKey(for: provider)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: apiKey.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess:
            break
        case errSecDuplicateItem:
            throw KeychainError.duplicateItem
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Retrieve API key from Keychain
    func retrieveAPIKey(for provider: APIProvider) throws -> String {
        let account = provider.rawValue
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        switch status {
        case errSecSuccess:
            guard let data = dataTypeRef as? Data,
                  let apiKey = String(data: data, encoding: .utf8) else {
                throw KeychainError.unexpectedPasswordData
            }
            return apiKey
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Remove API key from Keychain
    func removeAPIKey(for provider: APIProvider) throws {
        let account = provider.rawValue
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        switch status {
        case errSecSuccess, errSecItemNotFound:
            break
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Check if API key exists for provider
    func hasAPIKey(for provider: APIProvider) -> Bool {
        do {
            _ = try retrieveAPIKey(for: provider)
            return true
        } catch {
            return false
        }
    }
    
    /// Get all configured providers
    func getConfiguredProviders() -> [APIProvider] {
        return APIProvider.allCases.filter { hasAPIKey(for: $0) }
    }
    
    // MARK: - Preferred Provider (User Defaults)
    
    /// Returns the user-selected default AI provider if set
    func getDefaultProvider() -> APIProvider? {
        guard let raw = defaults.string(forKey: defaultProviderKey) else { return nil }
        return APIProvider(rawValue: raw)
    }
    
    /// Persists the user-selected default AI provider
    func setDefaultProvider(_ provider: APIProvider?) {
        if let provider = provider {
            defaults.set(provider.rawValue, forKey: defaultProviderKey)
        } else {
            defaults.removeObject(forKey: defaultProviderKey)
        }
    }
    
    /// Validate API key format
    func validateAPIKey(_ apiKey: String, for provider: APIProvider) -> Bool {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch provider {
        case .openAI:
            // OpenAI keys start with "sk-" and are typically 51 characters
            return trimmedKey.hasPrefix("sk-") && trimmedKey.count >= 20
        case .claude:
            // Claude keys start with "sk-ant-" 
            return trimmedKey.hasPrefix("sk-ant-") && trimmedKey.count >= 20
        case .gemini:
            // Gemini keys start with "AIza" and are typically longer than 20 characters
            return trimmedKey.hasPrefix("AIza") && trimmedKey.count >= 20
        }
    }
}
