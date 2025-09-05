# AI TaskImprovement Component Architecture

## Design Overview
**Issue**: #12 - AI タスク改善提案機能の実装
**Priority**: High
**Component**: TaskImprovementSuggestionView

## System Architecture

### Component Hierarchy
```
TaskImprovementSuggestionView (Main UI)
├── TaskAnalysisEngine (Analysis Logic)
├── AIImprovementClient (AI Integration)
├── ImprovementResultsView (Results Display)
└── ImprovementApplierService (Action Handler)
```

### Data Flow Architecture
```
[User Tasks] → [Analysis Engine] → [AI Client] → [Suggestions] → [UI Display] → [User Selection] → [Task Updates]
```

## Component Specifications

### 1. TaskImprovementSuggestionView
**Purpose**: Main UI component for task improvement workflow
**Location**: `iOS/shigodeki/TaskImprovementSuggestionView.swift`

```swift
struct TaskImprovementSuggestionView: View {
    @StateObject private var improvementEngine = TaskImprovementEngine()
    @EnvironmentObject private var sharedManagers: SharedManagerStore
    
    // UI States
    @State private var analysisPhase: AnalysisPhase = .loading
    @State private var selectedSuggestions: Set<ImprovementSuggestion> = []
    @State private var isApplying = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Analysis Phase UI
                // Results Display
                // Action Buttons
            }
        }
    }
}

enum AnalysisPhase {
    case loading
    case analyzing
    case showingResults
    case applying
    case completed
}
```

### 2. TaskImprovementEngine
**Purpose**: Core business logic for task analysis and improvement
**Responsibilities**:
- Analyze existing user tasks
- Coordinate with AI services
- Manage improvement workflow state

```swift
@MainActor
final class TaskImprovementEngine: ObservableObject {
    @Published var analysisState: AnalysisState = .idle
    @Published var improvements: [ImprovementSuggestion] = []
    @Published var analysisProgress: Double = 0.0
    
    // Dependencies
    private let aiGenerator: AITaskGenerator
    private let taskManager: TaskManager
    private let familyManager: FamilyManager
    
    func analyzeUserTasks() async throws {
        analysisState = .analyzing
        
        // 1. Load user's tasks across all families
        let userTasks = try await loadUserTasks()
        
        // 2. Analyze task patterns and issues
        let analysis = analyzeTaskPatterns(userTasks)
        
        // 3. Generate AI-powered suggestions
        let suggestions = try await generateImprovements(analysis)
        
        // 4. Update UI
        improvements = suggestions
        analysisState = .completed
    }
}
```

### 3. ImprovementSuggestion Data Model
```swift
struct ImprovementSuggestion: Identifiable, Codable {
    let id = UUID()
    let type: ImprovementType
    let title: String
    let description: String
    let targetTasks: [String] // Task IDs
    let impact: ImprovementImpact
    let actionRequired: ImprovementAction
    let confidence: Double // 0.0 - 1.0
}

enum ImprovementType {
    case taskBreakdown      // Break large tasks into subtasks
    case priorityAdjustment // Reorder task priorities
    case deadlineOptimization // Adjust unrealistic deadlines
    case dependencyMapping  // Add task dependencies
    case categoryReorganization // Better task categorization
}

enum ImprovementImpact {
    case low, medium, high, critical
}

struct ImprovementAction {
    let actionType: ActionType
    let parameters: [String: Any]
}
```

## Integration Points

### AITaskGenerator Enhancement
```swift
extension AITaskGenerator {
    func analyzeTasksForImprovement(_ tasks: [ShigodekiTask]) async throws -> [ImprovementSuggestion] {
        let analysisPrompt = buildTaskAnalysisPrompt(tasks)
        let response = try await currentClient?.generateImprovementSuggestions(for: analysisPrompt)
        return parseImprovementSuggestions(response)
    }
}
```

### SharedManagerStore Integration
```swift
extension SharedManagerStore {
    func getTaskImprovementEngine() async -> TaskImprovementEngine {
        if let existing = taskImprovementEngine {
            return existing
        }
        
        let engine = TaskImprovementEngine(
            aiGenerator: await getAiGenerator(),
            taskManager: await getTaskManager(),
            familyManager: await getFamilyManager()
        )
        
        taskImprovementEngine = engine
        return engine
    }
}
```

## UI/UX Design Specification

### Analysis Phase UI
```swift
VStack {
    // Progress indicator
    ProgressView(value: analysisProgress)
        .progressViewStyle(LinearProgressViewStyle())
    
    // Status message
    Text(analysisMessage)
        .font(.subheadline)
        .foregroundColor(.secondary)
    
    // Task analysis preview
    LazyVStack {
        ForEach(tasksBeingAnalyzed) { task in
            TaskAnalysisRow(task: task)
        }
    }
}
```

### Results Display UI
```swift
ScrollView {
    LazyVStack(spacing: 16) {
        ForEach(improvements) { suggestion in
            ImprovementSuggestionCard(
                suggestion: suggestion,
                isSelected: selectedSuggestions.contains(suggestion.id),
                onToggle: { toggleSuggestion(suggestion) }
            )
        }
    }
}
```

### Action Controls
```swift
HStack {
    Button("Select All High Impact") {
        selectHighImpactSuggestions()
    }
    
    Spacer()
    
    Button("Apply Selected") {
        applySelectedImprovements()
    }
    .disabled(selectedSuggestions.isEmpty || isApplying)
}
```

## Implementation Strategy

### Phase 1: Core Engine (1-2 days)
1. Create `TaskImprovementEngine` class
2. Implement task loading and analysis
3. Add basic AI integration

### Phase 2: UI Components (1 day)
1. Build `TaskImprovementSuggestionView`
2. Create suggestion display components
3. Add interaction handlers

### Phase 3: Integration (1 day)
1. Connect to SharedManagerStore
2. Test with existing task data
3. Handle edge cases and errors

### Phase 4: Polish (1 day)
1. Add animations and transitions
2. Implement loading states
3. Add error handling UI

## Testing Strategy

### Unit Tests
- TaskImprovementEngine logic
- Suggestion parsing and validation
- AI integration error handling

### Integration Tests
- Full workflow from analysis to application
- Multiple family/task scenarios
- Offline behavior

### UI Tests
- User interaction flows
- Loading state transitions
- Error recovery scenarios

## Success Metrics

### Technical Metrics
- Analysis completion time < 30 seconds
- AI response accuracy > 85%
- Error rate < 5%

### User Experience Metrics
- Suggestion relevance rating > 4.0/5.0
- Feature adoption rate > 60%
- User satisfaction improvement

## Risk Mitigation

### AI Service Failures
- Fallback to local analysis
- Cached suggestion templates
- Graceful error handling

### Performance Issues
- Background processing
- Progressive loading
- Memory management

### Data Privacy
- Local analysis when possible
- Minimal data sent to AI services
- User consent for AI features