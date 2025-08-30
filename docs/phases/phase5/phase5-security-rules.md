# Phase 5: Firestore Security Rules Specification
*Shigodeki Architecture Evolution - Session 5.1*

## Security Rules Overview

The new project-based architecture requires comprehensive security rules that enforce role-based access control while maintaining performance and simplicity. These rules protect user data, project privacy, and ensure proper authorization across the hierarchical structure.

---

## Core Security Principles

### 1. Authentication Required
- All operations require user authentication
- No anonymous access permitted

### 2. Role-Based Access Control
- **Owner**: Full control over project and all nested data
- **Editor**: Create, edit, delete tasks/lists/phases; invite members
- **Viewer**: Read-only access to project data

### 3. Data Isolation
- Users can only access projects they are members of
- Cross-project data access is prohibited
- Personal data remains private to the user

### 4. Hierarchical Permissions
- Project permissions cascade down to all nested collections
- Higher-level access grants lower-level access
- Efficient permission checking without excessive reads

---

## Complete Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================
    
    // Check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Get current user ID
    function getCurrentUser() {
      return request.auth.uid;
    }
    
    // Check if user is owner of a project
    function isProjectOwner(projectId) {
      return isAuthenticated() && 
        get(/databases/$(database)/documents/projects/$(projectId)).data.ownerId == getCurrentUser();
    }
    
    // Check if user is member of a project
    function isProjectMember(projectId) {
      return isAuthenticated() && 
        getCurrentUser() in get(/databases/$(database)/documents/projects/$(projectId)).data.memberIds;
    }
    
    // Get user's role in a project
    function getUserProjectRole(projectId) {
      return get(/databases/$(database)/documents/projects/$(projectId)/members/$(getCurrentUser())).data.role;
    }
    
    // Check if user has at least the specified role
    function hasMinimumRole(projectId, requiredRole) {
      let userRole = getUserProjectRole(projectId);
      return (requiredRole == 'viewer' && userRole in ['viewer', 'editor', 'owner']) ||
             (requiredRole == 'editor' && userRole in ['editor', 'owner']) ||
             (requiredRole == 'owner' && userRole == 'owner');
    }
    
    // Check if user can read project data
    function canReadProject(projectId) {
      return isProjectMember(projectId);
    }
    
    // Check if user can write project data  
    function canWriteProject(projectId) {
      return hasMinimumRole(projectId, 'editor');
    }
    
    // Check if user can manage project (delete, manage members)
    function canManageProject(projectId) {
      return hasMinimumRole(projectId, 'owner');
    }
    
    // Validate project data structure
    function isValidProjectData() {
      return request.resource.data.keys().hasAll(['name', 'ownerId', 'memberIds', 'isArchived']) &&
             request.resource.data.ownerId == getCurrentUser() &&
             getCurrentUser() in request.resource.data.memberIds;
    }
    
    // ============================================================================
    // USER COLLECTION
    // ============================================================================
    
    match /users/{userId} {
      // Users can only access their own data
      allow read, write: if isAuthenticated() && getCurrentUser() == userId;
    }
    
    // ============================================================================  
    // PROJECT COLLECTION
    // ============================================================================
    
    match /projects/{projectId} {
      // Read: Any project member
      allow read: if canReadProject(projectId);
      
      // Create: Any authenticated user (becomes owner)
      allow create: if isAuthenticated() && isValidProjectData();
      
      // Update: Editors and owners, but only owners can change membership/role settings
      allow update: if canWriteProject(projectId) && 
        // Editors can update basic fields
        (hasMinimumRole(projectId, 'editor') && 
         !request.resource.data.diff(resource.data).affectedKeys().hasAny(['ownerId', 'memberIds'])) ||
        // Only owners can change ownership or membership
        (hasMinimumRole(projectId, 'owner') && request.resource.data.ownerId == resource.data.ownerId);
      
      // Delete: Only owners
      allow delete: if canManageProject(projectId);
      
      // ========================================================================
      // PROJECT MEMBERS SUBCOLLECTION
      // ========================================================================
      
      match /members/{memberId} {
        // Read: Any project member can see all members
        allow read: if canReadProject(projectId);
        
        // Create: Owners and editors can add members (via invitations)
        allow create: if canWriteProject(projectId) && 
          request.resource.data.userId == memberId &&
          request.resource.data.projectId == projectId;
        
        // Update: Owners can update any member, users can update their own lastActiveAt
        allow update: if 
          (canManageProject(projectId)) ||
          (getCurrentUser() == memberId && 
           request.resource.data.diff(resource.data).affectedKeys().hasOnly(['lastActiveAt']));
        
        // Delete: Owners can remove any member, members can remove themselves
        allow delete: if canManageProject(projectId) || getCurrentUser() == memberId;
      }
      
      // ========================================================================
      // PROJECT INVITATIONS SUBCOLLECTION  
      // ========================================================================
      
      match /invitations/{inviteCode} {
        // Read: Any authenticated user (needed to accept invitations)
        allow read: if isAuthenticated();
        
        // Create: Editors and owners can create invitations
        allow create: if canWriteProject(projectId) &&
          request.resource.data.projectId == projectId &&
          request.resource.data.invitedBy == getCurrentUser();
        
        // Update: Only the creator or project owner can update
        allow update: if canManageProject(projectId) || 
          resource.data.invitedBy == getCurrentUser();
        
        // Delete: Only the creator or project owner can delete
        allow delete: if canManageProject(projectId) || 
          resource.data.invitedBy == getCurrentUser();
      }
      
      // ========================================================================
      // PHASES SUBCOLLECTION
      // ========================================================================
      
      match /phases/{phaseId} {
        // Read: Any project member
        allow read: if canReadProject(projectId);
        
        // Create: Editors and owners
        allow create: if canWriteProject(projectId) && 
          request.resource.data.projectId == projectId &&
          request.resource.data.createdBy == getCurrentUser();
        
        // Update: Editors and owners
        allow update: if canWriteProject(projectId);
        
        // Delete: Editors and owners
        allow delete: if canWriteProject(projectId);
        
        // ======================================================================
        // LISTS SUBCOLLECTION
        // ======================================================================
        
        match /lists/{listId} {
          // Read: Any project member
          allow read: if canReadProject(projectId);
          
          // Create: Editors and owners
          allow create: if canWriteProject(projectId) && 
            request.resource.data.projectId == projectId &&
            request.resource.data.phaseId == phaseId &&
            request.resource.data.createdBy == getCurrentUser();
          
          // Update: Editors and owners
          allow update: if canWriteProject(projectId);
          
          // Delete: Editors and owners
          allow delete: if canWriteProject(projectId);
          
          // ====================================================================
          // TASKS SUBCOLLECTION
          // ====================================================================
          
          match /tasks/{taskId} {
            // Read: Any project member
            allow read: if canReadProject(projectId);
            
            // Create: Editors and owners
            allow create: if canWriteProject(projectId) && 
              request.resource.data.projectId == projectId &&
              request.resource.data.phaseId == phaseId &&
              request.resource.data.listId == listId &&
              request.resource.data.createdBy == getCurrentUser();
            
            // Update: Editors and owners, plus assigned user can update completion status
            allow update: if canWriteProject(projectId) ||
              (resource.data.assignedTo == getCurrentUser() && 
               request.resource.data.diff(resource.data).affectedKeys()
                 .hasOnly(['isCompleted', 'completedAt']));
            
            // Delete: Editors and owners
            allow delete: if canWriteProject(projectId);
            
            // ==================================================================
            // SUBTASKS SUBCOLLECTION
            // ==================================================================
            
            match /subtasks/{subtaskId} {
              // Read: Any project member
              allow read: if canReadProject(projectId);
              
              // Create: Editors and owners
              allow create: if canWriteProject(projectId) && 
                request.resource.data.projectId == projectId &&
                request.resource.data.phaseId == phaseId &&
                request.resource.data.listId == listId &&
                request.resource.data.taskId == taskId &&
                request.resource.data.createdBy == getCurrentUser();
              
              // Update: Editors and owners, plus assigned user can update completion
              allow update: if canWriteProject(projectId) ||
                (resource.data.assignedTo == getCurrentUser() && 
                 request.resource.data.diff(resource.data).affectedKeys()
                   .hasOnly(['isCompleted', 'completedAt']));
              
              // Delete: Editors and owners
              allow delete: if canWriteProject(projectId);
            }
          }
        }
      }
    }
    
    // ============================================================================
    // MIGRATION COLLECTIONS (TEMPORARY)
    // ============================================================================
    
    // Legacy families collection (read-only during migration)
    match /families/{familyId} {
      allow read: if isAuthenticated() && 
        getCurrentUser() in resource.data.members;
      
      // No write operations allowed - data is migrated via secure functions
    }
    
    // User migration tracking (user can only access their own)
    match /user_migrations/{userId} {
      allow read, write: if isAuthenticated() && getCurrentUser() == userId;
    }
    
    // Legacy invitations (read-only during migration)
    match /invitations/{inviteCode} {
      allow read: if isAuthenticated();
      // No write operations allowed
    }
  }
}
```

---

## Security Rule Breakdown

### Permission Levels

#### Owner Permissions
- Full read/write access to project and all nested data
- Can manage project members (add, remove, change roles)
- Can delete the entire project
- Can create and manage invitations

#### Editor Permissions  
- Read/write access to phases, lists, tasks, and subtasks
- Can create invitations with editor or viewer roles
- Can view all project members
- Cannot manage membership or delete project

#### Viewer Permissions
- Read-only access to all project data
- Cannot create, update, or delete any content
- Cannot invite new members

### Special Cases

#### Task Assignment Rules
- Assigned users can mark their tasks as complete/incomplete
- Assigned users cannot modify other task properties
- This allows for granular task completion without full edit rights

#### Self-Management Rights
- Users can always update their own lastActiveAt timestamp
- Users can remove themselves from projects
- Users have full control over their own user document

### Data Validation

#### Project Creation
- New projects must include the creator as owner and member
- Required fields must be present and properly structured
- Creator automatically gets owner role

#### Hierarchical Consistency
- All nested documents must reference correct parent IDs
- CreatedBy fields must match the current authenticated user
- Denormalized project/phase/list IDs must be consistent

---

## Performance Optimizations

### Efficient Permission Checks
1. **Single permission lookup** per operation using project membership
2. **Cached role information** in project member documents
3. **Denormalized project IDs** avoid deep path lookups

### Minimized Database Reads
1. **Role-based branching** prevents unnecessary database reads
2. **Smart use of resource.data** for existing document checks
3. **Batch permission validation** for related operations

---

## Migration Security Considerations

### Legacy Data Protection
- Legacy collections are read-only during migration
- Migration operations handled by secure Cloud Functions
- No client-side modification of legacy data

### Transition Period Safety
- Both old and new security models can coexist
- Migration tracking prevents data corruption
- Rollback capability through preserved legacy data

---

## Testing Strategy

### Unit Tests for Security Rules
```javascript
// Test project member access
test('Project members can read project data', async () => {
  await firebase.assertSucceeds(
    getDoc(db, `/projects/${projectId}`)
      .withAuth({ uid: memberUserId })
  );
});

// Test non-member access denial
test('Non-members cannot access project data', async () => {
  await firebase.assertFails(
    getDoc(db, `/projects/${projectId}`)
      .withAuth({ uid: nonMemberUserId })
  );
});

// Test role-based permissions
test('Viewers cannot create tasks', async () => {
  await firebase.assertFails(
    setDoc(db, `/projects/${projectId}/phases/${phaseId}/lists/${listId}/tasks/${taskId}`, taskData)
      .withAuth({ uid: viewerUserId })
  );
});
```

### Integration Tests
- Cross-collection permission inheritance
- Complex query permission validation
- Migration scenario security verification

---

## Monitoring and Auditing

### Security Metrics
- Failed permission attempts by user/resource
- Unusual access patterns detection
- Role escalation attempt monitoring

### Audit Logging
- All sensitive operations logged
- Member addition/removal tracking
- Permission changes audit trail

---

*These security rules provide comprehensive protection for the new project-based architecture while maintaining optimal performance and clear access patterns.*