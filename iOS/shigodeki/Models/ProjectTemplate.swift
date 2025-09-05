//
//  ProjectTemplate.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import Foundation
import SwiftUI

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
    let priority: TaskPriority
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

enum TemplateCategory: String, CaseIterable, Codable, Hashable {
    case softwareDevelopment = "software_development"
    case projectManagement = "project_management"
    case eventPlanning = "event_planning"
    case lifeEvents = "life_events"
    case business = "business"
    case education = "education"
    case creative = "creative"
    case personal = "personal"
    case health = "health"
    case travel = "travel"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .softwareDevelopment: return "ソフトウェア開発"
        case .projectManagement: return "プロジェクト管理"
        case .eventPlanning: return "イベント企画"
        case .lifeEvents: return "ライフイベント"
        case .business: return "ビジネス"
        case .education: return "教育・学習"
        case .creative: return "クリエイティブ"
        case .personal: return "個人"
        case .health: return "健康・フィットネス"
        case .travel: return "旅行"
        case .other: return "その他"
        }
    }
    
    var icon: String {
        switch self {
        case .softwareDevelopment: return "laptopcomputer"
        case .projectManagement: return "chart.bar.xaxis"
        case .eventPlanning: return "calendar.badge.plus"
        case .lifeEvents: return "house"
        case .business: return "briefcase"
        case .education: return "book"
        case .creative: return "paintbrush"
        case .personal: return "person"
        case .health: return "heart"
        case .travel: return "airplane"
        case .other: return "folder"
        }
    }
    
    var color: Color {
        switch self {
        case .softwareDevelopment: return .blue
        case .projectManagement: return .orange
        case .eventPlanning: return .green
        case .lifeEvents: return .purple
        case .business: return .red
        case .education: return .yellow
        case .creative: return .pink
        case .personal: return .gray
        case .health: return .mint
        case .travel: return .cyan
        case .other: return .secondary
        }
    }
}

enum TemplateDifficulty: String, CaseIterable, Codable, Hashable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .beginner: return "初級"
        case .intermediate: return "中級"
        case .advanced: return "上級"
        case .expert: return "エキスパート"
        }
    }
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .expert: return .red
        }
    }
    
    var stars: Int {
        switch self {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        case .expert: return 4
        }
    }
}

// MARK: - Legacy JSON Support (for "steps" format like tsurutsu-template.json)

struct LegacyJSONTemplate: Codable {
    let name: String
    let description: String?
    let goal: String?
    let category: String?
    let version: String?
    let steps: [LegacyStep]
    let metadata: LegacyMetadata?
    
    struct LegacyStep: Codable {
        let title: String
        let description: String?
        let order: Int
        let prerequisites: [String]?
        let templateReference: String?
        let estimatedDuration: String?
        let tasks: [LegacyTask]
    }
    
    struct LegacyTask: Codable {
        let title: String
        let description: String?
        let priority: String?
        let estimatedDuration: String?
        let deadline: String?
        let tags: [String]?
        let templateLinks: [String]?
        let isOptional: Bool?
    }
    
    struct LegacyMetadata: Codable {
        let author: String?
        let createdAt: String?
        let estimatedDuration: String?
        let difficulty: String?
        let tags: [String]?
    }
}

// MARK: - Template Statistics

struct TemplateStats: Codable, Hashable {
    let totalPhases: Int
    let totalTaskLists: Int
    let totalTasks: Int
    let totalSubtasks: Int
    let estimatedCompletionHours: Double
    let optionalTaskCount: Int
    let averagePhaseComplexity: Double
    
    init(template: ProjectTemplate) {
        self.totalPhases = template.phases.count
        self.totalTaskLists = template.phases.reduce(0) { $0 + $1.taskLists.count }
        self.totalTasks = template.phases.reduce(0) { phaseSum, phase in
            phaseSum + phase.taskLists.reduce(0) { taskListSum, taskList in
                taskListSum + taskList.tasks.count
            }
        }
        self.totalSubtasks = template.phases.reduce(0) { phaseSum, phase in
            phaseSum + phase.taskLists.reduce(0) { taskListSum, taskList in
                taskListSum + taskList.tasks.reduce(0) { taskSum, task in
                    taskSum + task.subtasks.count
                }
            }
        }
        self.estimatedCompletionHours = template.phases.reduce(0.0) { phaseSum, phase in
            phaseSum + phase.taskLists.reduce(0.0) { taskListSum, taskList in
                taskListSum + taskList.tasks.reduce(0.0) { taskSum, task in
                    taskSum + (task.estimatedHours ?? 1.0)
                }
            }
        }
        self.optionalTaskCount = template.phases.reduce(0) { phaseSum, phase in
            phaseSum + phase.taskLists.reduce(0) { taskListSum, taskList in
                taskListSum + taskList.tasks.filter { $0.isOptional }.count
            }
        }
        self.averagePhaseComplexity = totalTasks > 0 ? Double(totalTasks) / Double(totalPhases) : 0.0
    }
    
    var completionTimeRange: String {
        let days = Int(estimatedCompletionHours / 8) // 1日8時間想定
        switch days {
        case 0: return "数時間"
        case 1: return "1日"
        case 2...7: return "\(days)日"
        case 8...30: return "\(days/7)週間"
        case 31...365: return "\(days/30)ヶ月"
        default: return "\(days/365)年"
        }
    }
    
    var complexityLevel: TemplateDifficulty {
        switch averagePhaseComplexity {
        case 0..<5: return .beginner
        case 5..<15: return .intermediate
        case 15..<30: return .advanced
        default: return .expert
        }
    }
}