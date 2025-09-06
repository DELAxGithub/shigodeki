//
//  ProjectTemplate.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - Core template models
//  Category/difficulty enums extracted to TemplateCategoryExtensions.swift
//  Legacy support extracted to TemplateLegacySupport.swift
//  Statistics extracted to TemplateStatisticsService.swift
//

import Foundation

struct ProjectTemplate: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let description: String?
    let goal: String?
    let category: TemplateCategory
    let version: String
    let phases: [PhaseTemplate]
    let metadata: TemplateMetadata
    
    init(name: String, description: String? = nil, goal: String? = nil, 
         category: TemplateCategory, version: String = "1.0", 
         phases: [PhaseTemplate], metadata: TemplateMetadata) {
        self.name = name
        self.description = description
        self.goal = goal
        self.category = category
        self.version = version
        self.phases = phases
        self.metadata = metadata
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(version)
    }
    
    static func == (lhs: ProjectTemplate, rhs: ProjectTemplate) -> Bool {
        lhs.name == rhs.name && lhs.version == rhs.version
    }
    
    static let sampleTemplate = ProjectTemplate(
        name: "Sample Template",
        description: "A sample template for testing",
        category: .business,
        phases: [],
        metadata: TemplateMetadata(
            author: "System",
            estimatedDuration: "1 hour",
            difficulty: .beginner,
            targetAudience: "All users"
        )
    )
}

struct PhaseTemplate: Identifiable, Codable, Hashable {
    var id: String { title }
    let title: String
    let description: String?
    let order: Int
    let prerequisites: [String]
    let templateReference: String?
    let estimatedDuration: String?
    let taskLists: [TaskListTemplate]
    
    init(title: String, description: String? = nil, order: Int, 
         prerequisites: [String] = [], templateReference: String? = nil,
         estimatedDuration: String? = nil, taskLists: [TaskListTemplate] = []) {
        self.title = title
        self.description = description
        self.order = order
        self.prerequisites = prerequisites
        self.templateReference = templateReference
        self.estimatedDuration = estimatedDuration
        self.taskLists = taskLists.isEmpty ? [TaskListTemplate.defaultTaskList] : taskLists
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(order)
    }
    
    static func == (lhs: PhaseTemplate, rhs: PhaseTemplate) -> Bool {
        lhs.title == rhs.title && lhs.order == rhs.order
    }
}

struct TaskListTemplate: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let description: String?
    let color: TaskListColor
    let order: Int
    let tasks: [TaskTemplate]
    
    init(name: String, description: String? = nil, color: TaskListColor = .blue, 
         order: Int = 0, tasks: [TaskTemplate]) {
        self.name = name
        self.description = description
        self.color = color
        self.order = order
        self.tasks = tasks
    }
    
    static let defaultTaskList = TaskListTemplate(
        name: "タスク",
        description: "メインタスク",
        color: .blue,
        order: 0,
        tasks: []
    )
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(order)
    }
    
    static func == (lhs: TaskListTemplate, rhs: TaskListTemplate) -> Bool {
        lhs.name == rhs.name && lhs.order == rhs.order
    }
}

struct TaskTemplate: Identifiable, Codable, Hashable {
    var id: String { title }
    let title: String
    let description: String?
    var priority: TaskPriority
    let estimatedDuration: String?
    let deadline: String?
    let tags: [String]
    let templateLinks: [String]?
    let isOptional: Bool
    let estimatedHours: Double?
    let dependsOn: [String]
    let subtasks: [SubtaskTemplate]
    
    init(title: String, description: String? = nil, priority: TaskPriority = .medium,
         estimatedDuration: String? = nil, deadline: String? = nil, tags: [String] = [],
         templateLinks: [String]? = nil, isOptional: Bool = false, 
         estimatedHours: Double? = nil, dependsOn: [String] = [], 
         subtasks: [SubtaskTemplate] = []) {
        self.title = title
        self.description = description
        self.priority = priority
        self.estimatedDuration = estimatedDuration
        self.deadline = deadline
        self.tags = tags
        self.templateLinks = templateLinks
        self.isOptional = isOptional
        self.estimatedHours = estimatedHours
        self.dependsOn = dependsOn
        self.subtasks = subtasks
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }
    
    static func == (lhs: TaskTemplate, rhs: TaskTemplate) -> Bool {
        lhs.title == rhs.title
    }
}

struct SubtaskTemplate: Identifiable, Codable, Hashable {
    var id: String { title }
    let title: String
    let description: String?
    let estimatedDuration: String?
    let isOptional: Bool
    
    init(title: String, description: String? = nil, 
         estimatedDuration: String? = nil, isOptional: Bool = false) {
        self.title = title
        self.description = description
        self.estimatedDuration = estimatedDuration
        self.isOptional = isOptional
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }
    
    static func == (lhs: SubtaskTemplate, rhs: SubtaskTemplate) -> Bool {
        lhs.title == rhs.title
    }
}

struct TemplateMetadata: Codable, Hashable {
    let author: String
    let createdAt: String
    let estimatedDuration: String?
    let difficulty: TemplateDifficulty
    let tags: [String]
    let language: String
    let requiredSkills: [String]?
    let targetAudience: String?
    
    init(author: String, createdAt: String = ISO8601DateFormatter().string(from: Date()),
         estimatedDuration: String? = nil, difficulty: TemplateDifficulty = .intermediate,
         tags: [String] = [], language: String = "ja", 
         requiredSkills: [String]? = nil, targetAudience: String? = nil) {
        self.author = author
        self.createdAt = createdAt
        self.estimatedDuration = estimatedDuration
        self.difficulty = difficulty
        self.tags = tags
        self.language = language
        self.requiredSkills = requiredSkills
        self.targetAudience = targetAudience
    }
}

// Enums and extensions moved to TemplateCategoryExtensions.swift
// Legacy support moved to TemplateLegacySupport.swift
// Statistics moved to TemplateStatisticsService.swift