# Firestore インデックス戦略

プロジェクトベースアーキテクチャでの包括的インデックス戦略とクエリ最適化の技術仕様です。

## 🔗 関連情報

- 📊 [データモデル設計](./data-model.md) - コレクション構造とスキーマ
- 🛡️ [セキュリティルール](./security-rules.md) - アクセス制御
- 🔄 [Phase5移行概要](./phase5-migration-overview.md) - 移行時のインデックス戦略

---

# Phase 5: Firestore インデックス戦略

**セッション**: 5.1 - シゴデキアーキテクチャ進化  
**目的**: 新プロジェクトベースアーキテクチャでの最適なクエリパフォーマンス実現

## インデックス戦略概要

新しいプロジェクトベースアーキテクチャでの一般的なクエリパターンに最適化し、インデックスメンテナンスオーバーヘッドを最小化する包括的インデックス戦略。

## 単一フィールドインデックス

### Users コレクション

```yaml
# /users/{userId}
single_field_indexes:
  - field: projectIds
    mode: ARRAY_CONTAINS
    description: "ユーザーが所属するプロジェクト検索用"
  
  - field: lastActiveAt  
    mode: DESCENDING
    description: "アクティブユーザーソート用"
  
  - field: createdAt
    mode: DESCENDING
    description: "新規ユーザー時系列ソート用"
    
  - field: email
    mode: ASCENDING
    description: "メールアドレスでのユーザー検索用"
```

### Projects コレクション

```yaml
# /projects/{projectId}
single_field_indexes:
  - field: memberIds
    mode: ARRAY_CONTAINS
    description: "ユーザーが参加するプロジェクト検索用"
  
  - field: ownerId
    mode: ASCENDING
    description: "所有者別プロジェクト検索用"
  
  - field: isArchived
    mode: ASCENDING
    description: "アクティブ/アーカイブプロジェクトフィルタ用"
  
  - field: lastModifiedAt
    mode: DESCENDING
    description: "最近更新されたプロジェクトソート用"
  
  - field: createdAt
    mode: DESCENDING
    description: "プロジェクト作成日時ソート用"
  
  - field: migratedFromFamily
    mode: ASCENDING
    description: "移行クエリ用（一時的）"
```

### ProjectMembers サブコレクション

```yaml
# /projects/{projectId}/members/{userId}
single_field_indexes:
  - field: role
    mode: ASCENDING
    description: "ロール別メンバーフィルタ用"
  
  - field: joinedAt
    mode: DESCENDING
    description: "参加日時ソート用"
  
  - field: lastActiveAt
    mode: DESCENDING
    description: "アクティビティ順ソート用"
  
  - field: userId
    mode: ASCENDING
    description: "ユーザーID検索用"
```

### Phases サブコレクション

```yaml
# /projects/{projectId}/phases/{phaseId}
single_field_indexes:
  - field: projectId
    mode: ASCENDING
    description: "プロジェクト別フェーズ検索用"
  
  - field: order
    mode: ASCENDING
    description: "フェーズ順序ソート用"
  
  - field: isCompleted
    mode: ASCENDING
    description: "完了/未完了フィルタ用"
  
  - field: createdAt
    mode: DESCENDING
    description: "作成日時ソート用"
  
  - field: dueDate
    mode: ASCENDING
    description: "期限日ソート用"
```

### Lists サブコレクション

```yaml
# /projects/{projectId}/phases/{phaseId}/lists/{listId}
single_field_indexes:
  - field: phaseId
    mode: ASCENDING
    description: "フェーズ別リスト検索用"
  
  - field: projectId
    mode: ASCENDING
    description: "プロジェクト全体のリスト検索用"
  
  - field: order
    mode: ASCENDING
    description: "リスト順序ソート用"
  
  - field: isArchived
    mode: ASCENDING
    description: "アクティブリストフィルタ用"
  
  - field: createdBy
    mode: ASCENDING
    description: "作成者別リストフィルタ用"
```

### Tasks サブコレクション

```yaml
# /projects/{projectId}/phases/{phaseId}/lists/{listId}/tasks/{taskId}
single_field_indexes:
  - field: listId
    mode: ASCENDING
    description: "リスト別タスク検索用"
  
  - field: phaseId
    mode: ASCENDING
    description: "フェーズ別タスク検索用"
  
  - field: projectId
    mode: ASCENDING
    description: "プロジェクト全体のタスク検索用"
  
  - field: isCompleted
    mode: ASCENDING
    description: "完了/未完了フィルタ用"
  
  - field: assignedTo
    mode: ASCENDING
    description: "担当者別タスクフィルタ用"
  
  - field: dueDate
    mode: ASCENDING
    description: "期限日ソート用"
  
  - field: priority
    mode: ASCENDING
    description: "優先度フィルタ用"
  
  - field: tags
    mode: ARRAY_CONTAINS
    description: "タグ別タスク検索用"
  
  - field: createdAt
    mode: DESCENDING
    description: "作成日時ソート用"
  
  - field: order
    mode: ASCENDING
    description: "タスク順序ソート用"
```

### Subtasks サブコレクション

```yaml
# /projects/{projectId}/phases/{phaseId}/lists/{listId}/tasks/{taskId}/subtasks/{subtaskId}
single_field_indexes:
  - field: taskId
    mode: ASCENDING
    description: "親タスク別サブタスク検索用"
  
  - field: projectId
    mode: ASCENDING
    description: "プロジェクト全体のサブタスク検索用"
  
  - field: isCompleted
    mode: ASCENDING
    description: "完了/未完了フィルタ用"
  
  - field: assignedTo
    mode: ASCENDING
    description: "担当者別サブタスクフィルタ用"
  
  - field: order
    mode: ASCENDING
    description: "サブタスク順序ソート用"
```

## 複合インデックス

### 高頻度クエリパターン用

#### プロジェクトメンバー管理

```yaml
# プロジェクト内のロール別アクティブメンバー
projects/{projectId}/members:
  composite_indexes:
    - fields:
        - projectId: ASCENDING
        - role: ASCENDING
        - lastActiveAt: DESCENDING
      description: "ロール別アクティブメンバーランキング"
    
    - fields:
        - projectId: ASCENDING
        - joinedAt: DESCENDING
      description: "新規参加メンバー順"
```

#### タスク管理クエリ

```yaml
# 複合タスククエリ
projects/{projectId}/phases/{phaseId}/lists/{listId}/tasks:
  composite_indexes:
    - fields:
        - projectId: ASCENDING
        - assignedTo: ASCENDING
        - isCompleted: ASCENDING
      description: "担当者別の未完了タスク"
    
    - fields:
        - projectId: ASCENDING
        - dueDate: ASCENDING
        - priority: ASCENDING
      description: "期限と優先度での並び替え"
    
    - fields:
        - projectId: ASCENDING
        - tags: ARRAY_CONTAINS
        - isCompleted: ASCENDING
      description: "タグ別未完了タスク"
    
    - fields:
        - listId: ASCENDING
        - order: ASCENDING
      description: "リスト内タスク順序"
    
    - fields:
        - phaseId: ASCENDING
        - dueDate: ASCENDING
      description: "フェーズ内期限順タスク"
    
    - fields:
        - assignedTo: ASCENDING
        - dueDate: ASCENDING
        - isCompleted: ASCENDING
      description: "担当者の期限順未完了タスク"
```

#### フェーズ・リスト管理

```yaml
# フェーズとリストの複合クエリ
projects/{projectId}/phases:
  composite_indexes:
    - fields:
        - projectId: ASCENDING
        - order: ASCENDING
      description: "プロジェクト内フェーズ順序"
    
    - fields:
        - projectId: ASCENDING
        - dueDate: ASCENDING
      description: "プロジェクト内フェーズ期限順"

projects/{projectId}/phases/{phaseId}/lists:
  composite_indexes:
    - fields:
        - phaseId: ASCENDING
        - order: ASCENDING
      description: "フェーズ内リスト順序"
    
    - fields:
        - projectId: ASCENDING
        - createdBy: ASCENDING
        - createdAt: DESCENDING
      description: "作成者別新しいリスト"
```

### 検索・フィルタリング用

```yaml
# プロジェクト検索とフィルタ
projects:
  composite_indexes:
    - fields:
        - memberIds: ARRAY_CONTAINS
        - isArchived: ASCENDING
        - lastModifiedAt: DESCENDING
      description: "ユーザーのアクティブプロジェクト（最近更新順）"
    
    - fields:
        - ownerId: ASCENDING
        - createdAt: DESCENDING
      description: "所有者の新しいプロジェクト"
    
    - fields:
        - memberIds: ARRAY_CONTAINS
        - createdAt: DESCENDING
      description: "ユーザー参加プロジェクト（新しい順）"
```

### ダッシュボード・統計用

```yaml
# ダッシュボード集計クエリ
projects/{projectId}/phases/{phaseId}/lists/{listId}/tasks:
  composite_indexes:
    - fields:
        - projectId: ASCENDING
        - isCompleted: ASCENDING
        - createdAt: DESCENDING
      description: "プロジェクト完了統計"
    
    - fields:
        - assignedTo: ASCENDING
        - isCompleted: ASCENDING
        - dueDate: ASCENDING
      description: "担当者別進捗統計"
    
    - fields:
        - phaseId: ASCENDING
        - isCompleted: ASCENDING
      description: "フェーズ別完了率"
```

## 特殊用途インデックス

### 移行用一時インデックス

```yaml
# Phase 4からPhase 5への移行用
migration_indexes:
  - collection: projects
    fields:
      - migratedFromFamily: ASCENDING
      - createdAt: DESCENDING
    description: "移行済みプロジェクト追跡"
    temporary: true
    remove_after: "移行完了後"
  
  - collection: users
    fields:
      - migrationStatus: ASCENDING
      - migratedAt: DESCENDING
    description: "ユーザー移行状況追跡"
    temporary: true
    remove_after: "移行完了後"
```

### 招待システム用

```yaml
# プロジェクト招待管理
projects/{projectId}/invitations:
  composite_indexes:
    - fields:
        - projectId: ASCENDING
        - createdAt: DESCENDING
      description: "プロジェクト別新しい招待"
    
    - fields:
        - invitedEmail: ASCENDING
        - acceptedAt: ASCENDING
      description: "招待状況追跡"
    
    - fields:
        - expiresAt: ASCENDING
        - acceptedAt: ASCENDING
      description: "期限切れ招待クリーンアップ"
```

## パフォーマンス最適化

### インデックス使用量最適化

**最適化戦略**:
1. **クエリパターン分析**: 実際のアプリ使用パターンに基づくインデックス設計
2. **複合インデックス効率**: 最も選択性の高いフィールドを先頭に配置
3. **配列インデックス慎重使用**: ARRAY_CONTAINSは必要最小限に制限
4. **一時インデックス管理**: 移行用インデックスの計画的削除

### クエリ最適化ガイドライン

**効率的クエリ設計**:
```swift
// ❌ 非効率なクエリ
db.collectionGroup("tasks")
  .whereField("isCompleted", isEqualTo: false)
  .whereField("assignedTo", isEqualTo: userId)
  .order(by: "dueDate")

// ✅ 効率的クエリ（複合インデックス利用）
db.collection("projects").document(projectId)
  .collection("phases").document(phaseId)
  .collection("lists").document(listId)
  .collection("tasks")
  .whereField("assignedTo", isEqualTo: userId)
  .whereField("isCompleted", isEqualTo: false)
  .order(by: "dueDate")
```

### インデックス監視

**監視項目**:
- インデックス使用率統計
- スロークエリ検出
- インデックス自動最適化提案
- ストレージ使用量追跡

## インデックス実装スクリプト

### Firebase CLI インデックス設定

```json
{
  "firestore": {
    "indexes": [
      {
        "collectionGroup": "tasks",
        "queryScope": "COLLECTION",
        "fields": [
          {"fieldPath": "projectId", "order": "ASCENDING"},
          {"fieldPath": "assignedTo", "order": "ASCENDING"},
          {"fieldPath": "isCompleted", "order": "ASCENDING"}
        ]
      },
      {
        "collectionGroup": "tasks", 
        "queryScope": "COLLECTION",
        "fields": [
          {"fieldPath": "projectId", "order": "ASCENDING"},
          {"fieldPath": "dueDate", "order": "ASCENDING"},
          {"fieldPath": "priority", "order": "ASCENDING"}
        ]
      },
      {
        "collectionGroup": "members",
        "queryScope": "COLLECTION", 
        "fields": [
          {"fieldPath": "projectId", "order": "ASCENDING"},
          {"fieldPath": "role", "order": "ASCENDING"},
          {"fieldPath": "lastActiveAt", "order": "DESCENDING"}
        ]
      }
    ]
  }
}
```

### 段階的インデックス作成

```bash
# Step 1: 基本インデックス作成
firebase deploy --only firestore:indexes

# Step 2: 使用状況監視（1週間）
firebase firestore:indexes --project=your-project

# Step 3: 使用率の低いインデックス削除
firebase firestore:indexes:delete [INDEX_ID]

# Step 4: 新しい使用パターンに基づく調整
firebase deploy --only firestore:indexes
```

## 移行時の注意事項

### 段階的インデックス移行

**移行戦略**:
1. **新インデックス事前作成**: 移行前に新アーキテクチャのインデックス作成
2. **並行運用期間**: 旧・新インデックス並行維持
3. **段階的切り替え**: 機能単位での段階的インデックス切り替え
4. **旧インデックス削除**: 移行完了確認後の旧インデックス削除

### インデックス作成時間対策

**大規模データ対応**:
- 段階的インデックス作成（小さなインデックスから）
- バックグラウンド作成の活用
- 作成時間予測とダウンタイム最小化
- ユーザー通知とステータス表示

---

**更新日**: 2025-09-05  
**関連Phase**: Phase 5 Session 5.1  
**次ステップ**: セキュリティルール実装と移行手順書