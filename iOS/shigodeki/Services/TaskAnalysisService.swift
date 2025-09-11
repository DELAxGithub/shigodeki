import Foundation

struct TaskAnalysisService {
    // MARK: - Public Methods
    
    static func loadUserTasks(
        userId: String, 
        familyManager: FamilyManager
    ) async throws -> [ShigodekiTask] {
        // Load families for user
        await familyManager.loadFamiliesForUser(userId: userId)
        let families = await familyManager.families
        
        var allTasks: [ShigodekiTask] = []
        
        for family in families {
            guard family.id != nil else { continue }
            
            // Load task lists for this family
            // Note: Using placeholder - actual TaskManager API may differ
            let taskLists: [TaskList] = []
            
            for taskList in taskLists {
                guard taskList.id != nil else { continue }
                
                // Load tasks for this task list
                // Note: Using placeholder - actual TaskManager API may differ
                let tasks: [ShigodekiTask] = []
                allTasks.append(contentsOf: tasks)
            }
        }
        
        return allTasks
    }
    
    static func analyzeTaskPatterns(_ tasks: [ShigodekiTask]) async -> TaskPatternAnalysis {
        var analysis = TaskPatternAnalysis()
        
        // Analyze task complexity
        let largeTasks = tasks.filter { $0.subtaskCount > 5 || $0.title.count > 100 }
        analysis.largeTasksNeedingBreakdown = largeTasks
        
        // Analyze priority distribution
        let priorityDistribution = Dictionary(grouping: tasks, by: { $0.priority })
        if let highPriorityCount = priorityDistribution[.high]?.count {
            let totalCount = priorityDistribution.values.flatMap({ $0 }).count
            if highPriorityCount > totalCount / 2 {
                analysis.hasPriorityInflation = true
            }
        }
        
        // Analyze overdue tasks
        let now = Date()
        let overdueTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < now && !task.isCompleted
        }
        analysis.overdueTasks = overdueTasks
        
        // Analyze completion patterns
        let completedTasks = tasks.filter { $0.isCompleted }
        let averageCompletionTime = calculateAverageCompletionTime(completedTasks)
        analysis.averageCompletionTime = averageCompletionTime
        
        // Analyze task dependencies
        // Note: Using placeholder - ShigodekiTask may not have dependentTaskIds property
        analysis.tasksWithoutDependencies = tasks.filter { !$0.isCompleted }
        
        return analysis
    }
    
    // MARK: - Private Methods
    
    private static func calculateAverageCompletionTime(_ tasks: [ShigodekiTask]) -> TimeInterval {
        let completionTimes = tasks.compactMap { task -> TimeInterval? in
            guard let completedAt = task.completedAt,
                  let createdAt = task.createdAt else { return nil }
            return completedAt.timeIntervalSince(createdAt)
        }
        
        return completionTimes.isEmpty ? 0 : completionTimes.reduce(0, +) / Double(completionTimes.count)
    }
}

// MARK: - Supporting Data Structures

struct TaskPatternAnalysis {
    var largeTasksNeedingBreakdown: [ShigodekiTask] = []
    var hasPriorityInflation: Bool = false
    var overdueTasks: [ShigodekiTask] = []
    var averageCompletionTime: TimeInterval = 0
    var tasksWithoutDependencies: [ShigodekiTask] = []
}
