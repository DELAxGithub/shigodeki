# Firebase 移行技術実装計画

Phase 4からPhase 5への包括的データ移行とアーキテクチャ変換の技術実装仕様です。

## 🔗 関連情報

- 📊 [データモデル設計](./data-model.md) - 新旧データ構造比較
- 🔄 [Phase5移行概要](./phase5-migration-overview.md) - 移行戦略全体像  
- 🛡️ [セキュリティルール](./security-rules.md) - 移行時セキュリティ考慮

---

# Phase 5: 移行技術実装計画

**セッション**: 5.1 - シゴデキアーキテクチャ進化  
**目的**: ファミリーベースからプロジェクトベースへの安全で効率的な完全移行

## 技術アーキテクチャ

### Cloud Functions 移行エンジン

#### 1. 移行オーケストレーター関数

```typescript
// functions/src/migration/orchestrator.ts
export const migrationOrchestrator = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  // ユーザー認証検証
  if (!context.auth || context.auth.uid !== userId) {
    throw new functions.https.HttpsError('unauthenticated', 'ユーザー認証が必要です');
  }
  
  try {
    // 移行トランザクション開始
    const migrationResult = await migrateUser(userId);
    return { success: true, result: migrationResult };
  } catch (error) {
    // エラーログ記録とロールバック開始
    console.error(`ユーザー ${userId} の移行失敗:`, error);
    await rollbackUser(userId);
    throw new functions.https.HttpsError('internal', '移行に失敗しました');
  }
});

// バッチ移行用関数
export const batchMigration = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    // 移行待ちユーザーの段階的処理
    const pendingUsers = await getPendingMigrationUsers();
    
    for (const user of pendingUsers) {
      try {
        await migrateUser(user.id);
      } catch (error) {
        // 個別エラーログ、全体は継続
        console.error(`バッチ移行エラー - ユーザー: ${user.id}`, error);
      }
    }
  });
```

#### 2. ユーザー移行関数

```typescript
// functions/src/migration/userMigration.ts
interface MigrationContext {
  userId: string;
  userDoc: User;
  families: Family[];
  migrationId: string;
  timestamp: Date;
}

interface MigrationResult {
  userId: string;
  projectCount: number;
  migrationId: string;
  duration: number;
  dataIntegrityScore: number;
}

export async function migrateUser(userId: string): Promise<MigrationResult> {
  const startTime = Date.now();
  const migrationId = generateMigrationId();
  
  try {
    // 1. 移行追跡レコード作成
    await createMigrationRecord(userId, migrationId);
    
    // 2. ユーザーの現在データ読み込み
    const context = await loadUserMigrationContext(userId, migrationId);
    
    // 3. バックアップ作成
    await createUserBackup(context);
    
    // 4. ファミリーをプロジェクトに変換
    const projects = await transformFamiliesToProjects(context);
    
    // 5. ユーザーレコード更新
    await updateUserForNewArchitecture(context, projects);
    
    // 6. 移行整合性検証
    const integrityScore = await verifyMigrationIntegrity(context, projects);
    
    // 7. 移行完了マーク
    await completeMigration(userId, migrationId);
    
    const duration = Date.now() - startTime;
    
    return { 
      userId, 
      projectCount: projects.length, 
      migrationId,
      duration,
      dataIntegrityScore: integrityScore
    };
  } catch (error) {
    // 移行失敗時の詳細ログ
    await logMigrationFailure(userId, migrationId, error);
    throw error;
  }
}

async function loadUserMigrationContext(userId: string, migrationId: string): Promise<MigrationContext> {
  const userDoc = await getUserDocument(userId);
  if (!userDoc) {
    throw new Error(`ユーザードキュメントが見つかりません: ${userId}`);
  }
  
  // ユーザーの全ファミリー読み込み
  const families = await getFamiliesByUser(userId);
  
  return {
    userId,
    userDoc,
    families,
    migrationId,
    timestamp: new Date()
  };
}
```

### データ変換ロジック

#### 1. ファミリーからプロジェクトへの変換

```typescript
// functions/src/migration/familyTransformation.ts
export async function transformFamiliesToProjects(context: MigrationContext): Promise<Project[]> {
  const projects: Project[] = [];
  
  for (const family of context.families) {
    // ファミリーからプロジェクト作成
    const project: Project = {
      id: generateProjectId(),
      name: family.name || `${context.userDoc.name}のプロジェクト`,
      description: `ファミリー "${family.name}" から移行されました`,
      ownerId: determineProjectOwner(family, context.userId),
      memberIds: family.members || [context.userId],
      createdAt: family.createdAt || new Date(),
      lastModifiedAt: new Date(),
      isArchived: false,
      migratedFromFamily: family.id,
      settings: {
        isPublic: false,
        allowGuestAccess: false,
        taskAutoArchiveDays: 30
      }
    };
    
    // デフォルトフェーズ作成
    const defaultPhase = createDefaultPhase(project.id, context.userId);
    
    // タスクリスト変換
    const taskLists = await transformTaskLists(family.id, defaultPhase.id, project.id);
    
    // プロジェクト構造作成
    await createProjectStructure(project, defaultPhase, taskLists);
    
    // プロジェクトメンバー作成
    await createProjectMembers(project, family.members || []);
    
    projects.push(project);
  }
  
  return projects;
}

function determineProjectOwner(family: Family, currentUserId: string): string {
  // 現在のユーザーがファミリーにいる場合、所有者になる
  if (family.members && family.members.includes(currentUserId)) {
    return currentUserId;
  }
  
  // そうでなければ、最初のメンバーが所有者
  return family.members?.[0] || currentUserId;
}

async function createProjectMembers(project: Project, memberIds: string[]): Promise<void> {
  const batch = admin.firestore().batch();
  
  for (const memberId of memberIds) {
    const memberRef = admin.firestore()
      .collection('projects')
      .doc(project.id)
      .collection('members')
      .doc(memberId);
    
    const member: ProjectMember = {
      id: memberId,
      userId: memberId,
      projectId: project.id,
      role: memberId === project.ownerId ? 'owner' : 'editor',
      joinedAt: new Date(),
      lastActiveAt: new Date(),
      invitedBy: project.ownerId
    };
    
    batch.set(memberRef, member);
  }
  
  await batch.commit();
}
```

#### 2. タスクリストとタスクの移行

```typescript
// functions/src/migration/taskTransformation.ts
interface TransformedList {
  list: TaskList;
  tasks: ShigodekiTask[];
  subtasks: Subtask[];
}

export async function transformTaskLists(
  familyId: string, 
  phaseId: string, 
  projectId: string
): Promise<TransformedList[]> {
  
  const taskLists = await getTaskListsByFamily(familyId);
  const transformedLists: TransformedList[] = [];
  
  for (const [index, taskList] of taskLists.entries()) {
    // タスクリストを新構造に変換
    const newList: TaskList = {
      ...taskList,
      phaseId,
      projectId,
      order: index,
      isArchived: taskList.isArchived || false,
      color: taskList.color || 'blue'
    };
    
    // リスト内のタスク変換
    const tasks = await getTasksByList(taskList.id!);
    const transformedTasks = await transformTasks(tasks, taskList.id!, phaseId, projectId);
    
    // サブタスク生成（複雑なタスクの場合）
    const subtasks = await generateSubtasksFromTasks(transformedTasks, projectId, phaseId, taskList.id!);
    
    transformedLists.push({
      list: newList,
      tasks: transformedTasks,
      subtasks
    });
  }
  
  return transformedLists;
}

async function transformTasks(
  tasks: LegacyTask[], 
  listId: string, 
  phaseId: string, 
  projectId: string
): Promise<ShigodekiTask[]> {
  
  return tasks.map((task, index) => ({
    ...task,
    projectId,
    phaseId,
    listId,
    order: index,
    // 新機能のデフォルト値
    priority: inferTaskPriority(task),
    tags: extractTagsFromDescription(task.description || ''),
    estimatedHours: null,
    actualHours: null,
    assignedTo: null,
    dueDate: null
  }));
}

function inferTaskPriority(task: LegacyTask): TaskPriority | undefined {
  const description = (task.description || '').toLowerCase();
  
  if (description.includes('緊急') || description.includes('urgent')) {
    return 'urgent';
  }
  if (description.includes('重要') || description.includes('high')) {
    return 'high';
  }
  if (description.includes('低') || description.includes('low')) {
    return 'low';
  }
  
  return 'medium'; // デフォルト
}

function extractTagsFromDescription(description: string): string[] {
  // #タグ 形式のタグを抽出
  const tagRegex = /#([\\w\\u3040-\\u309F\\u30A0-\\u30FF\\u4E00-\\u9FAF]+)/g;
  const tags: string[] = [];
  let match;
  
  while ((match = tagRegex.exec(description)) !== null) {
    tags.push(match[1]);
  }
  
  return tags;
}
```

#### 3. データ整合性検証

```typescript
// functions/src/migration/dataIntegrityVerification.ts
export async function verifyMigrationIntegrity(
  context: MigrationContext, 
  projects: Project[]
): Promise<number> {
  
  const checks: IntegrityCheck[] = [];
  
  // 1. データ量整合性チェック
  checks.push(await verifyDataVolume(context, projects));
  
  // 2. 関係整合性チェック  
  checks.push(await verifyRelationships(context, projects));
  
  // 3. ユーザーアクセス整合性チェック
  checks.push(await verifyUserAccess(context, projects));
  
  // 4. データ完全性チェック
  checks.push(await verifyDataCompleteness(context, projects));
  
  // 総合スコア計算
  const totalScore = checks.reduce((sum, check) => sum + check.score, 0) / checks.length;
  
  // 詳細ログ出力
  await logIntegrityReport(context.userId, context.migrationId, checks, totalScore);
  
  return totalScore;
}

interface IntegrityCheck {
  name: string;
  score: number; // 0-100
  details: string[];
  critical: boolean;
}

async function verifyDataVolume(context: MigrationContext, projects: Project[]): Promise<IntegrityCheck> {
  const originalFamilyCount = context.families.length;
  const newProjectCount = projects.length;
  
  // 基本的にはファミリー数 = プロジェクト数であるべき
  const volumeMatch = originalFamilyCount === newProjectCount;
  
  return {
    name: 'データ量整合性',
    score: volumeMatch ? 100 : 0,
    details: [
      `元ファミリー数: ${originalFamilyCount}`,
      `新プロジェクト数: ${newProjectCount}`,
      `整合性: ${volumeMatch ? '✅' : '❌'}`
    ],
    critical: true
  };
}

async function verifyRelationships(context: MigrationContext, projects: Project[]): Promise<IntegrityCheck> {
  const issues: string[] = [];
  let validRelationships = 0;
  let totalRelationships = 0;
  
  for (const project of projects) {
    totalRelationships++;
    
    // プロジェクト → フェーズ関係チェック
    const phases = await getPhasesByProject(project.id);
    if (phases.length > 0) {
      validRelationships++;
    } else {
      issues.push(`プロジェクト ${project.name} にフェーズが存在しません`);
    }
    
    // メンバー関係チェック
    const members = await getProjectMembers(project.id);
    if (members.length > 0 && members.some(m => m.role === 'owner')) {
      validRelationships++;
    } else {
      issues.push(`プロジェクト ${project.name} の所有者が見つかりません`);
    }
    totalRelationships++;
  }
  
  const score = totalRelationships > 0 ? (validRelationships / totalRelationships) * 100 : 100;
  
  return {
    name: '関係整合性',
    score,
    details: issues,
    critical: score < 90
  };
}
```

### バックアップ・ロールバック機能

#### バックアップ作成

```typescript
// functions/src/migration/backup.ts
export async function createUserBackup(context: MigrationContext): Promise<string> {
  const backupId = `backup_${context.userId}_${context.migrationId}`;
  
  const backup = {
    backupId,
    userId: context.userId,
    migrationId: context.migrationId,
    timestamp: context.timestamp,
    userData: context.userDoc,
    familyData: context.families,
    // 関連データも含める
    taskLists: await getAllUserTaskLists(context.userId),
    tasks: await getAllUserTasks(context.userId),
    invitations: await getAllUserInvitations(context.userId)
  };
  
  // セキュアなバックアップストレージに保存
  await admin.firestore()
    .collection('migration_backups')
    .doc(backupId)
    .set(backup);
  
  return backupId;
}
```

#### ロールバック実装

```typescript
// functions/src/migration/rollback.ts
export async function rollbackUser(userId: string): Promise<void> {
  // 最新のバックアップを取得
  const backup = await getLatestBackupForUser(userId);
  if (!backup) {
    throw new Error(`ユーザー ${userId} のバックアップが見つかりません`);
  }
  
  const batch = admin.firestore().batch();
  
  try {
    // 新しく作成されたプロジェクトデータを削除
    await deleteUserProjects(userId);
    
    // 元のファミリーデータを復元
    await restoreUserFamilies(backup, batch);
    
    // ユーザードキュメントを復元
    await restoreUserDocument(backup, batch);
    
    // ロールバック実行
    await batch.commit();
    
    // ロールバック記録
    await logRollbackSuccess(userId, backup.backupId);
    
  } catch (error) {
    console.error(`ロールバック失敗 - ユーザー: ${userId}`, error);
    throw error;
  }
}
```

### 移行進捗監視

#### リアルタイム進捗追跡

```typescript
// functions/src/migration/progress.ts
export async function updateMigrationProgress(
  userId: string,
  migrationId: string,
  stage: MigrationStage,
  progress: number,
  details?: string
): Promise<void> {
  
  await admin.firestore()
    .collection('user_migrations')
    .doc(userId)
    .update({
      migrationId,
      stage,
      progress,
      details,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });
    
  // リアルタイム通知（必要に応じて）
  if (progress === 100) {
    await sendMigrationCompleteNotification(userId);
  }
}

enum MigrationStage {
  INITIATED = 'initiated',
  BACKUP_CREATED = 'backup_created',
  TRANSFORMATION = 'transformation',
  VERIFICATION = 'verification',
  COMPLETED = 'completed',
  FAILED = 'failed',
  ROLLED_BACK = 'rolled_back'
}
```

## 移行実行戦略

### 段階的移行

**3段階移行アプローチ**:

1. **準備段階** (1週間)
   - 新アーキテクチャのインデックス事前作成
   - バックアップシステムテスト
   - パイロットユーザーでの試行

2. **移行実行段階** (2週間)
   - ユーザー単位での段階的移行
   - リアルタイム監視と問題対応
   - 移行品質の継続的確認

3. **完了・クリーンアップ段階** (1週間)
   - 全データの最終検証
   - レガシーデータの読み取り専用化
   - 移行完了通知とトレーニング

### 品質保証

**移行品質指標**:
- データ整合性スコア: 95%以上
- 移行成功率: 98%以上
- ユーザー満足度: 4.5/5以上
- パフォーマンス影響: 10%以内

---

**更新日**: 2025-09-05  
**関連Phase**: Phase 5 Session 5.1  
**次ステップ**: 移行実行とモニタリング