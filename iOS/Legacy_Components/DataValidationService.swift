//
//  DataValidationService.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation

class DataValidationService {
    static let shared = DataValidationService()
    
    private init() {}
    
    // MARK: - Sanitization
    
    func sanitizeString(_ input: String) -> String {
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n\n+", with: "\n\n", options: .regularExpression)
    }
    
    func sanitizeOptionalString(_ input: String?) -> String? {
        guard let input = input else { return nil }
        let sanitized = sanitizeString(input)
        return sanitized.isEmpty ? nil : sanitized
    }
    
    // MARK: - Validation Helpers
    
    func validateEmail(_ email: String) -> Bool {
        let emailRegex = "^[\\w\\.-]+@[\\w\\.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func validateDateRange(_ startDate: Date?, _ endDate: Date?) -> Bool {
        guard let start = startDate, let end = endDate else { return true }
        return start <= end
    }
    
    func validatePositiveNumber<T: Comparable & AdditiveArithmetic>(_ number: T?) -> Bool {
        guard let number = number else { return true }
        return number >= T.zero
    }
    
    // MARK: - Batch Validation
    
    func validateProjectHierarchy(project: Project, phases: [Phase], taskLists: [TaskList], 
                                 tasks: [ShigodekiTask], subtasks: [Subtask]) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Validate project
        do {
            try project.validate()
        } catch let error as ValidationError {
            errors.append(error)
        } catch {}
        
        // Validate hierarchy relationships
        do {
            try ModelRelationships.validateProjectHierarchy(project: project, phases: phases)
            for phase in phases {
                let phaseLists = taskLists.filter { $0.phaseId == phase.id }
                try ModelRelationships.validatePhaseHierarchy(phase: phase, taskLists: phaseLists)
                
                for taskList in phaseLists {
                    let listTasks = tasks.filter { $0.listId == taskList.id }
                    try ModelRelationships.validateTaskListHierarchy(taskList: taskList, tasks: listTasks)
                    
                    for task in listTasks {
                        let taskSubtasks = subtasks.filter { $0.taskId == task.id }
                        try ModelRelationships.validateTaskHierarchy(task: task, subtasks: taskSubtasks)
                    }
                }
            }
        } catch let error as ValidationError {
            errors.append(error)
        } catch {}
        
        return errors
    }
}