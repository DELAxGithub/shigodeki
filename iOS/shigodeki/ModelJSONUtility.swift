//
//  ModelJSONUtility.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation

class ModelJSONUtility {
    static let shared = ModelJSONUtility()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        setupEncoderDecoder()
    }
    
    private func setupEncoderDecoder() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Project JSON Operations
    
    func exportProject(_ project: Project) throws -> Data {
        return try encoder.encode(project)
    }
    
    func importProject(from data: Data) throws -> Project {
        return try decoder.decode(Project.self, from: data)
    }
    
    // MARK: - Task JSON Operations
    
    func exportTasks(_ tasks: [ShigodekiTask]) throws -> Data {
        return try encoder.encode(tasks)
    }
    
    func importTasks(from data: Data) throws -> [ShigodekiTask] {
        return try decoder.decode([ShigodekiTask].self, from: data)
    }
    
    // MARK: - Batch Export/Import
    
    struct ProjectExport: Codable {
        let project: Project
        let phases: [Phase]
        let taskLists: [TaskList]
        let tasks: [ShigodekiTask]
        let subtasks: [Subtask]
        let exportDate: Date
    }
    
    func exportFullProject(project: Project, phases: [Phase], taskLists: [TaskList], 
                          tasks: [ShigodekiTask], subtasks: [Subtask]) throws -> Data {
        let projectExport = ProjectExport(
            project: project,
            phases: phases,
            taskLists: taskLists,
            tasks: tasks,
            subtasks: subtasks,
            exportDate: Date()
        )
        return try encoder.encode(projectExport)
    }
    
    func importFullProject(from data: Data) throws -> ProjectExport {
        return try decoder.decode(ProjectExport.self, from: data)
    }
}