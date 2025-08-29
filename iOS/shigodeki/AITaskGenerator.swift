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
            let enhancedPrompt = buildEnhancedPrompt(userPrompt: prompt, projectType: projectType)
            let client = getClient(for: selectedProvider)
            
            progressMessage = "Connecting to \(selectedProvider.displayName)..."
            
            let suggestions = try await client.generateTaskSuggestions(for: enhancedPrompt)
            
            progressMessage = "Processing suggestions..."
            
            // Add slight delay for better UX
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
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
            let client = getClient(for: selectedProvider)
            
            // Since AIClient only supports task suggestions, we'll adapt the prompt
            // to generate text content structured as a single task description
            let adaptedPrompt = """
            Generate a comprehensive analysis based on the following request:
            
            \(prompt)
            
            Please provide a detailed response that directly addresses the request. Format your response as a single comprehensive description without task breakdown.
            """
            
            progressMessage = "Connecting to \(selectedProvider.displayName)..."
            
            let suggestions = try await client.generateTaskSuggestions(for: adaptedPrompt)
            
            progressMessage = "Processing response..."
            
            // Extract the text from the first task's description as our generated text
            if let firstTask = suggestions.tasks.first {
                return firstTask.description
            } else if let firstPhase = suggestions.phases?.first,
                      let firstPhaseTask = firstPhase.tasks.first {
                return firstPhaseTask.description
            } else {
                throw AIClientError.invalidResponse
            }
            
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
    
    func updateAvailableProviders() {
        availableProviders = KeychainManager.shared.getConfiguredProviders()
        
        // Update selected provider if current one is not available
        if !availableProviders.contains(selectedProvider) {
            selectedProvider = availableProviders.first ?? .openAI
        }
    }
    
    // MARK: - Private Methods
    
    private func getClient(for provider: KeychainManager.APIProvider) -> AIClient {
        switch provider {
        case .openAI:
            return OpenAIClient()
        case .claude:
            return ClaudeClient()
        }
    }
    
    private func buildEnhancedPrompt(userPrompt: String, projectType: ProjectType?) -> String {
        var prompt = userPrompt
        
        // Add project type context if available
        if let projectType = projectType {
            let typeContext = getProjectTypeContext(projectType)
            prompt = "\(typeContext)\n\nProject request: \(prompt)"
        }
        
        // Add general context for better task generation
        let generalContext = """
        
        Additional context:
        - This is for a task management app where users organize work into projects, phases, and tasks
        - Tasks can have subtasks for detailed breakdown
        - Include time estimates that are realistic and helpful
        - Consider dependencies between tasks when creating phases
        - Focus on actionable, specific tasks rather than vague goals
        """
        
        return prompt + generalContext
    }
    
    private func getProjectTypeContext(_ projectType: ProjectType) -> String {
        switch projectType {
        case .work:
            return "This is a work/professional project. Focus on business objectives, deliverables, and professional workflows."
        case .personal:
            return "This is a personal project. Consider work-life balance, personal goals, and individual capacity."
        case .family:
            return "This is a family project involving multiple family members. Consider coordination, age-appropriate tasks, and family schedules."
        case .creative:
            return "This is a creative project. Focus on artistic processes, inspiration phases, and creative milestones."
        case .learning:
            return "This is a learning/educational project. Include research phases, practice tasks, and knowledge building steps."
        case .health:
            return "This is a health and wellness project. Consider gradual progress, sustainability, and health best practices."
        case .travel:
            return "This is a travel project. Include planning phases, booking tasks, and travel logistics."
        case .home:
            return "This is a home improvement or household project. Consider practical steps, safety, and maintenance."
        case .financial:
            return "This is a financial planning project. Focus on research, analysis, and systematic financial steps."
        case .social:
            return "This is a social or community project. Consider group coordination, communication, and social dynamics."
        case .custom:
            return "This is a custom project type. Adapt suggestions to be flexible and broadly applicable."
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
        let taskManager = TaskManager()
        var tasks: [ShigodekiTask] = []
        
        // If we have phases, create tasks within phases
        if let phases = suggestions.phases {
            for (phaseIndex, phase) in phases.enumerated() {
                for (taskIndex, taskSuggestion) in phase.tasks.enumerated() {
                    let task = createTask(
                        from: taskSuggestion,
                        project: project,
                        phaseIndex: phaseIndex,
                        taskIndex: taskIndex,
                        phaseName: phase.name
                    )
                    tasks.append(task)
                }
            }
        } else {
            // Create tasks directly
            for (index, taskSuggestion) in suggestions.tasks.enumerated() {
                let task = createTask(
                    from: taskSuggestion,
                    project: project,
                    phaseIndex: nil as Int?,
                    taskIndex: index,
                    phaseName: nil as String?
                )
                tasks.append(task)
            }
        }
        
        return tasks
    }
    
    private func createTask(
        from suggestion: AITaskSuggestion.TaskSuggestion,
        project: Project,
        phaseIndex: Int?,
        taskIndex: Int,
        phaseName: String?
    ) -> ShigodekiTask {
        
        // We need to create a task with the proper ShigodekiTask initializer
        // For now, use placeholder values since we'd need proper IDs
        let task = ShigodekiTask(
            title: suggestion.title,
            description: suggestion.description,
            assignedTo: nil,
            createdBy: project.ownerId,
            dueDate: nil,
            priority: mapPriority(suggestion.priority),
            listId: "temp-list-id", // Would need proper list creation
            phaseId: "temp-phase-id", // Would need proper phase creation
            projectId: project.id ?? "temp-project-id",
            order: taskIndex
        )
        
        // Set phase if available
        if let phaseIndex = phaseIndex, let phaseName = phaseName {
            // This would need to be handled by the calling code
            // as we'd need to create/reference phases
        }
        
        return task
    }
    
    private func mapPriority(_ aiPriority: AITaskPriority) -> TaskPriority {
        switch aiPriority {
        case .low:
            return .low
        case .medium:
            return .medium
        case .high:
            return .high
        case .urgent:
            return .high // Map urgent to high as our app only has 3 levels
        }
    }
    
    private func parseEstimatedDuration(_ duration: String) -> TimeInterval? {
        let lowercased = duration.lowercased()
        
        // Simple duration parsing - could be enhanced
        if lowercased.contains("minute") {
            let numbers = lowercased.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            if let minutes = numbers.first {
                return TimeInterval(minutes * 60)
            }
        } else if lowercased.contains("hour") {
            let numbers = lowercased.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Double($0) }
            if let hours = numbers.first {
                return TimeInterval(hours * 3600)
            }
        } else if lowercased.contains("day") {
            let numbers = lowercased.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            if let days = numbers.first {
                return TimeInterval(days * 86400) // 24 hours
            }
        }
        
        return nil
    }
}