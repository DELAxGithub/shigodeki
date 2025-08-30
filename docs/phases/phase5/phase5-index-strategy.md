# Phase 5: Firestore Index Strategy
*Shigodeki Architecture Evolution - Session 5.1*

## Index Strategy Overview

This document outlines the comprehensive indexing strategy for the new project-based architecture, optimizing for common query patterns while minimizing index maintenance overhead.

---

## Single Field Indexes

### Users Collection
```yaml
# /users/{userId}
indexes:
  - field: projectIds
    mode: ARRAY_CONTAINS
  - field: lastActiveAt  
    mode: DESCENDING
  - field: createdAt
    mode: DESCENDING
```

### Projects Collection
```yaml
# /projects/{projectId}
indexes:
  - field: memberIds
    mode: ARRAY_CONTAINS
  - field: ownerId
    mode: ASCENDING
  - field: isArchived
    mode: ASCENDING
  - field: lastModifiedAt
    mode: DESCENDING
  - field: createdAt
    mode: DESCENDING
  - field: migratedFromFamily
    mode: ASCENDING  # For migration queries
```

### Project Members Subcollection
```yaml
# /projects/{projectId}/members/{userId}
indexes:
  - field: role
    mode: ASCENDING
  - field: joinedAt
    mode: DESCENDING
  - field: lastActiveAt
    mode: DESCENDING
```

### Phases Subcollection
```yaml
# /projects/{projectId}/phases/{phaseId}
indexes:
  - field: projectId
    mode: ASCENDING
  - field: order
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
  - field: createdAt
    mode: DESCENDING
```

### Lists Subcollection
```yaml
# /projects/{projectId}/phases/{phaseId}/lists/{listId}
indexes:
  - field: phaseId
    mode: ASCENDING
  - field: projectId
    mode: ASCENDING
  - field: order
    mode: ASCENDING
  - field: isArchived
    mode: ASCENDING
  - field: createdBy
    mode: ASCENDING
```

### Tasks Subcollection
```yaml
# /projects/{projectId}/phases/{phaseId}/lists/{listId}/tasks/{taskId}
indexes:
  - field: listId
    mode: ASCENDING
  - field: phaseId
    mode: ASCENDING
  - field: projectId
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
  - field: assignedTo
    mode: ASCENDING
  - field: dueDate
    mode: ASCENDING
  - field: priority
    mode: ASCENDING
  - field: createdBy
    mode: ASCENDING
  - field: order
    mode: ASCENDING
  - field: hasSubtasks
    mode: ASCENDING
  - field: tags
    mode: ARRAY_CONTAINS
```

### Subtasks Subcollection
```yaml
# /projects/{projectId}/phases/{phaseId}/lists/{listId}/tasks/{taskId}/subtasks/{subtaskId}
indexes:
  - field: taskId
    mode: ASCENDING
  - field: listId
    mode: ASCENDING
  - field: phaseId
    mode: ASCENDING
  - field: projectId
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
  - field: assignedTo
    mode: ASCENDING
  - field: order
    mode: ASCENDING
```

---

## Composite Indexes

### High-Priority Composite Indexes

#### 1. User Project Queries
```yaml
# Get user's active projects, sorted by recent activity
collection: projects
fields:
  - field: memberIds
    mode: ARRAY_CONTAINS
  - field: isArchived
    mode: ASCENDING
  - field: lastModifiedAt
    mode: DESCENDING
```

#### 2. Phase Management
```yaml
# Get project phases in order
collection: phases
fields:
  - field: projectId
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
  - field: order
    mode: ASCENDING
```

#### 3. List Management
```yaml
# Get phase lists in order
collection: lists
fields:
  - field: phaseId
    mode: ASCENDING
  - field: isArchived
    mode: ASCENDING
  - field: order
    mode: ASCENDING
```

#### 4. Task Queries - Project View
```yaml
# Get all incomplete tasks in a project, sorted by due date
collection: tasks
fields:
  - field: projectId
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
  - field: dueDate
    mode: ASCENDING

# Get user's assigned tasks in a project
collection: tasks
fields:
  - field: projectId
    mode: ASCENDING
  - field: assignedTo
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
  - field: dueDate
    mode: ASCENDING
```

#### 5. Task Queries - List View
```yaml
# Get list tasks by completion status and order
collection: tasks
fields:
  - field: listId
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
  - field: order
    mode: ASCENDING

# Get list tasks by priority
collection: tasks
fields:
  - field: listId
    mode: ASCENDING
  - field: priority
    mode: DESCENDING
  - field: dueDate
    mode: ASCENDING
```

#### 6. Cross-Project User Tasks
```yaml
# Get all user tasks across projects (Collection Group Query)
collection: tasks  # Collection Group
fields:
  - field: assignedTo
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
  - field: dueDate
    mode: ASCENDING

# Get overdue tasks for user
collection: tasks  # Collection Group
fields:
  - field: assignedTo
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
  - field: dueDate
    mode: ASCENDING
```

### Medium-Priority Composite Indexes

#### 7. Advanced Task Filtering
```yaml
# Get tasks by priority and completion status
collection: tasks
fields:
  - field: listId
    mode: ASCENDING
  - field: priority
    mode: DESCENDING
  - field: isCompleted
    mode: ASCENDING

# Get tasks with subtasks
collection: tasks
fields:
  - field: projectId
    mode: ASCENDING
  - field: hasSubtasks
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
```

#### 8. Statistics and Analytics
```yaml
# Get recently created tasks for activity feed
collection: tasks  # Collection Group
fields:
  - field: projectId
    mode: ASCENDING
  - field: createdAt
    mode: DESCENDING

# Get completed tasks for reporting
collection: tasks
fields:
  - field: projectId
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
  - field: completedAt
    mode: DESCENDING
```

#### 9. Subtask Management
```yaml
# Get task subtasks in order
collection: subtasks
fields:
  - field: taskId
    mode: ASCENDING
  - field: order
    mode: ASCENDING

# Get incomplete subtasks for task
collection: subtasks
fields:
  - field: taskId
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
  - field: order
    mode: ASCENDING
```

---

## Collection Group Indexes

Collection Group queries span multiple subcollections, enabling powerful cross-project queries.

### Tasks Collection Group
```yaml
# Index for all tasks across all projects
collection_group: tasks
fields:
  - field: assignedTo
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
  - field: dueDate
    mode: ASCENDING

# Index for project-wide task queries
collection_group: tasks
fields:
  - field: projectId
    mode: ASCENDING
  - field: assignedTo
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
```

### Subtasks Collection Group
```yaml
# Index for all subtasks across all projects
collection_group: subtasks
fields:
  - field: assignedTo
    mode: ASCENDING
  - field: isCompleted
    mode: ASCENDING
  - field: dueDate
    mode: ASCENDING
```

---

## Index Exemptions

### Collections That Don't Need Indexes
- `project_invitations` - Small collections, simple queries
- `user_migrations` - Temporary collections for migration
- Documents with fewer than 100 expected items

### Fields That Don't Need Indexes
- `description` fields - Text search handled separately
- `statistics` fields - Computed values, not queried directly
- `settings` fields - Queried infrequently

---

## Migration-Specific Indexes

During the migration period, additional temporary indexes are needed:

### Legacy Data Migration
```yaml
# Find families that haven't been migrated
collection: families
fields:
  - field: migrated
    mode: ASCENDING
  - field: createdAt
    mode: ASCENDING

# Track migration progress
collection: user_migrations
fields:
  - field: status
    mode: ASCENDING
  - field: migrationStartedAt
    mode: ASCENDING
```

---

## Performance Considerations

### Index Size Optimization
1. **Limit composite indexes** to essential query patterns only
2. **Use single-field indexes** for simple filters
3. **Avoid indexing high-cardinality text fields**
4. **Consider query frequency** when designing indexes

### Query Optimization Patterns
1. **Always filter by project** to limit result set size
2. **Use limit() and offset()** for pagination
3. **Cache frequently accessed data** in client
4. **Batch reads** when possible to reduce query count

### Monitoring and Maintenance
1. **Monitor index usage** in Firebase Console
2. **Remove unused indexes** identified through usage analytics
3. **Update indexes** as query patterns evolve
4. **Regular performance reviews** quarterly

---

## Implementation Timeline

### Phase 1: Core Indexes (Week 1)
- User, Project, Phase, List single-field indexes
- Basic composite indexes for navigation

### Phase 2: Task Management Indexes (Week 2)  
- Task and Subtask indexes
- Collection group indexes for cross-project queries

### Phase 3: Advanced Features (Week 3)
- Analytics and reporting indexes
- Performance optimization indexes

### Phase 4: Migration Indexes (During Migration)
- Temporary indexes for data migration
- Removed after migration completion

---

## Firestore Index Configuration File

```json
{
  "indexes": [
    {
      "collectionGroup": "tasks",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        {"fieldPath": "assignedTo", "order": "ASCENDING"},
        {"fieldPath": "isCompleted", "order": "ASCENDING"},
        {"fieldPath": "dueDate", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "tasks",
      "queryScope": "COLLECTION_GROUP", 
      "fields": [
        {"fieldPath": "projectId", "order": "ASCENDING"},
        {"fieldPath": "assignedTo", "order": "ASCENDING"},
        {"fieldPath": "isCompleted", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "projects",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "memberIds", "arrayConfig": "CONTAINS"},
        {"fieldPath": "isArchived", "order": "ASCENDING"},
        {"fieldPath": "lastModifiedAt", "order": "DESCENDING"}
      ]
    }
  ],
  "fieldOverrides": []
}
```

---

*This index strategy balances query performance with maintenance overhead, ensuring optimal user experience while keeping Firebase costs reasonable.*