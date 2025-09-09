//
//  SharedManagerStore.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import Foundation
import SwiftUI
import Combine

/// 中央集中化されたManager管理システム  
/// Phase 1で特定された「36個の@StateObject重複作成」問題を解決
/// 非同期関数でデッドロック問題を根本解決
@MainActor
class SharedManagerStore: ObservableObject {
    
    // MARK: - Singleton Pattern
    
    static let shared = SharedManagerStore()
    
    // MARK: - Shared Manager Instances
    
    @Published private var _authManager: AuthenticationManager?
    @Published private var _projectManager: ProjectManager?
    @Published private var _taskManager: EnhancedTaskManager?
    @Published private var _phaseManager: PhaseManager?
    @Published private var _subtaskManager: SubtaskManager?
    @Published private var _familyManager: FamilyManager?
    @Published private var _taskListManager: TaskListManager?
    @Published private var _aiGenerator: AITaskGenerator?
    @Published private var _taskImprovementEngine: TaskImprovementEngine?
    
    // MARK: - Preload Management
    
    @Published var isPreloaded: Bool = false
    private var preloadTask: Task<Void, Never>?
    
    private init() {
        MemoryManagementService.setupMemoryWarningHandling { [weak self] in
            await self?.cleanupUnusedManagers()
        }
    }
    
    // MARK: - Synchronous Cached Accessors (read-only)
    // Provide immediate access to already-created managers to reduce UI flicker on view remounts.
    var phaseManagerIfLoaded: PhaseManager? { _phaseManager }
    var authManagerIfLoaded: AuthenticationManager? { _authManager }
    var aiGeneratorIfLoaded: AITaskGenerator? { _aiGenerator }
    var familyManagerIfLoaded: FamilyManager? { _familyManager }
    
    // MARK: - Manager Access Methods
    
    func getAuthManager() async -> AuthenticationManager {
        return await ManagerCreationService.createManagerSafely(
            key: "AuthManager",
            existing: _authManager,
            create: { AuthenticationManager.shared },
            assign: { self._authManager = $0 },
            logContext: "AuthManager Created"
        )
    }
    
    func getProjectManager() async -> ProjectManager {
        return await ManagerCreationService.createManagerSafely(
            key: "ProjectManager",
            existing: _projectManager,
            create: { ProjectManager() },
            assign: { self._projectManager = $0 },
            logContext: "ProjectManager Created"
        )
    }
    
    func getTaskManager() async -> EnhancedTaskManager {
        return await ManagerCreationService.createManagerSafely(
            key: "EnhancedTaskManager",
            existing: _taskManager,
            create: { EnhancedTaskManager() },
            assign: { self._taskManager = $0 },
            logContext: "TaskManager Created"
        )
    }
    
    func getPhaseManager() async -> PhaseManager {
        return await ManagerCreationService.createManagerSafely(
            key: "PhaseManager",
            existing: _phaseManager,
            create: { PhaseManager() },
            assign: { self._phaseManager = $0 },
            logContext: "PhaseManager Created"
        )
    }
    
    func getSubtaskManager() async -> SubtaskManager {
        return await ManagerCreationService.createManagerSafely(
            key: "SubtaskManager",
            existing: _subtaskManager,
            create: { SubtaskManager() },
            assign: { self._subtaskManager = $0 },
            logContext: "SubtaskManager Created"
        )
    }
    
    func getFamilyManager() async -> FamilyManager {
        return await ManagerCreationService.createManagerSafely(
            key: "FamilyManager",
            existing: _familyManager,
            create: { FamilyManager() },
            assign: { self._familyManager = $0 },
            logContext: "FamilyManager Created"
        )
    }
    
    func getTaskListManager() async -> TaskListManager {
        return await ManagerCreationService.createManagerSafely(
            key: "TaskListManager",
            existing: _taskListManager,
            create: { TaskListManager() },
            assign: { self._taskListManager = $0 },
            logContext: "TaskListManager Created"
        )
    }
    
    func getAiGenerator() async -> AITaskGenerator {
        return await ManagerCreationService.createManagerSafely(
            key: "AITaskGenerator",
            existing: _aiGenerator,
            create: { AITaskGenerator() },
            assign: { self._aiGenerator = $0 },
            logContext: "AIGenerator Created"
        )
    }
    
    func getTaskImprovementEngine() async -> TaskImprovementEngine {
        return await ManagerCreationService.createManagerSafely(
            key: "TaskImprovementEngine",
            existing: _taskImprovementEngine,
            create: { 
                TaskImprovementEngine(
                    aiGenerator: AITaskGenerator(),
                    taskManager: TaskManager(),
                    familyManager: FamilyManager()
                )
            },
            assign: { self._taskImprovementEngine = $0 },
            logContext: "TaskImprovementEngine Created"
        )
    }
    
    // MARK: - Preload Management
    
    /// Single-flight preload to prevent deadlock - prevents concurrent preload calls
    func preload() async {
        // If preload is already in progress, wait for it to complete
        if let existingTask = preloadTask {
            await existingTask.value
            return
        }
        
        // If already preloaded, return immediately
        if isPreloaded {
            #if DEBUG
            print("✅ SharedManagerStore: Already preloaded, skipping")
            #endif
            return
        }
        
        // Start single preload task
        preloadTask = Task { [weak self] in
            guard let self = self else { return }
            await ManagerCreationService.preloadEssentialManagers(sharedStore: self)
            await MainActor.run { [weak self] in
                self?.isPreloaded = true
                self?.preloadTask = nil
            }
        }
        
        await preloadTask?.value
    }
    
    func preloadAllManagers() async {
        if let existingTask = preloadTask {
            await existingTask.value
            return
        }
        
        if isPreloaded {
            #if DEBUG
            print("✅ SharedManagerStore: Already preloaded, skipping")
            #endif
            return
        }
        
        preloadTask = Task {
            await ManagerCreationService.preloadEssentialManagers(sharedStore: self)
            await MainActor.run {
                isPreloaded = true
            }
        }
        
        await preloadTask?.value
        preloadTask = nil
    }
    
    // MARK: - Memory Management
    
    func getCurrentMemoryUsage() -> Double {
        return MemoryManagementService.getCurrentMemoryUsage()
    }
    
    func smartCacheManagement() async {
        let memoryUsage = getCurrentMemoryUsage()
        MemoryManagementService.performSmartCacheManagement(
            currentMemoryUsage: memoryUsage,
            aiGeneratorRef: &_aiGenerator,
            taskImprovementEngineRef: &_taskImprovementEngine
        )
    }
    
    func cleanupUnusedManagers() async {
        await MemoryManagementService.cleanupManagerListeners(
            projectManager: _projectManager,
            taskManager: _taskManager,
            phaseManager: _phaseManager,
            subtaskManager: _subtaskManager,
            taskListManager: _taskListManager
        )
    }
    
    func removeAllListeners() async {
        await MemoryManagementService.cleanupManagerListeners(
            projectManager: _projectManager,
            taskManager: _taskManager,
            phaseManager: _phaseManager,
            subtaskManager: _subtaskManager,
            taskListManager: _taskListManager
        )
        
        await MainActor.run { 
            FirebaseListenerManager.shared.logDebugInfo() 
        }
    }
    
    // MARK: - Debug and Monitoring
    
    func getManagerStatistics() -> ManagerStatistics {
        return ManagerStatisticsService.generateStatistics(
            authManager: _authManager,
            projectManager: _projectManager,
            taskManager: _taskManager,
            phaseManager: _phaseManager,
            subtaskManager: _subtaskManager,
            familyManager: _familyManager,
            taskListManager: _taskListManager,
            aiGenerator: _aiGenerator,
            taskImprovementEngine: _taskImprovementEngine
        )
    }
    
    func generateDebugReport() -> String {
        let stats = getManagerStatistics()
        return ManagerStatisticsService.generateDebugReport(stats: stats)
    }
    
    func logDebugInfo() {
        let stats = getManagerStatistics()
        ManagerStatisticsService.logDebugInfo(stats: stats)
    }
}

// MARK: - SwiftUI Environment Integration

struct SharedManagerStoreEnvironmentKey: EnvironmentKey {
    @MainActor static var defaultValue: SharedManagerStore { SharedManagerStore.shared }
}

extension EnvironmentValues {
    var sharedManagerStore: SharedManagerStore {
        get { self[SharedManagerStoreEnvironmentKey.self] }
        set { self[SharedManagerStoreEnvironmentKey.self] = newValue }
    }
}

extension View {
    func withSharedManagers() -> some View {
        self.environmentObject(SharedManagerStore.shared)
    }
}
