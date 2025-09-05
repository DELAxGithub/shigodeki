# TaskList Creation Workflow Design

## Design Overview
**Issue**: #15 - タスクリスト作成機能の実装
**Priority**: High
**Context**: New architecture integration for project-phase-tasklist hierarchy

## Current State Analysis

### Existing Components
- ✅ `CreateTaskListView` - Basic UI structure exists
- ✅ `TaskListManager` - Backend integration ready
- ❌ **Missing**: Integration between UI and new architecture
- ❌ **Missing**: Phase-TaskList relationship management

### Current Architecture Gap
```
Project → Phase → TaskList (NEW HIERARCHY)
       ↑
   Missing integration point
```

## System Architecture Design

### Component Flow
```
[PhaseListView] → [CreateTaskListView] → [TaskListManager] → [Firestore]
                              ↓
                    [PhaseManager] (for relationship)
                              ↓
                    [SharedManagerStore] (coordination)
```

### Data Flow Specification
```
1. User Context: Project + Phase selected
2. UI Input: TaskList name, description, color
3. Validation: Name required, unique within phase
4. Creation: TaskList + Phase relationship
5. Update: Phase task list count
6. Navigation: Return to phase view with new list
```

## Detailed Component Design

### 1. Enhanced CreateTaskListView
**Current Issue**: Missing phase context and integration
**Solution**: Add phase-aware creation workflow

```swift
struct CreateTaskListView: View {
    // MARK: - Properties
    let phase: Phase
    let project: Project
    
    @StateObject private var taskListManager: TaskListManager
    @StateObject private var phaseManager: PhaseManager
    
    @State private var taskListName = ""
    @State private var taskListDescription = ""
    @State private var selectedColor: TaskListColor = .blue
    @State private var isCreating = false
    @State private var creationError: String?
    
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                taskListDetailsSection
                colorSelectionSection
                previewSection
            }
            .navigationTitle("新しいタスクリスト")
            .navigationBarItems(
                leading: cancelButton,
                trailing: createButton
            )
            .alert("作成エラー", isPresented: .constant(creationError != nil)) {
                Button("OK") { creationError = nil }
            } message: {
                Text(creationError ?? "")
            }
        }
    }
    
    // MARK: - Creation Logic
    private func createTaskList() async {
        guard !isCreating else { return }
        
        isCreating = true
        creationError = nil
        
        do {
            // 1. Create TaskList with phase relationship
            let taskList = await createTaskListModel()
            
            // 2. Save to Firestore
            try await taskListManager.createTaskList(taskList)
            
            // 3. Update phase task list count
            await phaseManager.incrementTaskListCount(for: phase.id)
            
            // 4. Navigate back with success
            await MainActor.run {
                presentationMode.wrappedValue.dismiss()
            }
            
        } catch {
            creationError = "タスクリストの作成に失敗しました: \(error.localizedDescription)"
        }
        
        isCreating = false
    }
    
    private func createTaskListModel() -> TaskList {
        TaskList(
            id: UUID().uuidString,
            name: taskListName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: taskListDescription.isEmpty ? nil : taskListDescription,
            color: selectedColor,
            phaseId: phase.id,
            projectId: project.id,
            familyId: project.familyId,
            order: 0, // Will be set by manager
            isArchived: false,
            createdAt: Date(),
            createdBy: // Current user ID
        )
    }
}
```

### 2. TaskList Data Model Enhancement
**Current Model**: Basic TaskList structure
**Enhancement**: Phase integration and ordering

```swift
struct TaskList: Identifiable, Codable {
    let id: String
    let name: String
    let description: String?
    let color: TaskListColor
    
    // NEW: Phase Integration
    let phaseId: String
    let projectId: String
    let familyId: String
    
    // NEW: Ordering and Management
    let order: Int
    let isArchived: Bool
    let taskCount: Int? // Cached for performance
    let completedTaskCount: Int? // Cached for performance
    
    // Metadata
    let createdAt: Date
    let createdBy: String
    let updatedAt: Date?
    let updatedBy: String?
}

enum TaskListColor: String, CaseIterable, Codable {
    case blue, green, orange, red, purple, yellow, gray, pink
    
    var displayColor: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .purple: return .purple
        case .yellow: return .yellow
        case .gray: return .gray
        case .pink: return .pink
        }
    }
    
    var displayName: String {
        switch self {
        case .blue: return "ブルー"
        case .green: return "グリーン"
        case .orange: return "オレンジ"
        case .red: return "レッド"
        case .purple: return "パープル"
        case .yellow: return "イエロー"
        case .gray: return "グレー"
        case .pink: return "ピンク"
        }
    }
}
```

### 3. TaskListManager Enhancement
**Current Functionality**: Basic CRUD operations
**Enhancement**: Phase-aware operations

```swift
extension TaskListManager {
    // MARK: - Phase-Aware Creation
    func createTaskList(_ taskList: TaskList) async throws {
        // 1. Validate phase exists
        guard await validatePhaseExists(taskList.phaseId) else {
            throw TaskListError.phaseNotFound
        }
        
        // 2. Determine order within phase
        let order = await getNextOrderInPhase(taskList.phaseId)
        var taskListWithOrder = taskList
        taskListWithOrder.order = order
        
        // 3. Create in Firestore
        let document = db.collection("families")
            .document(taskList.familyId)
            .collection("projects")
            .document(taskList.projectId)
            .collection("phases")
            .document(taskList.phaseId)
            .collection("taskLists")
            .document(taskList.id)
        
        try await document.setData(from: taskListWithOrder)
        
        // 4. Update local cache
        await MainActor.run {
            self.taskLists.append(taskListWithOrder)
            self.taskLists.sort { $0.order < $1.order }
        }
    }
    
    // MARK: - Phase Integration
    private func validatePhaseExists(_ phaseId: String) async -> Bool {
        // Check if phase exists and user has access
        // Implementation details...
        return true
    }
    
    private func getNextOrderInPhase(_ phaseId: String) async -> Int {
        let existingLists = taskLists.filter { $0.phaseId == phaseId }
        return (existingLists.map { $0.order }.max() ?? -1) + 1
    }
}
```

### 4. PhaseManager Integration
**Purpose**: Maintain phase-tasklist relationship integrity

```swift
extension PhaseManager {
    func incrementTaskListCount(for phaseId: String) async {
        guard let phaseIndex = phases.firstIndex(where: { $0.id == phaseId }) else {
            return
        }
        
        await MainActor.run {
            phases[phaseIndex].taskListCount += 1
        }
        
        // Update Firestore
        await updatePhaseTaskListCount(phaseId: phaseId, increment: 1)
    }
    
    private func updatePhaseTaskListCount(phaseId: String, increment: Int) async {
        // Firestore update implementation
    }
}
```

## UI/UX Design Enhancements

### Navigation Flow
```
PhaseListView
├── "新しいタスクリスト" button
└── → CreateTaskListView (with phase context)
    ├── Form: Name, Description, Color
    ├── Preview: Shows how it will appear
    └── → Success: Back to PhaseListView (updated)
```

### Form Validation
```swift
private var isFormValid: Bool {
    !taskListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private var createButton: some View {
    Button(isCreating ? "作成中..." : "作成") {
        Task {
            await createTaskList()
        }
    }
    .disabled(!isFormValid || isCreating)
}
```

### Error Handling UI
```swift
// Inline validation
if !taskListName.isEmpty && taskListName.count > 100 {
    Text("名前は100文字以内で入力してください")
        .foregroundColor(.red)
        .font(.caption)
}

// Creation error handling
.alert("作成エラー", isPresented: .constant(creationError != nil)) {
    Button("再試行") { 
        Task { await createTaskList() }
    }
    Button("キャンセル") { 
        creationError = nil 
    }
} message: {
    Text(creationError ?? "")
}
```

### Loading States
```swift
if isCreating {
    HStack {
        ProgressView()
            .scaleEffect(0.8)
        Text("タスクリストを作成中...")
    }
    .foregroundColor(.secondary)
}
```

## Integration with PhaseListView

### Updated PhaseListView Call
```swift
// In PhaseListView
.navigationDestination(isPresented: $showCreateTaskList) {
    CreateTaskListView(
        phase: selectedPhase,  // Pass selected phase
        project: project       // Pass project context
    )
    .environmentObject(sharedManagers)
}
```

### Success Feedback
```swift
// After successful creation
.onReceive(taskListCreationSuccess) { newTaskList in
    // Show success message
    // Refresh phase data
    // Highlight new task list
}
```

## Firestore Schema Integration

### Collection Structure
```
families/{familyId}/projects/{projectId}/phases/{phaseId}/taskLists/{taskListId}
```

### Document Structure
```json
{
  "id": "tasklist-uuid",
  "name": "UI Implementation",
  "description": "Frontend components and views",
  "color": "blue",
  "phaseId": "phase-uuid",
  "projectId": "project-uuid", 
  "familyId": "family-uuid",
  "order": 0,
  "isArchived": false,
  "taskCount": 0,
  "completedTaskCount": 0,
  "createdAt": "2025-08-30T...",
  "createdBy": "user-uuid",
  "updatedAt": null,
  "updatedBy": null
}
```

## Implementation Timeline

### Phase 1: Core Integration (1 day)
1. Update CreateTaskListView with phase context
2. Enhance TaskListManager creation logic
3. Add PhaseManager integration

### Phase 2: UI Enhancement (1 day)  
1. Improve form validation and error handling
2. Add loading states and success feedback
3. Implement navigation integration

### Phase 3: Testing & Polish (1 day)
1. Test creation workflow end-to-end
2. Handle edge cases and error scenarios
3. Add animations and transitions

## Success Metrics

### Technical Success
- TaskList creation success rate > 95%
- Average creation time < 3 seconds
- Zero data consistency issues

### User Experience Success
- Form completion rate > 90%
- User satisfaction rating > 4.0/5.0
- Error recovery success > 80%

## Risk Mitigation

### Data Integrity
- Atomic operations with rollback capability
- Validation at multiple levels
- Consistent state management

### User Experience  
- Clear error messages with recovery options
- Loading states prevent user confusion
- Validation feedback prevents errors

### Performance
- Optimistic UI updates
- Background Firestore operations
- Efficient data caching