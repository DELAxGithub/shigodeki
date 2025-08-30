# Phase 5: Data Integrity Verification
*Shigodeki Architecture Evolution - Session 5.1*

## Verification Overview

### Verification Stages
1. **Pre-Migration Verification**: Validate source data before transformation
2. **Post-Migration Verification**: Ensure data integrity after transformation
3. **Ongoing Verification**: Continuous monitoring of data consistency

### Verification Criteria
- **Data Completeness**: All source data successfully migrated
- **Relationship Integrity**: All references and relationships preserved
- **Data Accuracy**: Transformed data matches source data semantically
- **Permission Consistency**: Access controls properly migrated

---

## Pre-Migration Verification

### Source Data Validation
```typescript
// functions/src/migration/preVerification.ts
export async function validateSourceData(userId: string): Promise<ValidationResult> {
  const db = admin.firestore();
  const issues: ValidationIssue[] = [];
  
  // Get user document
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    issues.push({ type: 'CRITICAL', message: 'User document not found' });
    return { valid: false, issues };
  }
  
  const user = userDoc.data() as User;
  
  // Validate family relationships
  for (const familyId of user.familyIds || []) {
    const familyDoc = await db.collection('families').doc(familyId).get();
    
    if (!familyDoc.exists) {
      issues.push({ 
        type: 'ERROR', 
        message: `Family ${familyId} not found`,
        context: { userId, familyId }
      });
      continue;
    }
    
    const family = familyDoc.data() as Family;
    
    // Verify user is member of family
    if (!family.members.includes(userId)) {
      issues.push({
        type: 'ERROR',
        message: `User ${userId} not in family ${familyId} members list`,
        context: { userId, familyId, members: family.members }
      });
    }
    
    // Validate task lists in family
    await validateFamilyTaskLists(familyId, issues);
  }
  
  return {
    valid: issues.filter(i => i.type === 'CRITICAL' || i.type === 'ERROR').length === 0,
    issues
  };
}

async function validateFamilyTaskLists(familyId: string, issues: ValidationIssue[]): Promise<void> {
  const db = admin.firestore();
  
  const taskListsQuery = await db.collectionGroup('taskLists')
    .where('familyId', '==', familyId)
    .get();
  
  for (const taskListDoc of taskListsQuery.docs) {
    const taskList = taskListDoc.data() as TaskList;
    
    // Validate task list creator exists
    const creatorExists = await db.collection('users').doc(taskList.createdBy).get();
    if (!creatorExists.exists) {
      issues.push({
        type: 'WARNING',
        message: `TaskList creator ${taskList.createdBy} not found`,
        context: { taskListId: taskListDoc.id, familyId }
      });
    }
    
    // Validate tasks in list
    await validateTasksInList(familyId, taskListDoc.id, issues);
  }
}
```

### Task Validation
```typescript
// functions/src/migration/taskValidation.ts
async function validateTasksInList(
  familyId: string, 
  taskListId: string, 
  issues: ValidationIssue[]
): Promise<void> {
  const db = admin.firestore();
  
  const tasksQuery = await db.collection('families')
    .doc(familyId)
    .collection('taskLists')
    .doc(taskListId)
    .collection('tasks')
    .get();
  
  for (const taskDoc of tasksQuery.docs) {
    const task = taskDoc.data() as ShigodekiTask;
    
    // Validate assigned user exists
    if (task.assignedTo) {
      const assigneeExists = await db.collection('users').doc(task.assignedTo).get();
      if (!assigneeExists.exists) {
        issues.push({
          type: 'ERROR',
          message: `Task assigned to non-existent user ${task.assignedTo}`,
          context: { taskId: taskDoc.id, taskListId, familyId }
        });
      }
    }
    
    // Validate creator exists
    const creatorExists = await db.collection('users').doc(task.createdBy).get();
    if (!creatorExists.exists) {
      issues.push({
        type: 'ERROR',
        message: `Task creator ${task.createdBy} not found`,
        context: { taskId: taskDoc.id, taskListId, familyId }
      });
    }
    
    // Validate data consistency
    if (task.isCompleted && !task.completedAt) {
      issues.push({
        type: 'WARNING',
        message: 'Completed task missing completion date',
        context: { taskId: taskDoc.id }
      });
    }
  }
}
```

---

## Post-Migration Verification

### Project Structure Verification
```typescript
// functions/src/migration/postVerification.ts
export async function verifyMigrationIntegrity(
  context: MigrationContext, 
  createdProjects: Project[]
): Promise<VerificationResult> {
  
  const issues: ValidationIssue[] = [];
  
  // Verify user document updated correctly
  await verifyUserDocumentMigration(context.userId, createdProjects, issues);
  
  // Verify each project structure
  for (const project of createdProjects) {
    await verifyProjectStructure(project, context, issues);
  }
  
  // Verify data count consistency
  await verifyDataCounts(context, createdProjects, issues);
  
  return {
    valid: issues.filter(i => i.type === 'CRITICAL' || i.type === 'ERROR').length === 0,
    issues,
    summary: generateVerificationSummary(context, createdProjects, issues)
  };
}

async function verifyUserDocumentMigration(
  userId: string, 
  projects: Project[], 
  issues: ValidationIssue[]
): Promise<void> {
  const db = admin.firestore();
  
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    issues.push({ 
      type: 'CRITICAL', 
      message: 'User document not found after migration' 
    });
    return;
  }
  
  const user = userDoc.data() as User;
  
  // Verify projectIds array
  const expectedProjectIds = projects.map(p => p.id!);
  const missingProjects = expectedProjectIds.filter(id => !user.projectIds?.includes(id));
  
  if (missingProjects.length > 0) {
    issues.push({
      type: 'ERROR',
      message: 'User missing project IDs',
      context: { userId, missingProjects }
    });
  }
  
  // Verify role assignments
  for (const project of projects) {
    if (!user.roleAssignments?.[project.id!]) {
      issues.push({
        type: 'ERROR',
        message: 'Missing role assignment for project',
        context: { userId, projectId: project.id }
      });
    }
  }
}
```

### Data Count Verification
```typescript
// functions/src/migration/countVerification.ts
async function verifyDataCounts(
  context: MigrationContext, 
  projects: Project[], 
  issues: ValidationIssue[]
): Promise<void> {
  
  // Count original data
  const originalCounts = await countOriginalData(context);
  
  // Count migrated data
  const migratedCounts = await countMigratedData(projects);
  
  // Compare counts
  if (originalCounts.families !== migratedCounts.projects) {
    issues.push({
      type: 'ERROR',
      message: 'Family to project count mismatch',
      context: { 
        originalFamilies: originalCounts.families, 
        migratedProjects: migratedCounts.projects 
      }
    });
  }
  
  if (originalCounts.taskLists !== migratedCounts.lists) {
    issues.push({
      type: 'ERROR',
      message: 'TaskList to list count mismatch',
      context: { 
        originalTaskLists: originalCounts.taskLists, 
        migratedLists: migratedCounts.lists 
      }
    });
  }
  
  if (originalCounts.tasks !== migratedCounts.tasks) {
    issues.push({
      type: 'ERROR',
      message: 'Task count mismatch',
      context: { 
        originalTasks: originalCounts.tasks, 
        migratedTasks: migratedCounts.tasks 
      }
    });
  }
}

async function countOriginalData(context: MigrationContext): Promise<DataCounts> {
  const db = admin.firestore();
  
  let taskListCount = 0;
  let taskCount = 0;
  
  for (const family of context.families) {
    const taskListsSnapshot = await db.collectionGroup('taskLists')
      .where('familyId', '==', family.id)
      .get();
    
    taskListCount += taskListsSnapshot.size;
    
    for (const taskListDoc of taskListsSnapshot.docs) {
      const tasksSnapshot = await taskListDoc.ref.collection('tasks').get();
      taskCount += tasksSnapshot.size;
    }
  }
  
  return {
    families: context.families.length,
    taskLists: taskListCount,
    tasks: taskCount
  };
}
```

---

## Real-time Verification

### Ongoing Data Monitoring
```typescript
// functions/src/migration/ongoingVerification.ts
export const dataIntegrityMonitor = functions.firestore
  .document('projects/{projectId}')
  .onWrite(async (change, context) => {
    const projectId = context.params.projectId;
    
    // Run integrity checks
    const issues = await runProjectIntegrityCheck(projectId);
    
    if (issues.length > 0) {
      await reportIntegrityIssues(projectId, issues);
    }
  });

async function runProjectIntegrityCheck(projectId: string): Promise<ValidationIssue[]> {
  const db = admin.firestore();
  const issues: ValidationIssue[] = [];
  
  // Get project
  const projectDoc = await db.collection('projects').doc(projectId).get();
  if (!projectDoc.exists) return issues;
  
  const project = projectDoc.data() as Project;
  
  // Verify all members have user documents
  for (const memberId of project.memberIds) {
    const memberDoc = await db.collection('users').doc(memberId).get();
    if (!memberDoc.exists) {
      issues.push({
        type: 'ERROR',
        message: `Project member ${memberId} does not exist`,
        context: { projectId, memberId }
      });
    }
  }
  
  // Verify owner is in members list
  if (!project.memberIds.includes(project.ownerId)) {
    issues.push({
      type: 'ERROR',
      message: 'Project owner not in members list',
      context: { projectId, ownerId: project.ownerId }
    });
  }
  
  return issues;
}
```

---

## Client-Side Verification

### Migration Verification UI
```swift
// iOS/shigodeki/Migration/VerificationView.swift
struct MigrationVerificationView: View {
    @State private var verificationResults: VerificationResults?
    @State private var isVerifying = false
    
    var body: some View {
        VStack(spacing: 20) {
            if isVerifying {
                ProgressView("データ整合性を確認中...")
            } else if let results = verificationResults {
                VerificationResultsView(results: results)
            } else {
                Button("データ整合性を確認") {
                    Task {
                        await runVerification()
                    }
                }
            }
        }
        .padding()
    }
    
    private func runVerification() async {
        isVerifying = true
        
        // Run client-side verification checks
        let results = await MigrationVerificationService.shared.verifyMigration()
        
        verificationResults = results
        isVerifying = false
    }
}
```

---

*これらの検証手順により、移行されたデータの完全性と一貫性を保証し、問題の早期発見と修正を可能にします。*