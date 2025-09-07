//
//  TemplateExporter.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import Foundation

class TemplateExporter: ObservableObject {
    
    // Type aliases for backward compatibility
    typealias ExportError = TemplateExportError
    typealias ExportOptions = TemplateExportOptions
    typealias ExportFormat = TemplateExportFormat
    
    @Published var isExporting = false
    @Published var lastExportResult: URL?
    @Published var lastExportError: TemplateExportError?
    
    // MARK: - Public Methods
    
    func exportProject(_ project: Project, 
                      phases: [Phase] = [],
                      taskLists: [String: [TaskList]] = [:],
                      tasks: [String: [ShigodekiTask]] = [:],
                      subtasks: [String: [Subtask]] = [:],
                      options: TemplateExportOptions = .default) async throws -> ProjectTemplate {
        
        await MainActor.run {
            isExporting = true
            lastExportError = nil
        }
        
        defer {
            Task { @MainActor in
                isExporting = false
            }
        }
        
        // フェーズの検証
        guard !phases.isEmpty else {
            let error = TemplateExportError.noPhases
            await MainActor.run {
                lastExportError = error
            }
            throw error
        }
        
        // テンプレート変換
        let template = try ProjectTemplateConverter.convertToTemplate(
            project: project,
            phases: phases,
            taskLists: taskLists,
            tasks: tasks,
            subtasks: subtasks,
            options: options
        )
        
        return template
    }
    
    func exportToJSON(_ project: Project,
                     phases: [Phase] = [],
                     taskLists: [String: [TaskList]] = [:],
                     tasks: [String: [ShigodekiTask]] = [:],
                     subtasks: [String: [Subtask]] = [:],
                     options: TemplateExportOptions = .default) async throws -> Data {
        
        let template = try await exportProject(
            project,
            phases: phases,
            taskLists: taskLists,
            tasks: tasks,
            subtasks: subtasks,
            options: options
        )
        
        return try TemplateContentEncoder.encodeTemplate(template, format: options.exportFormat)
    }
    
    func exportToFile(_ project: Project,
                     phases: [Phase] = [],
                     taskLists: [String: [TaskList]] = [:],
                     tasks: [String: [ShigodekiTask]] = [:],
                     subtasks: [String: [Subtask]] = [:],
                     options: TemplateExportOptions = .default,
                     to url: URL) async throws {
        
        let jsonData = try await exportToJSON(
            project,
            phases: phases,
            taskLists: taskLists,
            tasks: tasks,
            subtasks: subtasks,
            options: options
        )
        
        do {
            try jsonData.write(to: url)
            await MainActor.run {
                lastExportResult = url
            }
        } catch {
            let exportError = TemplateExportError.fileWriteFailed(url.path)
            await MainActor.run {
                lastExportError = exportError
            }
            throw exportError
        }
    }
    
    // MARK: - Implementation delegated to separate services
}

// MARK: - Preview Support

extension TemplateExporter {
    static func previewExporter() -> TemplateExporter {
        let exporter = TemplateExporter()
        return exporter
    }
}