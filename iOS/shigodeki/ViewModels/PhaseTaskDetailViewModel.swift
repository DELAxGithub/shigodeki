//
//  PhaseTaskDetailViewModel.swift
//  shigodeki
//
//  Operation: Decoupling - Clean ViewModel Architecture
//  Created by Claude on 2025-09-02.
//

import Foundation
import Combine

@MainActor
class PhaseTaskDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties (UI State)
    
    @Published private(set) var hasChanges: Bool = false
    @Published private(set) var shouldEnableSaveButton: Bool = false
    @Published private(set) var isLoading: Bool = false
    
    // Computed property for save button state
    var canSave: Bool {
        return shouldEnableSaveButton && !isLoading
    }
    
    // MARK: - Current Values (Editable)
    
    @Published var isCompleted: Bool {
        didSet { evaluateChanges() }
    }
    
    @Published var priority: TaskPriority {
        didSet { evaluateChanges() }
    }
    
    @Published var title: String {
        didSet { evaluateChanges() }
    }
    
    @Published var taskDescription: String {
        didSet { evaluateChanges() }
    }
    
    // MARK: - Original Values (Immutable Reference)
    
    private let originalTask: ShigodekiTask
    private let originalIsCompleted: Bool
    private let originalPriority: TaskPriority
    private let originalTitle: String
    private let originalDescription: String
    
    // MARK: - Dependencies
    
    private let project: Project
    private let phase: Phase
    private let taskManager: EnhancedTaskManager
    
    // MARK: - Initialization
    
    init(task: ShigodekiTask, project: Project, phase: Phase, taskManager: EnhancedTaskManager? = nil) {
        // Store original values for comparison
        self.originalTask = task
        self.originalIsCompleted = task.isCompleted
        self.originalPriority = task.priority
        self.originalTitle = task.title
        self.originalDescription = task.description ?? ""
        
        // Initialize current editable values
        self.isCompleted = task.isCompleted
        self.priority = task.priority
        self.title = task.title
        self.taskDescription = task.description ?? ""
        
        // Store dependencies
        self.project = project
        self.phase = phase
        self.taskManager = taskManager ?? EnhancedTaskManager()
        
        // Initial state evaluation
        evaluateChanges()
    }
    
    // MARK: - Public Methods (Test-Friendly)
    
    func setCompleted(_ completed: Bool) {
        isCompleted = completed
    }
    
    func setPriority(_ newPriority: TaskPriority) {
        priority = newPriority
    }
    
    func setTitle(_ newTitle: String) {
        title = newTitle
    }
    
    func setDescription(_ newDescription: String) {
        taskDescription = newDescription
    }
    
    // MARK: - State Evaluation (Core Logic)
    
    private func evaluateChanges() {
        let hasCompletionChanged = isCompleted != originalIsCompleted
        let hasPriorityChanged = priority != originalPriority
        let hasTitleChanged = title != originalTitle
        let hasDescriptionChanged = taskDescription != originalDescription
        
        hasChanges = hasCompletionChanged || hasPriorityChanged || hasTitleChanged || hasDescriptionChanged
        shouldEnableSaveButton = hasChanges
    }
    
    // MARK: - Save Logic
    
    func save() async throws {
        guard hasChanges else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Create updated task
        var updatedTask = originalTask
        updatedTask.isCompleted = isCompleted
        updatedTask.priority = priority
        updatedTask.title = title
        updatedTask.description = taskDescription.isEmpty ? nil : taskDescription
        
        // Issue #63 Fix: Update completedAt timestamp when completion status changes
        if isCompleted != originalIsCompleted {
            updatedTask.completedAt = isCompleted ? Date() : nil
        }
        
        // Save to repository
        _ = try await taskManager.updatePhaseTask(updatedTask)
        
        // Reset change tracking - task is now saved
        resetToSavedState(updatedTask)
    }
    
    // MARK: - State Management
    
    private func resetToSavedState(_ savedTask: ShigodekiTask) {
        // Update original values to match saved state
        // This is a private method that would be called after successful save
        // For now, we'll reset hasChanges to false
        hasChanges = false
        shouldEnableSaveButton = false
    }
    
    func discardChanges() {
        isCompleted = originalIsCompleted
        priority = originalPriority
        title = originalTitle
        taskDescription = originalDescription
        evaluateChanges() // Should result in hasChanges = false
    }
}

// MARK: - Computed Properties for UI

extension PhaseTaskDetailViewModel {
    var canSave: Bool {
        return shouldEnableSaveButton && !isLoading
    }
}