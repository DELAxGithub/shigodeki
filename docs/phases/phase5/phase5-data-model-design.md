# Phase 5: Data Model Design Document
*Shigodeki Architecture Evolution - Session 5.1*

## Overview
Transformation from family-based task management to project-based hierarchical architecture with enhanced collaboration and scalability.

---

## Current vs. New Architecture

### Current Structure (Phase 4)
```
users/{userId}
├── familyIds: [string] 
└── metadata

families/{familyId}
├── taskLists/{listId}/
│   └── tasks/{taskId}
└── metadata

invitations/{inviteCode}
└── metadata
```

### New Structure (Phase 5+)
```
users/{userId}
├── projectIds: [string] 
├── role_assignments/{projectId}: Role
└── metadata

projects/{projectId}
├── metadata
├── members/{userId}
├── phases/{phaseId}/
│   ├── metadata
│   └── lists/{listId}/
│       ├── metadata  
│       └── tasks/{taskId}/
│           ├── metadata
│           └── subtasks/{subtaskId}
└── invitations/{inviteCode}
```

---

## Data Model Specifications

### 1. User Model (Enhanced)
```swift
struct User: Identifiable, Codable {
    var id: String?
    let name: String
    let email: String
    let projectIds: [String]          // NEW: replaces familyIds
    let roleAssignments: [String: Role] // NEW: project-role mapping
    var createdAt: Date?
    var lastActiveAt: Date?           // NEW: activity tracking
    var preferences: UserPreferences? // NEW: user settings
}

struct UserPreferences: Codable {
    let theme: String
    let notificationsEnabled: Bool
    let defaultView: String
}

enum Role: String, CaseIterable, Codable {
    case owner = "owner"       // Full permissions
    case editor = "editor"     // Edit content, manage tasks
    case viewer = "viewer"     // Read-only access
    
    var permissions: Set<Permission> {
        switch self {
        case .owner: return [.read, .write, .delete, .invite, .manageMembers]
        case .editor: return [.read, .write, .invite]
        case .viewer: return [.read]
        }
    }
}

enum Permission {
    case read, write, delete, invite, manageMembers
}
```

### 2. Project Model (NEW)
```swift
struct Project: Identifiable, Codable {
    var id: String?
    let name: String
    let description: String?
    let ownerId: String              // Creator/owner user ID
    var memberIds: [String]          // All project members
    var createdAt: Date?
    var lastModifiedAt: Date?
    var isArchived: Bool
    var settings: ProjectSettings?
    var statistics: ProjectStats?    // Computed fields
    
    init(name: String, description: String? = nil, ownerId: String) {
        self.name = name
        self.description = description
        self.ownerId = ownerId
        self.memberIds = [ownerId]
        self.isArchived = false
    }
}

struct ProjectSettings: Codable {
    let color: TaskListColor         // Reuse existing color enum
    let isPrivate: Bool
    let defaultPhaseTemplate: String?
}

struct ProjectStats: Codable {
    let totalTasks: Int
    let completedTasks: Int
    let totalPhases: Int
    let activeMembers: Int
}
```

### 3. ProjectMember Model (NEW)
```swift
struct ProjectMember: Identifiable, Codable {
    var id: String?                  // userId
    let userId: String
    let projectId: String
    var role: Role
    var joinedAt: Date?
    var invitedBy: String?           // userId who sent invitation
    var lastActiveAt: Date?
    
    init(userId: String, projectId: String, role: Role, invitedBy: String? = nil) {
        self.id = userId
        self.userId = userId
        self.projectId = projectId
        self.role = role
        self.invitedBy = invitedBy
    }
}
```

### 4. Phase Model (NEW)
```swift
struct Phase: Identifiable, Codable {
    var id: String?
    let name: String
    let description: String?
    let projectId: String
    var order: Int                   // Sequence within project
    var createdAt: Date?
    var createdBy: String           // userId
    var isCompleted: Bool
    var completedAt: Date?
    var settings: PhaseSettings?
    
    init(name: String, description: String? = nil, projectId: String, createdBy: String, order: Int) {
        self.name = name
        self.description = description
        self.projectId = projectId
        self.createdBy = createdBy
        self.order = order
        self.isCompleted = false
    }
}

struct PhaseSettings: Codable {
    let color: TaskListColor
    let autoCompleteOnAllTasksDone: Bool
}
```

### 5. TaskList Model (Enhanced)
```swift
struct TaskList: Identifiable, Codable {
    var id: String?
    let name: String
    let phaseId: String              // NEW: belongs to phase instead of family
    let projectId: String            // NEW: denormalized for easy querying
    var createdAt: Date?
    let createdBy: String
    var color: TaskListColor
    var isArchived: Bool
    var order: Int                   // NEW: sequence within phase
    var settings: TaskListSettings?  // NEW: list-specific settings
    
    init(name: String, phaseId: String, projectId: String, createdBy: String, color: TaskListColor = .blue, order: Int) {
        self.name = name
        self.phaseId = phaseId
        self.projectId = projectId
        self.createdBy = createdBy
        self.color = color
        self.isArchived = false
        self.order = order
    }
}

struct TaskListSettings: Codable {
    let autoArchiveCompletedTasks: Bool
    let defaultTaskPriority: TaskPriority
}
```

### 6. Task Model (Enhanced)
```swift
struct ShigodekiTask: Identifiable, Codable {
    var id: String?
    let title: String
    let description: String?
    var isCompleted: Bool
    let assignedTo: String?
    var createdAt: Date?
    var completedAt: Date?
    var dueDate: Date?
    var priority: TaskPriority
    let createdBy: String
    
    // NEW: Hierarchy fields
    let listId: String               // Parent list
    let phaseId: String              // Denormalized for queries
    let projectId: String            // Denormalized for queries
    var order: Int                   // Sequence within list
    var hasSubtasks: Bool            // Optimization flag
    var subtaskCount: Int            // Cache for performance
    var completedSubtaskCount: Int   // Cache for performance
    
    // NEW: Enhanced metadata
    var tags: [String]               // Flexible tagging system
    var estimatedHours: Double?      // Time estimation
    var actualHours: Double?         // Time tracking
    var dependsOn: [String]          // Task dependencies (task IDs)
    
    init(title: String, description: String? = nil, assignedTo: String? = nil, 
         createdBy: String, dueDate: Date? = nil, priority: TaskPriority = .medium,
         listId: String, phaseId: String, projectId: String, order: Int) {
        self.title = title
        self.description = description
        self.isCompleted = false
        self.assignedTo = assignedTo
        self.createdBy = createdBy
        self.dueDate = dueDate
        self.priority = priority
        self.listId = listId
        self.phaseId = phaseId
        self.projectId = projectId
        self.order = order
        self.hasSubtasks = false
        self.subtaskCount = 0
        self.completedSubtaskCount = 0
        self.tags = []
    }
}
```

### 7. Subtask Model (NEW)
```swift
struct Subtask: Identifiable, Codable {
    var id: String?
    let title: String
    let description: String?
    var isCompleted: Bool
    let assignedTo: String?
    var createdAt: Date?
    var completedAt: Date?
    var dueDate: Date?
    let createdBy: String
    
    // Hierarchy fields
    let taskId: String               // Parent task
    let listId: String               // Denormalized for queries
    let phaseId: String              // Denormalized for queries
    let projectId: String            // Denormalized for queries
    var order: Int                   // Sequence within task
    
    init(title: String, description: String? = nil, assignedTo: String? = nil,
         createdBy: String, dueDate: Date? = nil, taskId: String, 
         listId: String, phaseId: String, projectId: String, order: Int) {
        self.title = title
        self.description = description
        self.isCompleted = false
        self.assignedTo = assignedTo
        self.createdBy = createdBy
        self.dueDate = dueDate
        self.taskId = taskId
        self.listId = listId
        self.phaseId = phaseId
        self.projectId = projectId
        self.order = order
    }
}
```

### 8. ProjectInvitation Model (Enhanced)
```swift
struct ProjectInvitation: Identifiable, Codable {
    var id: String?                  // invite code
    let inviteCode: String           // 6-character code
    let projectId: String
    let projectName: String          // Cached for display
    let invitedBy: String            // userId
    let invitedByName: String        // Cached for display
    let role: Role                   // Role to assign upon acceptance
    var isActive: Bool
    var createdAt: Date?
    var expiresAt: Date?
    var usedAt: Date?                // When invitation was accepted
    var usedBy: String?              // Who accepted the invitation
    
    init(inviteCode: String, projectId: String, projectName: String, 
         invitedBy: String, invitedByName: String, role: Role) {
        self.id = inviteCode
        self.inviteCode = inviteCode
        self.projectId = projectId
        self.projectName = projectName
        self.invitedBy = invitedBy
        self.invitedByName = invitedByName
        self.role = role
        self.isActive = true
        self.expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date())
    }
}
```

---

## Key Design Principles

### 1. Hierarchy & Organization
- **Project** → **Phase** → **List** → **Task** → **Subtask**
- Each level maintains references to parent and project for efficient querying
- Order fields enable custom sorting within each level

### 2. Role-Based Access Control
- Three roles: Owner, Editor, Viewer
- Granular permissions system
- Project-level membership management

### 3. Performance Optimization
- Denormalized data for common queries
- Cached counts and statistics
- Efficient indexing strategy

### 4. Migration Compatibility
- Maintains core concepts from current model
- Clear mapping path from families → projects
- Preserves existing task data structure

### 5. Future Extensibility
- Tag system for flexible categorization
- Time tracking foundations
- Template system preparation
- AI integration hooks

---

## Benefits of New Architecture

### Scalability
- Better support for large projects
- Efficient queries across hierarchy levels
- Optimized for complex permission models

### User Experience
- Clearer project organization
- Better collaboration controls
- Support for complex workflows

### Development
- More maintainable code structure
- Better separation of concerns
- Enhanced testing capabilities

---

*This design provides a solid foundation for the project-based architecture while maintaining compatibility with existing functionality.*