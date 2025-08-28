# Phase 5: Migration Technical Implementation Plan
*Shigodeki Architecture Evolution - Session 5.1*

## Technical Architecture

### Cloud Functions Migration Engine

#### 1. Migration Orchestrator Function
```typescript
// functions/src/migration/orchestrator.ts
export const migrationOrchestrator = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  // Validate user authentication
  if (!context.auth || context.auth.uid !== userId) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  try {
    // Start migration transaction
    const migrationResult = await migrateUser(userId);
    return { success: true, result: migrationResult };
  } catch (error) {
    // Log error and initiate rollback
    console.error(`Migration failed for user ${userId}:`, error);
    await rollbackUser(userId);
    throw new functions.https.HttpsError('internal', 'Migration failed');
  }
});
```

#### 2. User Migration Function
```typescript
// functions/src/migration/userMigration.ts
interface MigrationContext {
  userId: string;
  userDoc: User;
  families: Family[];
  migrationId: string;
}

export async function migrateUser(userId: string): Promise<MigrationResult> {
  const migrationId = generateMigrationId();
  
  // 1. Create migration tracking record
  await createMigrationRecord(userId, migrationId);
  
  // 2. Load user's current data
  const context = await loadUserMigrationContext(userId);
  
  // 3. Create backup
  await createUserBackup(context);
  
  // 4. Transform families to projects
  const projects = await transformFamiliesToProjects(context);
  
  // 5. Update user record
  await updateUserForNewArchitecture(context, projects);
  
  // 6. Verify migration integrity
  await verifyMigrationIntegrity(context, projects);
  
  // 7. Mark migration as complete
  await completeMigration(userId, migrationId);
  
  return { userId, projectCount: projects.length, migrationId };
}
```

### Data Transformation Logic

#### 1. Family to Project Conversion
```typescript
// functions/src/migration/familyTransformation.ts
export async function transformFamiliesToProjects(context: MigrationContext): Promise<Project[]> {
  const projects: Project[] = [];
  
  for (const family of context.families) {
    // Create project from family
    const project: Project = {
      id: generateProjectId(),
      name: family.name || `${family.name}のプロジェクト`,
      description: `${family.name}から移行されました`,
      ownerId: determineProjectOwner(family, context.userId),
      memberIds: family.members,
      createdAt: family.createdAt,
      lastModifiedAt: new Date(),
      isArchived: false,
      migratedFromFamily: family.id
    };
    
    // Create default phase
    const defaultPhase = createDefaultPhase(project.id, context.userId);
    
    // Transform task lists
    const taskLists = await transformTaskLists(family.id, defaultPhase.id, project.id);
    
    // Create project structure
    await createProjectStructure(project, defaultPhase, taskLists);
    
    projects.push(project);
  }
  
  return projects;
}

function determineProjectOwner(family: Family, currentUserId: string): string {
  // Current user becomes owner if they're in the family
  if (family.members.includes(currentUserId)) {
    return currentUserId;
  }
  
  // Otherwise, first member becomes owner
  return family.members[0] || currentUserId;
}
```

#### 2. Task List and Task Migration
```typescript
// functions/src/migration/taskTransformation.ts
export async function transformTaskLists(
  familyId: string, 
  phaseId: string, 
  projectId: string
): Promise<TransformedList[]> {
  
  const taskLists = await getTaskListsByFamily(familyId);
  const transformedLists: TransformedList[] = [];
  
  for (const [index, taskList] of taskLists.entries()) {
    // Transform task list to new structure
    const newList: TaskList = {
      ...taskList,
      phaseId,
      projectId,
      order: index,
      // Remove familyId, add hierarchy fields
    };
    
    // Transform tasks within the list
    const tasks = await getTasksByList(taskList.id!);
    const transformedTasks = await transformTasks(tasks, taskList.id!, phaseId, projectId);
    
    transformedLists.push({
      list: newList,
      tasks: transformedTasks
    });
  }
  
  return transformedLists;
}

async function transformTasks(
  tasks: ShigodekiTask[], 
  listId: string, 
  phaseId: string, 
  projectId: string
): Promise<ShigodekiTask[]> {
  
  return tasks.map((task, index) => ({
    ...task,
    listId,
    phaseId,
    projectId,
    order: index,
    hasSubtasks: false,
    subtaskCount: 0,
    completedSubtaskCount: 0,
    tags: []
  }));
}
```

### Migration State Management

#### 1. Migration Tracking System
```typescript
// functions/src/migration/tracking.ts
interface MigrationRecord {
  userId: string;
  migrationId: string;
  status: 'pending' | 'in_progress' | 'completed' | 'failed' | 'rolled_back';
  startedAt: Date;
  completedAt?: Date;
  
  originalFamilies: string[];
  createdProjects: string[];
  
  backupLocation: string;
  
  error?: {
    stage: string;
    message: string;
    timestamp: Date;
  };
}

export async function createMigrationRecord(userId: string, migrationId: string): Promise<void> {
  const record: MigrationRecord = {
    userId,
    migrationId,
    status: 'pending',
    startedAt: new Date(),
    originalFamilies: [],
    createdProjects: [],
    backupLocation: `backups/${userId}/${migrationId}`
  };
  
  await admin.firestore()
    .collection('user_migrations')
    .doc(userId)
    .set(record);
}
```

#### 2. Backup System
```typescript
// functions/src/migration/backup.ts
export async function createUserBackup(context: MigrationContext): Promise<void> {
  const backupData = {
    user: context.userDoc,
    families: context.families,
    timestamp: new Date(),
    migrationId: context.migrationId
  };
  
  // Store backup in secure location
  await admin.firestore()
    .collection('migration_backups')
    .doc(`${context.userId}_${context.migrationId}`)
    .set(backupData);
  
  // Also store in Cloud Storage for redundancy
  const bucket = admin.storage().bucket();
  const backupFile = bucket.file(`migration-backups/${context.userId}/${context.migrationId}.json`);
  
  await backupFile.save(JSON.stringify(backupData, null, 2), {
    metadata: { contentType: 'application/json' }
  });
}
```

### Client-Side Compatibility Layer

#### 1. Data Access Abstraction
```swift
// iOS/shigodeki/Migration/DataCompatibilityLayer.swift
@MainActor
class DataCompatibilityLayer: ObservableObject {
    @Published var isMigrated: Bool = false
    @Published var migrationInProgress: Bool = false
    
    private let familyManager = FamilyManager()
    private let projectManager = ProjectManager()
    
    func loadUserData() async {
        // Check user migration status
        let migrationStatus = await checkMigrationStatus()
        
        switch migrationStatus {
        case .notMigrated:
            isMigrated = false
            await familyManager.loadFamilies()
        case .migrated:
            isMigrated = true
            await projectManager.loadProjects()
        case .inProgress:
            migrationInProgress = true
            // Show migration UI
        }
    }
    
    func initiateUserMigration() async throws {
        migrationInProgress = true
        
        // Call Cloud Function for migration
        let functions = Functions.functions()
        let migrateUser = functions.httpsCallable("migrationOrchestrator")
        
        do {
            let result = try await migrateUser.call(["userId": Auth.auth().currentUser?.uid])
            
            // Migration successful - reload data
            await loadUserData()
            migrationInProgress = false
        } catch {
            migrationInProgress = false
            throw error
        }
    }
}
```

#### 2. UI Compatibility Bridge
```swift
// iOS/shigodeki/Migration/UICompatibilityBridge.swift
struct MainContentView: View {
    @StateObject private var compatibilityLayer = DataCompatibilityLayer()
    
    var body: some View {
        Group {
            if compatibilityLayer.migrationInProgress {
                MigrationProgressView()
            } else if compatibilityLayer.isMigrated {
                // New project-based UI
                ProjectBasedMainView()
            } else {
                // Legacy family-based UI
                FamilyBasedMainView()
                    .migrationPrompt(isPresented: $showMigrationPrompt) {
                        Task {
                            try await compatibilityLayer.initiateUserMigration()
                        }
                    }
            }
        }
        .onAppear {
            Task {
                await compatibilityLayer.loadUserData()
            }
        }
    }
}
```

### Error Handling and Recovery

#### 1. Migration Error Types
```typescript
// functions/src/migration/errors.ts
export enum MigrationErrorType {
  DATA_LOAD_FAILED = 'data_load_failed',
  BACKUP_CREATION_FAILED = 'backup_creation_failed',
  PROJECT_CREATION_FAILED = 'project_creation_failed',
  USER_UPDATE_FAILED = 'user_update_failed',
  INTEGRITY_CHECK_FAILED = 'integrity_check_failed'
}

export class MigrationError extends Error {
  constructor(
    public type: MigrationErrorType,
    public stage: string,
    message: string,
    public originalError?: Error
  ) {
    super(message);
    this.name = 'MigrationError';
  }
}
```

#### 2. Rollback Mechanism
```typescript
// functions/src/migration/rollback.ts
export async function rollbackUser(userId: string): Promise<void> {
  const migrationRecord = await getMigrationRecord(userId);
  
  if (!migrationRecord) {
    throw new Error('No migration record found for rollback');
  }
  
  try {
    // 1. Restore from backup
    await restoreUserFromBackup(userId, migrationRecord.migrationId);
    
    // 2. Clean up partially created projects
    await cleanupPartialMigration(migrationRecord.createdProjects);
    
    // 3. Update migration status
    await updateMigrationStatus(userId, 'rolled_back');
    
    console.log(`Successfully rolled back user ${userId}`);
  } catch (error) {
    console.error(`Rollback failed for user ${userId}:`, error);
    throw error;
  }
}
```

---

## Implementation Phases

### Phase 1: Infrastructure Setup
1. Deploy Cloud Functions for migration
2. Set up backup systems
3. Create migration tracking collections
4. Implement client-side compatibility layer

### Phase 2: Testing and Validation
1. Test migration with synthetic data
2. Validate rollback procedures
3. Performance testing under load
4. Security rule validation

### Phase 3: Staged Rollout
1. Internal team migration (dog-fooding)
2. Limited beta user migration
3. Gradual expansion to all users
4. Monitor and optimize throughout

---

*This technical plan provides the detailed implementation approach for safe, reliable migration to the new project-based architecture.*