# Phase 5: Firestore Collection Structure Specification
*Shigodeki Architecture Evolution - Session 5.1*

## Collection Hierarchy Overview

```
root/
├── users/{userId}
│   ├── projectIds: [string]
│   ├── roleAssignments: {projectId: role}
│   └── [metadata fields]
│
├── projects/{projectId}
│   ├── [project metadata]
│   ├── members/{userId}
│   │   ├── role: string
│   │   ├── joinedAt: timestamp
│   │   └── [member metadata]
│   │
│   ├── phases/{phaseId}
│   │   ├── [phase metadata]
│   │   └── lists/{listId}
│   │       ├── [list metadata]
│   │       └── tasks/{taskId}
│   │           ├── [task metadata]
│   │           └── subtasks/{subtaskId}
│   │               └── [subtask metadata]
│   │
│   └── invitations/{inviteCode}
│       ├── role: string
│       ├── isActive: boolean
│       └── [invitation metadata]
│
└── [legacy collections for migration]
    ├── families/{familyId}
    ├── invitations_legacy/{inviteCode}
    └── user_migrations/{userId}
```

---

## Detailed Collection Specifications

### 1. Users Collection
**Path**: `/users/{userId}`

```typescript
interface UserDocument {
  // Core Identity
  name: string;
  email: string;
  
  // Project Associations
  projectIds: string[];                    // All projects user belongs to
  roleAssignments: {[projectId: string]: 'owner' | 'editor' | 'viewer'};
  
  // Metadata
  createdAt: Timestamp;
  lastActiveAt: Timestamp;
  
  // Settings (optional)
  preferences?: {
    theme: 'light' | 'dark' | 'system';
    notificationsEnabled: boolean;
    defaultView: 'projects' | 'tasks' | 'calendar';
  };
  
  // Migration tracking
  migratedFromFamilies?: string[];         // Track migration source
  migrationCompletedAt?: Timestamp;
}
```

### 2. Projects Collection
**Path**: `/projects/{projectId}`

```typescript
interface ProjectDocument {
  // Core Properties
  name: string;
  description?: string;
  
  // Ownership
  ownerId: string;                         // User who created project
  memberIds: string[];                     // All project members
  
  // Status
  isArchived: boolean;
  
  // Metadata
  createdAt: Timestamp;
  lastModifiedAt: Timestamp;
  
  // Settings (optional)
  settings?: {
    color: 'blue' | 'green' | 'orange' | 'red' | 'purple' | 'pink' | 'yellow' | 'gray';
    isPrivate: boolean;
    defaultPhaseTemplate?: string;
  };
  
  // Cached Statistics (updated via Cloud Functions)
  statistics?: {
    totalTasks: number;
    completedTasks: number;
    totalPhases: number;
    activeMembers: number;
    lastActivityAt: Timestamp;
  };
  
  // Migration tracking
  migratedFromFamily?: string;             // Original family ID
}
```

### 3. Project Members Subcollection
**Path**: `/projects/{projectId}/members/{userId}`

```typescript
interface ProjectMemberDocument {
  // Identity
  userId: string;                          // Matches document ID
  projectId: string;                       // Parent project
  
  // Role & Permissions
  role: 'owner' | 'editor' | 'viewer';
  
  // Metadata
  joinedAt: Timestamp;
  invitedBy?: string;                      // User ID who sent invitation
  lastActiveAt: Timestamp;
  
  // Cached user data for performance
  userName: string;                        // Denormalized from users collection
  userEmail: string;                       // Denormalized from users collection
}
```

### 4. Phases Subcollection
**Path**: `/projects/{projectId}/phases/{phaseId}`

```typescript
interface PhaseDocument {
  // Core Properties
  name: string;
  description?: string;
  
  // Hierarchy
  projectId: string;                       // Parent project (denormalized)
  order: number;                           // Sequence within project (0-based)
  
  // Status
  isCompleted: boolean;
  completedAt?: Timestamp;
  
  // Metadata
  createdAt: Timestamp;
  createdBy: string;                       // User ID of creator
  
  // Settings (optional)
  settings?: {
    color: 'blue' | 'green' | 'orange' | 'red' | 'purple' | 'pink' | 'yellow' | 'gray';
    autoCompleteOnAllTasksDone: boolean;
  };
  
  // Cached Statistics
  statistics?: {
    totalLists: number;
    totalTasks: number;
    completedTasks: number;
  };
}
```

### 5. Lists Subcollection
**Path**: `/projects/{projectId}/phases/{phaseId}/lists/{listId}`

```typescript
interface ListDocument {
  // Core Properties
  name: string;
  
  // Hierarchy (denormalized for efficient querying)
  phaseId: string;                         // Parent phase
  projectId: string;                       // Root project
  order: number;                           // Sequence within phase
  
  // Metadata
  createdAt: Timestamp;
  createdBy: string;                       // User ID of creator
  
  // Visual & Status
  color: 'blue' | 'green' | 'orange' | 'red' | 'purple' | 'pink' | 'yellow' | 'gray';
  isArchived: boolean;
  
  // Settings (optional)
  settings?: {
    autoArchiveCompletedTasks: boolean;
    defaultTaskPriority: 'low' | 'medium' | 'high';
  };
  
  // Cached Statistics
  statistics?: {
    totalTasks: number;
    completedTasks: number;
  };
}
```

### 6. Tasks Subcollection
**Path**: `/projects/{projectId}/phases/{phaseId}/lists/{listId}/tasks/{taskId}`

```typescript
interface TaskDocument {
  // Core Properties
  title: string;
  description?: string;
  
  // Status & Assignment
  isCompleted: boolean;
  assignedTo?: string;                     // User ID
  completedAt?: Timestamp;
  
  // Scheduling
  dueDate?: Timestamp;
  priority: 'low' | 'medium' | 'high';
  
  // Hierarchy (denormalized for efficient querying)
  listId: string;                          // Parent list
  phaseId: string;                         // Parent phase
  projectId: string;                       // Root project
  order: number;                           // Sequence within list
  
  // Metadata
  createdAt: Timestamp;
  createdBy: string;                       // User ID of creator
  
  // Subtask Management (cached for performance)
  hasSubtasks: boolean;
  subtaskCount: number;
  completedSubtaskCount: number;
  
  // Enhanced Features (optional)
  tags?: string[];                         // Flexible tagging
  estimatedHours?: number;                 // Time estimation
  actualHours?: number;                    // Time tracking
  dependsOn?: string[];                    // Task dependencies (task IDs)
  
  // Cached assignee data for performance
  assignedToName?: string;                 // Denormalized user name
}
```

### 7. Subtasks Subcollection
**Path**: `/projects/{projectId}/phases/{phaseId}/lists/{listId}/tasks/{taskId}/subtasks/{subtaskId}`

```typescript
interface SubtaskDocument {
  // Core Properties
  title: string;
  description?: string;
  
  // Status & Assignment
  isCompleted: boolean;
  assignedTo?: string;                     // User ID
  completedAt?: Timestamp;
  
  // Scheduling
  dueDate?: Timestamp;
  
  // Hierarchy (denormalized for efficient querying)
  taskId: string;                          // Parent task
  listId: string;                          // Parent list
  phaseId: string;                         // Parent phase
  projectId: string;                       // Root project
  order: number;                           // Sequence within task
  
  // Metadata
  createdAt: Timestamp;
  createdBy: string;                       // User ID of creator
  
  // Cached assignee data for performance
  assignedToName?: string;                 // Denormalized user name
}
```

### 8. Project Invitations Subcollection
**Path**: `/projects/{projectId}/invitations/{inviteCode}`

```typescript
interface ProjectInvitationDocument {
  // Invitation Identity
  inviteCode: string;                      // 6-character alphanumeric code
  
  // Project Context
  projectId: string;                       // Parent project
  projectName: string;                     // Cached for display
  
  // Invitation Details
  invitedBy: string;                       // User ID who created invitation
  invitedByName: string;                   // Cached for display
  role: 'editor' | 'viewer';               // Role to assign (not owner)
  
  // Status
  isActive: boolean;
  
  // Timing
  createdAt: Timestamp;
  expiresAt: Timestamp;                    // 7 days from creation
  
  // Usage Tracking
  usedAt?: Timestamp;
  usedBy?: string;                         // User ID who accepted
}
```

---

## Migration Collections (Temporary)

### 9. Legacy Family Collection (Preserved)
**Path**: `/families/{familyId}`
- Preserved during migration for rollback capability
- Marked as `migrated: true` when successfully converted
- Removed after successful migration verification

### 10. User Migration Tracking
**Path**: `/user_migrations/{userId}`

```typescript
interface UserMigrationDocument {
  userId: string;
  migrationStartedAt: Timestamp;
  migrationCompletedAt?: Timestamp;
  status: 'pending' | 'in_progress' | 'completed' | 'failed';
  
  originalFamilies: string[];              // Family IDs user belonged to
  createdProjects: string[];               // Project IDs created during migration
  
  errorDetails?: {
    stage: string;
    error: string;
    timestamp: Timestamp;
  };
}
```

---

## Key Design Decisions

### 1. Denormalization Strategy
- **Project/Phase/List IDs** stored in nested documents for efficient querying
- **User names/emails** cached in member documents to reduce reads
- **Statistics** cached and updated via Cloud Functions

### 2. Collection Structure
- **Deep nesting** for clear hierarchy (max 6 levels deep within Firestore limits)
- **Subcollections** used for related data that grows over time
- **Denormalized references** for common query patterns

### 3. Performance Optimizations
- **Cached counts** for UI display without expensive aggregation queries
- **Flattened user associations** for quick permission checks
- **Strategic denormalization** to minimize cross-collection queries

### 4. Migration Safety
- **Parallel collections** during migration to enable rollback
- **Migration tracking** to monitor progress and handle failures
- **Gradual transition** allowing both old and new data structures temporarily

---

## Query Patterns

### Common Query Examples

```typescript
// Get user's projects
const userProjectsQuery = db.collection('users').doc(userId).get()
  .then(doc => doc.data().projectIds);

// Get project phases
const projectPhasesQuery = db.collection('projects').doc(projectId)
  .collection('phases')
  .orderBy('order')
  .get();

// Get phase tasks (across all lists)
const phaseTasksQuery = db.collectionGroup('tasks')
  .where('phaseId', '==', phaseId)
  .where('isCompleted', '==', false)
  .orderBy('dueDate')
  .get();

// Get user's assigned tasks across all projects
const userTasksQuery = db.collectionGroup('tasks')
  .where('assignedTo', '==', userId)
  .where('isCompleted', '==', false)
  .orderBy('dueDate')
  .get();
```

---

*This collection structure provides optimal performance for the new project-based architecture while maintaining clear hierarchical relationships and supporting complex query patterns.*