import Foundation

/// Rate limit and quota management for AI providers
@MainActor
final class ProviderThrottleCenter: ObservableObject {
    
    static let shared = ProviderThrottleCenter()
    
    private var cooldowns: [KeychainManager.APIProvider: Date] = [:]
    private let defaultCooldownDuration: TimeInterval = 45 // 45 seconds
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Mark a provider as cooling down for the specified duration
    func markCoolingDown(_ provider: KeychainManager.APIProvider, for seconds: TimeInterval = 45) {
        let cooldownUntil = Date().addingTimeInterval(seconds)
        cooldowns[provider] = cooldownUntil
        
        print("🔥 Provider \(provider.displayName) cooling down until \(cooldownUntil)")
    }
    
    /// Check if a provider is currently cooling down
    func isCoolingDown(_ provider: KeychainManager.APIProvider) -> Bool {
        guard let cooldownUntil = cooldowns[provider] else {
            return false
        }
        
        let now = Date()
        if now >= cooldownUntil {
            // Cooldown expired, remove from dictionary
            cooldowns.removeValue(forKey: provider)
            return false
        }
        
        return true
    }
    
    /// Get remaining cooldown time for a provider
    func getRemainingCooldownTime(for provider: KeychainManager.APIProvider) -> TimeInterval? {
        guard let cooldownUntil = cooldowns[provider] else {
            return nil
        }
        
        let remaining = cooldownUntil.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }
    
    /// Get all available providers excluding those in cooldown
    func getAvailableProviders(from allProviders: [KeychainManager.APIProvider]) -> [KeychainManager.APIProvider] {
        return allProviders.filter { !isCoolingDown($0) }
    }
    
    /// Reset all cooldowns (for testing or manual reset)
    func resetAllCooldowns() {
        cooldowns.removeAll()
    }
    
    /// Get next available time when any provider will be available
    func getNextAvailableTime() -> Date? {
        let activeCooldowns = cooldowns.values.filter { $0 > Date() }
        return activeCooldowns.min()
    }
    
    /// Get formatted message about next available provider
    func getNextAvailableMessage() -> String? {
        guard let nextTime = getNextAvailableTime() else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        
        return "次の候補: \(formatter.string(from: nextTime))"
    }
}