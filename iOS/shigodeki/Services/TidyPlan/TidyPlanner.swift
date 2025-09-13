import Foundation

final class TidyPlanner {
    private let apiKey: String?
    
    init(apiKey: String?) {
        self.apiKey = apiKey
    }
    
    /// Generates a plan from image data. Returns a fallback plan if network is disabled or API fails.
    func generate(from imageData: Data, locale: UserLocale, allowNetwork: Bool, context: String? = nil) async -> Plan {
        guard allowNetwork, let key = apiKey, !key.isEmpty else {
            return FallbackPlanner.generatePlan(locale: locale)
        }
        do {
            let openAI = OpenAIService(apiKey: key)
            return try await openAI.generatePlan(from: imageData, locale: locale, context: context)
        } catch {
            return FallbackPlanner.generatePlan(locale: locale)
        }
    }
    
    static func fallbackPlan(locale: UserLocale = UserLocale(country: "CA", city: "Toronto")) -> Plan {
        FallbackPlanner.generatePlan(locale: locale)
    }
}
