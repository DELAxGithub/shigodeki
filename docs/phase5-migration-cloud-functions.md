# Phase 5: Migration Cloud Functions
*Shigodeki Architecture Evolution - Session 5.1*

## Cloud Functions Architecture

### Function Overview

#### 1. Migration Orchestrator
**Purpose**: Main entry point for user migration
**Trigger**: HTTPS Callable
**Security**: User authentication required

```typescript
// functions/src/migration/orchestrator.ts
export const migrationOrchestrator = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  if (!context.auth || context.auth.uid !== userId) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  try {
    const migrationResult = await migrateUser(userId);
    return { success: true, result: migrationResult };
  } catch (error) {
    await rollbackUser(userId);
    throw new functions.https.HttpsError('internal', 'Migration failed');
  }
});
```

#### 2. Batch Migration Processor
**Purpose**: Process multiple users in batches
**Trigger**: Pub/Sub scheduled
**Security**: Admin only

```typescript
// functions/src/migration/batchProcessor.ts
export const batchMigrationProcessor = functions.pubsub
  .schedule('0 2 * * *') // Daily at 2 AM
  .onRun(async (context) => {
    const pendingUsers = await getPendingMigrationUsers();
    const batchSize = 10;
    
    for (let i = 0; i < pendingUsers.length; i += batchSize) {
      const batch = pendingUsers.slice(i, i + batchSize);
      await Promise.allSettled(
        batch.map(userId => migrateUser(userId))
      );
      
      // Wait between batches to avoid rate limits
      await sleep(1000);
    }
  });
```

#### 3. Migration Status Monitor
**Purpose**: Monitor migration progress and handle failures
**Trigger**: Firestore document changes
**Security**: System triggered

```typescript
// functions/src/migration/monitor.ts
export const migrationMonitor = functions.firestore
  .document('user_migrations/{userId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Handle status changes
    if (before.status !== after.status) {
      await handleStatusChange(context.params.userId, before.status, after.status);
    }
    
    // Handle failed migrations
    if (after.status === 'failed') {
      await scheduleRetry(context.params.userId);
    }
  });
```

---

## Core Migration Functions

### User Migration Function
```typescript
// functions/src/migration/userMigration.ts
export async function migrateUser(userId: string): Promise<MigrationResult> {
  const migrationId = generateMigrationId();
  
  try {
    // Step 1: Initialize
    await createMigrationRecord(userId, migrationId);
    
    // Step 2: Load data
    const context = await loadUserMigrationContext(userId);
    
    // Step 3: Create backup
    await createUserBackup(context);
    
    // Step 4: Transform data
    const projects = await transformFamiliesToProjects(context);
    
    // Step 5: Update user
    await updateUserForNewArchitecture(context, projects);
    
    // Step 6: Verify
    await verifyMigrationIntegrity(context, projects);
    
    // Step 7: Complete
    await completeMigration(userId, migrationId);
    
    return { userId, projectCount: projects.length, migrationId };
    
  } catch (error) {
    await handleMigrationError(userId, migrationId, error);
    throw error;
  }
}
```

### Context Loading
```typescript
// functions/src/migration/contextLoader.ts
interface MigrationContext {
  userId: string;
  userDoc: User;
  families: Family[];
  migrationId: string;
}

export async function loadUserMigrationContext(userId: string): Promise<MigrationContext> {
  const db = admin.firestore();
  
  // Load user document
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throw new Error(`User ${userId} not found`);
  }
  
  // Load user's families
  const user = userDoc.data() as User;
  const familyPromises = user.familyIds.map(familyId => 
    db.collection('families').doc(familyId).get()
  );
  
  const familyDocs = await Promise.all(familyPromises);
  const families = familyDocs
    .filter(doc => doc.exists)
    .map(doc => ({ id: doc.id, ...doc.data() } as Family));
  
  return {
    userId,
    userDoc: { id: userDoc.id, ...user },
    families,
    migrationId: generateMigrationId()
  };
}
```

---

## Data Transformation Functions

### Family to Project Transformation
```typescript
// functions/src/migration/familyTransformation.ts
export async function transformFamiliesToProjects(context: MigrationContext): Promise<Project[]> {
  const projects: Project[] = [];
  
  for (const family of context.families) {
    const project = await createProjectFromFamily(family, context.userId);
    const defaultPhase = await createDefaultPhase(project.id!, context.userId);
    await migrateTaskListsToPhase(family.id!, defaultPhase.id!, project.id!);
    
    projects.push(project);
  }
  
  return projects;
}

async function createProjectFromFamily(family: Family, currentUserId: string): Promise<Project> {
  const db = admin.firestore();
  
  const project: Project = {
    name: family.name || `${family.name}のプロジェクト`,
    description: `${family.name}から移行されました`,
    ownerId: determineProjectOwner(family, currentUserId),
    memberIds: family.members,
    createdAt: family.createdAt || new Date(),
    lastModifiedAt: new Date(),
    isArchived: false,
    migratedFromFamily: family.id
  };
  
  const projectRef = await db.collection('projects').add(project);
  
  // Create member documents
  await createProjectMembers(projectRef.id, family.members, project.ownerId);
  
  return { id: projectRef.id, ...project };
}
```

### Task List Migration
```typescript
// functions/src/migration/taskListMigration.ts
export async function migrateTaskListsToPhase(
  familyId: string, 
  phaseId: string, 
  projectId: string
): Promise<void> {
  const db = admin.firestore();
  
  // Get all task lists for this family
  const taskListsQuery = await db.collectionGroup('taskLists')
    .where('familyId', '==', familyId)
    .get();
  
  const batch = db.batch();
  
  for (const [index, taskListDoc] of taskListsQuery.docs.entries()) {
    const taskList = taskListDoc.data() as TaskList;
    
    // Create new list in phase
    const newListRef = db.collection('projects')
      .doc(projectId)
      .collection('phases')
      .doc(phaseId)
      .collection('lists')
      .doc();
    
    const updatedList: TaskList = {
      ...taskList,
      phaseId,
      projectId,
      order: index
    };
    
    batch.set(newListRef, updatedList);
    
    // Migrate tasks for this list
    await migrateTasksForList(taskListDoc.id, newListRef.id, phaseId, projectId);
  }
  
  await batch.commit();
}
```

---

## Error Handling

### Migration Error Handler
```typescript
// functions/src/migration/errorHandler.ts
export async function handleMigrationError(
  userId: string, 
  migrationId: string, 
  error: any
): Promise<void> {
  console.error(`Migration failed for user ${userId}:`, error);
  
  // Update migration record with error
  await admin.firestore()
    .collection('user_migrations')
    .doc(userId)
    .update({
      status: 'failed',
      error: {
        stage: error.stage || 'unknown',
        message: error.message,
        timestamp: new Date()
      }
    });
  
  // Send alert to monitoring system
  await sendMigrationAlert(userId, error);
}

async function sendMigrationAlert(userId: string, error: any): Promise<void> {
  // Implementation for alerting system
  // Could be Slack, email, monitoring service, etc.
  console.log(`ALERT: Migration failed for user ${userId}`, error);
}
```

### Retry Logic
```typescript
// functions/src/migration/retryHandler.ts
export async function scheduleRetry(userId: string): Promise<void> {
  const migrationRecord = await getMigrationRecord(userId);
  
  if (!migrationRecord) return;
  
  // Exponential backoff: 1h, 4h, 16h, then manual
  const retryDelays = [3600, 14400, 57600]; // seconds
  const currentRetries = migrationRecord.retryCount || 0;
  
  if (currentRetries < retryDelays.length) {
    const delay = retryDelays[currentRetries];
    
    // Schedule retry using Cloud Tasks
    await scheduleDelayedMigration(userId, delay);
    
    // Update retry count
    await admin.firestore()
      .collection('user_migrations')
      .doc(userId)
      .update({
        retryCount: currentRetries + 1,
        nextRetryAt: new Date(Date.now() + delay * 1000)
      });
  }
}
```

---

## Utility Functions

### ID Generation
```typescript
// functions/src/migration/utils.ts
export function generateMigrationId(): string {
  return `migration_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

export function generateProjectId(): string {
  return admin.firestore().collection('projects').doc().id;
}
```

### Batch Operations
```typescript
// functions/src/migration/batchUtils.ts
export async function batchWrite(operations: BatchOperation[]): Promise<void> {
  const db = admin.firestore();
  const batchSize = 500; // Firestore batch limit
  
  for (let i = 0; i < operations.length; i += batchSize) {
    const batch = db.batch();
    const batchOps = operations.slice(i, i + batchSize);
    
    batchOps.forEach(op => {
      switch (op.type) {
        case 'set':
          batch.set(op.ref, op.data);
          break;
        case 'update':
          batch.update(op.ref, op.data);
          break;
        case 'delete':
          batch.delete(op.ref);
          break;
      }
    });
    
    await batch.commit();
  }
}
```

---

## Deployment Configuration

### functions/package.json
```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.0.0",
    "typescript": "^5.0.0"
  },
  "engines": {
    "node": "18"
  }
}
```

### functions/src/index.ts
```typescript
export { migrationOrchestrator } from './migration/orchestrator';
export { batchMigrationProcessor } from './migration/batchProcessor';
export { migrationMonitor } from './migration/monitor';
```

---

*These Cloud Functions provide secure, scalable server-side migration with comprehensive error handling and monitoring.*