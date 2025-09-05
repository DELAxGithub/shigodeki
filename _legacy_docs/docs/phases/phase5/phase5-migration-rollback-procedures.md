# Phase 5: Migration Rollback Procedures
*Shigodeki Architecture Evolution - Session 5.1*

## Rollback Strategy Overview

### Rollback Triggers
- Migration failure at any stage
- Data integrity check failure
- User-reported issues within 24 hours
- System performance degradation

### Rollback Capabilities
- **Individual User Rollback**: Restore single user to pre-migration state
- **Batch Rollback**: Restore multiple users simultaneously
- **Complete Rollback**: Revert entire migration if critical issues arise

---

## Cloud Function Rollback Implementation

### Main Rollback Function
```typescript
// functions/src/migration/rollback.ts
export const userRollback = functions.https.onCall(async (data, context) => {
  const { userId, migrationId } = data;
  
  // Verify admin access or self-rollback
  if (!context.auth || (context.auth.uid !== userId && !isAdmin(context.auth.uid))) {
    throw new functions.https.HttpsError('permission-denied', 'Unauthorized rollback request');
  }
  
  try {
    await rollbackUser(userId, migrationId);
    return { success: true, message: 'User successfully rolled back' };
  } catch (error) {
    console.error(`Rollback failed for user ${userId}:`, error);
    throw new functions.https.HttpsError('internal', 'Rollback operation failed');
  }
});

export async function rollbackUser(userId: string, migrationId?: string): Promise<void> {
  const migrationRecord = await getMigrationRecord(userId);
  
  if (!migrationRecord) {
    throw new Error('No migration record found for rollback');
  }
  
  // Use provided migrationId or get from record
  const targetMigrationId = migrationId || migrationRecord.migrationId;
  
  // Step 1: Restore user data from backup
  await restoreUserFromBackup(userId, targetMigrationId);
  
  // Step 2: Remove created projects
  await cleanupCreatedProjects(migrationRecord.createdProjects);
  
  // Step 3: Restore family memberships
  await restoreFamilyMemberships(userId, migrationRecord.originalFamilies);
  
  // Step 4: Update migration status
  await updateMigrationStatus(userId, 'rolled_back', {
    rolledBackAt: new Date(),
    rolledBackBy: 'system'
  });
  
  console.log(`Successfully rolled back user ${userId}`);
}
```

### Backup Restoration
```typescript
// functions/src/migration/backupRestoration.ts
export async function restoreUserFromBackup(userId: string, migrationId: string): Promise<void> {
  const db = admin.firestore();
  
  // Get backup data
  const backupDoc = await db.collection('migration_backups')
    .doc(`${userId}_${migrationId}`)
    .get();
  
  if (!backupDoc.exists) {
    throw new Error(`Backup not found: ${userId}_${migrationId}`);
  }
  
  const backupData = backupDoc.data()!;
  
  // Restore user document
  await db.collection('users').doc(userId).set(backupData.user);
  
  // Restore families
  const batch = db.batch();
  
  for (const family of backupData.families) {
    const familyRef = db.collection('families').doc(family.id);
    batch.set(familyRef, family);
  }
  
  await batch.commit();
  
  console.log(`Restored user ${userId} from backup ${migrationId}`);
}
```

---

## Project Cleanup Procedures

### Remove Created Projects
```typescript
// functions/src/migration/projectCleanup.ts
export async function cleanupCreatedProjects(projectIds: string[]): Promise<void> {
  const db = admin.firestore();
  
  for (const projectId of projectIds) {
    await deleteProjectCompletely(projectId);
  }
}

async function deleteProjectCompletely(projectId: string): Promise<void> {
  const db = admin.firestore();
  const projectRef = db.collection('projects').doc(projectId);
  
  // Delete all subcollections
  await deleteSubcollection(projectRef, 'members');
  await deleteSubcollection(projectRef, 'invitations');
  await deletePhaseHierarchy(projectRef);
  
  // Delete project document
  await projectRef.delete();
}

async function deletePhaseHierarchy(projectRef: FirebaseFirestore.DocumentReference): Promise<void> {
  const phasesSnapshot = await projectRef.collection('phases').get();
  
  for (const phaseDoc of phasesSnapshot.docs) {
    const phaseRef = phaseDoc.ref;
    
    // Delete lists and their tasks/subtasks
    const listsSnapshot = await phaseRef.collection('lists').get();
    
    for (const listDoc of listsSnapshot.docs) {
      const listRef = listDoc.ref;
      
      // Delete tasks and subtasks
      const tasksSnapshot = await listRef.collection('tasks').get();
      
      for (const taskDoc of tasksSnapshot.docs) {
        const taskRef = taskDoc.ref;
        await deleteSubcollection(taskRef, 'subtasks');
        await taskRef.delete();
      }
      
      await listRef.delete();
    }
    
    await phaseRef.delete();
  }
}
```

---

## Family Membership Restoration

### Restore User-Family Relationships
```typescript
// functions/src/migration/familyRestoration.ts
export async function restoreFamilyMemberships(userId: string, familyIds: string[]): Promise<void> {
  const db = admin.firestore();
  
  // Ensure user is added back to all original families
  for (const familyId of familyIds) {
    const familyRef = db.collection('families').doc(familyId);
    
    try {
      await familyRef.update({
        members: admin.firestore.FieldValue.arrayUnion(userId)
      });
    } catch (error) {
      console.warn(`Could not restore user ${userId} to family ${familyId}:`, error);
    }
  }
  
  // Update user's familyIds array
  await db.collection('users').doc(userId).update({
    familyIds: familyIds,
    // Remove project-related fields
    projectIds: admin.firestore.FieldValue.delete(),
    roleAssignments: admin.firestore.FieldValue.delete()
  });
}
```

---

## Client-Side Rollback Support

### Rollback Request Handler
```swift
// iOS/shigodeki/Migration/RollbackService.swift
class RollbackService {
    private let functions = Functions.functions()
    
    func requestUserRollback() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw MigrationError.notAuthenticated
        }
        
        let rollbackFunction = functions.httpsCallable("userRollback")
        
        do {
            _ = try await rollbackFunction.call(["userId": userId])
        } catch {
            throw MigrationError.rollbackFailed(error.localizedDescription)
        }
    }
    
    func checkRollbackEligibility() async -> Bool {
        // Check if user can still rollback (within time window, etc.)
        return true // Implementation depends on business rules
    }
}
```

### Rollback UI
```swift
// iOS/shigodeki/Migration/RollbackPromptView.swift
struct RollbackPromptView: View {
    let onConfirm: () async -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("以前のバージョンに戻す")
                .font(.headline)
            
            Text("新機能で問題が発生した場合、以前の家族ベースのシステムに戻すことができます。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Text("⚠️ 注意: 新機能で作成したデータは失われます")
                .font(.caption)
                .foregroundColor(.red)
                .padding()
                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            
            HStack(spacing: 16) {
                Button("キャンセル") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("戻す") {
                    Task {
                        await onConfirm()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding()
    }
}
```

---

## Monitoring and Alerts

### Rollback Monitoring
```typescript
// functions/src/migration/rollbackMonitoring.ts
export const rollbackMonitor = functions.firestore
  .document('user_migrations/{userId}')
  .onUpdate(async (change, context) => {
    const after = change.after.data();
    
    if (after.status === 'rolled_back') {
      await sendRollbackAlert(context.params.userId, after);
      await updateRollbackMetrics();
    }
  });

async function sendRollbackAlert(userId: string, migrationData: any): Promise<void> {
  console.log(`ALERT: User ${userId} rolled back migration`, {
    migrationId: migrationData.migrationId,
    originalError: migrationData.error,
    rolledBackAt: migrationData.rolledBackAt
  });
}
```

---

*これらの手順により、問題が発生した場合でもユーザーデータを安全に以前の状態に復元できます。*