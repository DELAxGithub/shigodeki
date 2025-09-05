# Export Functionality Architecture Design

## Design Overview
**Issue**: #13 - プロジェクトエクスポート機能の完全実装
**Priority**: High
**Context**: Complete hierarchical data export with integrity verification

## Current State Analysis

### Existing Implementation
- ✅ Project export structure exists
- ✅ Phase and TaskList loading implemented
- ❌ **Critical Gap**: Task loading for export (line 571)
- ❌ **Missing**: Data integrity verification
- ❌ **Missing**: Multiple export formats

### Current Architecture Issue
```swift
// ProjectManager.swift:571
let listTasks: [ShigodekiTask] = [] // TODO: Implement proper task loading for export
```

## Complete Export System Architecture

### Component Hierarchy
```
ProjectExportManager (Main Controller)
├── DataCollectionEngine (Hierarchical Data Loading)
├── DataIntegrityVerifier (Validation & Consistency)
├── ExportFormatters (JSON, CSV, PDF, etc.)
├── ProgressTracker (User Feedback)
└── ExportResultHandler (File Management)
```

### Data Flow Architecture
```
[Project Selection] → [Data Collection] → [Integrity Check] → [Format Selection] → [Export Generation] → [File Sharing]
                              ↓                    ↓                    ↓
                    [Progress Updates]    [Validation Results]    [User Feedback]
```

## Detailed Component Design

### 1. ProjectExportManager
**Purpose**: Orchestrate the complete export workflow
**Location**: `iOS/shigodeki/ProjectExportManager.swift` (new file)

```swift
@MainActor
final class ProjectExportManager: ObservableObject {
    // MARK: - Published Properties
    @Published var exportState: ExportState = .idle
    @Published var exportProgress: Double = 0.0
    @Published var exportError: ExportError?
    @Published var exportResult: ExportResult?
    
    // MARK: - Dependencies
    private let projectManager: ProjectManager
    private let taskManager: TaskManager
    private let taskListManager: TaskListManager
    private let subtaskManager: SubtaskManager
    
    // MARK: - Export Workflow
    func exportProject(_ project: Project, format: ExportFormat) async throws -> ExportResult {
        exportState = .collecting
        exportProgress = 0.0
        
        do {
            // Phase 1: Collect hierarchical data (0-60%)
            let projectData = try await collectCompleteProjectData(project)
            exportProgress = 0.6
            
            // Phase 2: Verify data integrity (60-80%)
            let verificationResult = try await verifyDataIntegrity(projectData)
            exportProgress = 0.8
            
            // Phase 3: Generate export (80-100%)
            let exportResult = try await generateExport(projectData, format: format, verification: verificationResult)
            exportProgress = 1.0
            
            exportState = .completed
            self.exportResult = exportResult
            return exportResult
            
        } catch {
            exportState = .failed
            exportError = ExportError.from(error)
            throw error
        }
    }
}

enum ExportState {
    case idle
    case collecting
    case verifying
    case formatting
    case completed
    case failed
}

enum ExportFormat {
    case json
    case csv
    case pdf
    case excel
}
```

### 2. DataCollectionEngine
**Purpose**: Complete hierarchical data loading with integrity
**Enhancement**: Fix the missing task loading issue

```swift
struct DataCollectionEngine {
    private let projectManager: ProjectManager
    private let taskManager: TaskManager
    private let taskListManager: TaskListManager
    private let subtaskManager: SubtaskManager
    
    func collectCompleteProjectData(_ project: Project) async throws -> CompleteProjectData {
        var phases: [String: Phase] = [:]
        var taskLists: [String: [TaskList]] = [:]
        var tasks: [String: [ShigodekiTask]] = [:]
        var subtasks: [String: [Subtask]] = [:]
        
        // 1. Load all phases
        let projectPhases = try await projectManager.getPhases(projectId: project.id)
        for phase in projectPhases {
            phases[phase.id] = phase
            
            // 2. Load task lists for each phase
            let phaseLists = try await taskListManager.getTaskLists(
                phaseId: phase.id, 
                projectId: project.id
            )
            taskLists[phase.id] = phaseLists
            
            // 3. Load tasks for each task list (FIX THE MISSING IMPLEMENTATION)
            for taskList in phaseLists {
                guard let taskListId = taskList.id else { continue }
                
                // FIXED: Proper task loading implementation
                let listTasks = try await taskManager.getTasks(
                    taskListId: taskListId,
                    phaseId: phase.id,
                    projectId: project.id
                )
                tasks[taskListId] = listTasks
                
                // 4. Load subtasks for each task
                for task in listTasks {
                    guard let taskId = task.id else { continue }
                    let taskSubtasks = try await subtaskManager.getSubtasks(
                        taskId: taskId,
                        listId: taskListId,
                        phaseId: phase.id,
                        projectId: project.id
                    )
                    subtasks[taskId] = taskSubtasks
                }
            }
        }
        
        return CompleteProjectData(
            project: project,
            phases: phases,
            taskLists: taskLists,
            tasks: tasks,
            subtasks: subtasks,
            metadata: ExportMetadata(
                exportedAt: Date(),
                exportedBy: getCurrentUserId(),
                version: "1.0",
                totalPhases: phases.count,
                totalTaskLists: taskLists.values.flatMap { $0 }.count,
                totalTasks: tasks.values.flatMap { $0 }.count,
                totalSubtasks: subtasks.values.flatMap { $0 }.count
            )
        )
    }
}
```

### 3. Data Models for Export

```swift
struct CompleteProjectData {
    let project: Project
    let phases: [String: Phase]
    let taskLists: [String: [TaskList]]
    let tasks: [String: [ShigodekiTask]]
    let subtasks: [String: [Subtask]]
    let metadata: ExportMetadata
}

struct ExportMetadata {
    let exportedAt: Date
    let exportedBy: String
    let version: String
    let totalPhases: Int
    let totalTaskLists: Int
    let totalTasks: Int
    let totalSubtasks: Int
    
    // Data integrity checksums
    let dataChecksum: String
    let hierarchyValid: Bool
}

struct ExportResult {
    let fileURL: URL
    let format: ExportFormat
    let fileSize: Int64
    let itemCount: ExportItemCount
    let verificationResult: DataIntegrityResult
    let exportDuration: TimeInterval
}

struct ExportItemCount {
    let phases: Int
    let taskLists: Int
    let tasks: Int
    let subtasks: Int
    
    var total: Int {
        phases + taskLists + tasks + subtasks
    }
}
```

### 4. DataIntegrityVerifier
**Purpose**: Ensure export data consistency and completeness

```swift
struct DataIntegrityVerifier {
    func verifyDataIntegrity(_ data: CompleteProjectData) async throws -> DataIntegrityResult {
        var issues: [IntegrityIssue] = []
        
        // 1. Verify hierarchy relationships
        issues.append(contentsOf: verifyHierarchyIntegrity(data))
        
        // 2. Verify data completeness
        issues.append(contentsOf: verifyDataCompleteness(data))
        
        // 3. Verify referential integrity
        issues.append(contentsOf: verifyReferentialIntegrity(data))
        
        // 4. Verify business rules
        issues.append(contentsOf: verifyBusinessRules(data))
        
        let severity = determineSeverity(issues)
        
        return DataIntegrityResult(
            isValid: severity != .critical,
            issues: issues,
            severity: severity,
            verifiedAt: Date()
        )
    }
    
    private func verifyHierarchyIntegrity(_ data: CompleteProjectData) -> [IntegrityIssue] {
        var issues: [IntegrityIssue] = []
        
        // Check project → phase relationships
        for (phaseId, phase) in data.phases {
            if phase.projectId != data.project.id {
                issues.append(.hierarchyMismatch(
                    "Phase \(phase.name) belongs to different project"
                ))
            }
        }
        
        // Check phase → taskList relationships
        for (phaseId, taskLists) in data.taskLists {
            for taskList in taskLists {
                if taskList.phaseId != phaseId {
                    issues.append(.hierarchyMismatch(
                        "TaskList \(taskList.name) belongs to different phase"
                    ))
                }
            }
        }
        
        // Check taskList → task relationships
        for (taskListId, tasks) in data.tasks {
            for task in tasks {
                if task.listId != taskListId {
                    issues.append(.hierarchyMismatch(
                        "Task \(task.title) belongs to different task list"
                    ))
                }
            }
        }
        
        return issues
    }
}

struct DataIntegrityResult {
    let isValid: Bool
    let issues: [IntegrityIssue]
    let severity: IntegritySeverity
    let verifiedAt: Date
}

enum IntegrityIssue {
    case hierarchyMismatch(String)
    case missingData(String)
    case invalidReference(String)
    case businessRuleViolation(String)
}

enum IntegritySeverity {
    case none, warning, error, critical
}
```

### 5. ExportFormatters
**Purpose**: Generate exports in multiple formats

```swift
protocol ExportFormatter {
    func format(_ data: CompleteProjectData) async throws -> Data
    var fileExtension: String { get }
    var mimeType: String { get }
}

// JSON Formatter (Primary)
struct JSONExportFormatter: ExportFormatter {
    let fileExtension = "json"
    let mimeType = "application/json"
    
    func format(_ data: CompleteProjectData) async throws -> Data {
        let exportDocument = JSONExportDocument(
            project: data.project,
            phases: Array(data.phases.values).sorted { $0.order < $1.order },
            structure: buildHierarchicalStructure(data),
            metadata: data.metadata
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try encoder.encode(exportDocument)
    }
}

// CSV Formatter (Flat structure)
struct CSVExportFormatter: ExportFormatter {
    let fileExtension = "csv"
    let mimeType = "text/csv"
    
    func format(_ data: CompleteProjectData) async throws -> Data {
        var csvContent = "Phase,TaskList,Task,Subtask,Status,Priority,DueDate,Assignee\n"
        
        for phase in data.phases.values.sorted(by: { $0.order < $1.order }) {
            let taskLists = data.taskLists[phase.id] ?? []
            
            for taskList in taskLists.sorted(by: { $0.order < $1.order }) {
                let tasks = data.tasks[taskList.id ?? ""] ?? []
                
                for task in tasks.sorted(by: { $0.order < $1.order }) {
                    let subtasks = data.subtasks[task.id ?? ""] ?? []
                    
                    if subtasks.isEmpty {
                        csvContent += formatCSVRow(
                            phase: phase.name,
                            taskList: taskList.name,
                            task: task.title,
                            subtask: "",
                            task: task
                        )
                    } else {
                        for subtask in subtasks {
                            csvContent += formatCSVRow(
                                phase: phase.name,
                                taskList: taskList.name,
                                task: task.title,
                                subtask: subtask.title,
                                task: task
                            )
                        }
                    }
                }
            }
        }
        
        return csvContent.data(using: .utf8) ?? Data()
    }
}
```

### 6. Fixed ProjectManager Integration

```swift
// FIXED implementation for ProjectManager.swift:571
extension ProjectManager {
    func exportProjectWithCompleteData(_ project: Project) async throws -> CompleteProjectData {
        let exportManager = ProjectExportManager(
            projectManager: self,
            taskManager: taskManager,
            taskListManager: taskListManager,
            subtaskManager: subtaskManager
        )
        
        let dataEngine = DataCollectionEngine(
            projectManager: self,
            taskManager: taskManager,
            taskListManager: taskListManager,
            subtaskManager: subtaskManager
        )
        
        return try await dataEngine.collectCompleteProjectData(project)
    }
}
```

## UI/UX Design for Export

### Export Options View
```swift
struct ProjectExportView: View {
    let project: Project
    @StateObject private var exportManager = ProjectExportManager()
    @State private var selectedFormat: ExportFormat = .json
    @State private var showingExportResult = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                projectSummarySection
                formatSelectionSection
                exportOptionsSection
                
                if exportManager.exportState == .idle {
                    exportButton
                } else {
                    exportProgressSection
                }
            }
            .navigationTitle("プロジェクトをエクスポート")
        }
    }
    
    private func startExport() {
        Task {
            do {
                let result = try await exportManager.exportProject(project, format: selectedFormat)
                showingExportResult = true
            } catch {
                // Handle error
            }
        }
    }
}
```

### Progress Tracking UI
```swift
private var exportProgressSection: some View {
    VStack(spacing: 12) {
        ProgressView(value: exportManager.exportProgress)
            .progressViewStyle(LinearProgressViewStyle())
        
        Text(exportManager.exportState.displayMessage)
            .font(.subheadline)
            .foregroundColor(.secondary)
        
        if exportManager.exportProgress > 0 {
            Text("\(Int(exportManager.exportProgress * 100))% 完了")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

## Implementation Strategy

### Phase 1: Core Data Collection (2 days)
1. Implement `DataCollectionEngine` with complete task loading
2. Fix `ProjectManager.swift:571` TODO
3. Add comprehensive error handling

### Phase 2: Data Integrity (1 day)
1. Build `DataIntegrityVerifier`
2. Add validation rules and checks
3. Implement integrity reporting

### Phase 3: Export Formats (1 day)
1. Implement JSON formatter (primary)
2. Add CSV formatter for flat exports
3. Create export result handling

### Phase 4: UI Integration (1 day)
1. Build export options UI
2. Add progress tracking
3. Implement file sharing capabilities

## Success Metrics

### Technical Success
- Complete data export success rate > 99%
- Data integrity verification accuracy > 95%
- Export generation time < 30 seconds for typical projects

### Data Quality Success
- Zero data loss in exports
- All hierarchy relationships preserved
- Referential integrity maintained > 99%

## Risk Mitigation

### Data Integrity Risks
- Comprehensive validation at multiple levels
- Atomic data collection operations
- Rollback capabilities for failed exports

### Performance Risks
- Progress tracking for user feedback
- Background processing for large exports
- Memory-efficient data handling

### User Experience Risks
- Clear error messages with recovery options
- Export preview before generation
- Multiple format options for different use cases