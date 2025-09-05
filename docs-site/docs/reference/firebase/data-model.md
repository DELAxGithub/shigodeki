# Firestore データモデル設計

プロジェクトベース階層アーキテクチャへの移行とコラボレーション・スケーラビリティ強化のためのデータモデル仕様です。

## 🔗 関連情報

- 🛡️ [セキュリティルール](./security-rules.md) - アクセス制御とロール管理
- 🔄 [Phase5移行概要](./phase5-migration-overview.md) - 移行戦略
- 🏗️ [インデックス戦略](./index-strategy.md) - クエリ最適化

---

# Phase 5: データモデル設計書

**セッション**: 5.1 - シゴデキアーキテクチャ進化  
**目的**: ファミリーベースからプロジェクトベース階層アーキテクチャへの変革

## 概要

ファミリーベースタスク管理からプロジェクトベース階層アーキテクチャへの変革により、強化されたコラボレーションとスケーラビリティを実現。

## 現在 vs 新アーキテクチャ

### 現在の構造（Phase 4）

```yaml
# レガシー構造
users/{userId}:
  - familyIds: [string] 
  - metadata

families/{familyId}:
  - taskLists/{listId}/
    - tasks/{taskId}
  - metadata

invitations/{inviteCode}:
  - metadata
```

### 新構造（Phase 5+）

```yaml
# 新プロジェクトベース構造
users/{userId}:
  - projectIds: [string] 
  - role_assignments/{projectId}: Role
  - metadata

projects/{projectId}:
  - metadata
  - members/{userId}
  - phases/{phaseId}/
    - metadata
    - lists/{listId}/
      - metadata  
      - tasks/{taskId}/
        - metadata
        - subtasks/{subtaskId}
  - invitations/{inviteCode}
```

## データモデル仕様

### 1. User モデル（強化版）

```swift
struct User: Identifiable, Codable {
    var id: String?
    let name: String
    let email: String
    let projectIds: [String]                    // 新機能: familyIds を置換
    let roleAssignments: [String: Role]         // 新機能: プロジェクト-ロールマッピング
    var createdAt: Date?
    var lastActiveAt: Date?                     // 新機能: 活動追跡
    var preferences: UserPreferences?           // 新機能: ユーザー設定
}

struct UserPreferences: Codable {
    let theme: String                          // "light" | "dark" | "auto"
    let notificationsEnabled: Bool
    let defaultView: String                    // "list" | "board" | "timeline"
    let language: String                       // "ja" | "en"
}

enum Role: String, CaseIterable, Codable {
    case owner = "owner"       // 完全権限
    case editor = "editor"     // コンテンツ編集、タスク管理
    case viewer = "viewer"     // 読み取り専用アクセス
    
    var permissions: Set<Permission> {
        switch self {
        case .owner: return [.read, .write, .delete, .invite, .manageMembers]
        case .editor: return [.read, .write, .invite]
        case .viewer: return [.read]
        }
    }
    
    var localizedName: String {
        switch self {
        case .owner: return "所有者"
        case .editor: return "編集者"
        case .viewer: return "閲覧者"
        }
    }
}

enum Permission {
    case read, write, delete, invite, manageMembers
}
```

### 2. Project モデル（新規）

```swift
struct Project: Identifiable, Codable {
    var id: String?
    let name: String
    let description: String?
    let ownerId: String                        // 作成者/所有者ユーザーID
    var memberIds: [String]                    // 全プロジェクトメンバー
    var createdAt: Date?
    var lastModifiedAt: Date?
    var isArchived: Bool
    var settings: ProjectSettings?
    var statistics: ProjectStats?              // 計算フィールド
    
    // Firestore で計算される統計
    var phaseCount: Int { return 0 }          // Cloud Function で更新
    var totalTasks: Int { return 0 }          // Cloud Function で更新
    var completedTasks: Int { return 0 }      // Cloud Function で更新
}

struct ProjectSettings: Codable {
    let isPublic: Bool                        // 公開プロジェクト設定
    let allowGuestAccess: Bool                // ゲストアクセス許可
    let defaultPhaseTemplate: String?         // デフォルトフェーズテンプレート
    let taskAutoArchiveDays: Int?             // 完了タスク自動アーカイブ日数
}

struct ProjectStats: Codable {
    let totalMembers: Int
    let totalPhases: Int
    let totalTasks: Int
    let completedTasks: Int
    let lastActivityAt: Date?
    
    var completionPercentage: Double {
        guard totalTasks > 0 else { return 0.0 }
        return Double(completedTasks) / Double(totalTasks)
    }
}
```

### 3. ProjectMember モデル（新規）

```swift
struct ProjectMember: Identifiable, Codable {
    var id: String?                           // = userId
    let userId: String
    let projectId: String
    let role: Role
    var joinedAt: Date?
    var lastActiveAt: Date?
    let invitedBy: String?
    var nickname: String?                     // プロジェクト内ニックネーム
}
```

### 4. Phase モデル（新規）

```swift
struct Phase: Identifiable, Codable {
    var id: String?
    let name: String
    let description: String?
    let projectId: String                     // 親プロジェクトID
    var order: Int                           // フェーズ順序
    var createdAt: Date?
    var isArchived: Bool
    var dueDate: Date?                       // フェーズ期限
    var completedAt: Date?                   // 完了日時
    
    // 統計（計算フィールド）
    var listCount: Int { return 0 }          // Cloud Function で更新
    var taskCount: Int { return 0 }          // Cloud Function で更新
    var completedTaskCount: Int { return 0 } // Cloud Function で更新
}
```

### 5. TaskList モデル（強化版）

```swift
struct TaskList: Identifiable, Codable {
    var id: String?
    let name: String
    let description: String?
    let projectId: String                    // 新機能: プロジェクトID
    let phaseId: String                      // 新機能: フェーズID
    var order: Int                          // リスト順序
    var color: String?                      // リストカラー
    var createdAt: Date?
    var isArchived: Bool
    
    // 統計（計算フィールド）
    var taskCount: Int { return 0 }         // Cloud Function で更新
    var completedTaskCount: Int { return 0 } // Cloud Function で更新
}
```

### 6. Task モデル（強化版）

```swift
struct ShigodekiTask: Identifiable, Codable {
    var id: String?
    let title: String
    let description: String?
    let projectId: String                    // 新機能: プロジェクトID
    let phaseId: String                      // 新機能: フェーズID
    let listId: String
    var order: Int
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date?
    var dueDate: Date?                       // 新機能: 期限
    var priority: TaskPriority?              // 新機能: 優先度
    var assignedTo: String?                  // 新機能: 担当者
    var tags: [String]                       // 新機能: タグシステム
    var estimatedHours: Double?              // 新機能: 見積もり時間
    var actualHours: Double?                 // 新機能: 実績時間
    
    // 統計（計算フィールド）
    var subtaskCount: Int { return 0 }       // Cloud Function で更新
    var completedSubtaskCount: Int { return 0 } // Cloud Function で更新
}

enum TaskPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var localizedName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .urgent: return "緊急"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "green"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
}
```

### 7. Subtask モデル（新規）

```swift
struct Subtask: Identifiable, Codable {
    var id: String?
    let title: String
    let description: String?
    let projectId: String                    // 非正規化: 高速クエリのため
    let phaseId: String                      // 非正規化: 高速クエリのため
    let listId: String                       // 非正規化: 高速クエリのため
    let taskId: String                       // 親タスクID
    var order: Int
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date?
    var assignedTo: String?                  // 担当者
}
```

### 8. ProjectInvitation モデル（新規）

```swift
struct ProjectInvitation: Identifiable, Codable {
    var id: String?                          // = inviteCode
    let inviteCode: String                   // 招待コード（UUID）
    let projectId: String
    let invitedBy: String                    // 招待者ユーザーID
    let invitedEmail: String?                // 招待されたメールアドレス
    let role: Role                           // 招待時に付与されるロール
    var createdAt: Date?
    var expiresAt: Date?                     // 招待期限
    var acceptedAt: Date?                    // 受諾日時
    var acceptedBy: String?                  // 受諾者ユーザーID
    let isExpired: Bool                      // 期限切れフラグ
    
    var isValid: Bool {
        !isExpired && acceptedAt == nil && (expiresAt == nil || expiresAt! > Date())
    }
}
```

## コレクション構造

### Firestore コレクション階層

```yaml
/users/{userId}
  - フィールド: User モデルのすべてのフィールド

/projects/{projectId}
  - フィールド: Project モデルのすべてのフィールド
  
  /members/{userId}
    - フィールド: ProjectMember モデルのすべてのフィールド
  
  /invitations/{inviteCode}
    - フィールド: ProjectInvitation モデルのすべてのフィールド
  
  /phases/{phaseId}
    - フィールド: Phase モデルのすべてのフィールド
    
    /lists/{listId}
      - フィールド: TaskList モデルのすべてのフィールド
      
      /tasks/{taskId}
        - フィールド: ShigodekiTask モデルのすべてのフィールド
        
        /subtasks/{subtaskId}
          - フィールド: Subtask モデルのすべてのフィールド

# 移行用一時コレクション
/user_migrations/{userId}
  - migrationStatus: string
  - migratedAt: Date
  - legacyFamilyIds: [string]

/migration_logs/{operationId}
  - operation: string
  - status: string
  - createdAt: Date
  - details: object
```

## インデックス要件

### 複合インデックス

```yaml
# プロジェクトメンバークエリ用
projects/{projectId}/members:
  - (projectId, role)
  - (projectId, lastActiveAt)

# タスククエリ用  
projects/{projectId}/phases/{phaseId}/lists/{listId}/tasks:
  - (projectId, assignedTo, isCompleted)
  - (projectId, dueDate, priority)
  - (projectId, tags, isCompleted)
  - (listId, order)

# フェーズクエリ用
projects/{projectId}/phases:
  - (projectId, order)
  - (projectId, dueDate)

# 招待クエリ用
projects/{projectId}/invitations:
  - (projectId, createdAt)
  - (invitedEmail, acceptedAt)
```

## データ整合性ルール

### 参照整合性

**必須関係**:
- Task → List → Phase → Project の階層関係維持
- User → ProjectMember 関係の整合性
- Invitation → Project 関係の整合性

### 非正規化戦略

**パフォーマンス最適化**:
- Task と Subtask に projectId, phaseId, listId を非正規化
- 高速なクロス階層クエリを可能にする
- 統計フィールドの戦略的非正規化

### 統計更新戦略

**Cloud Function 自動更新**:
- Project 統計: タスク数、完了数、メンバー数
- Phase 統計: リスト数、タスク数、完了率  
- TaskList 統計: タスク数、完了数
- Task 統計: サブタスク数、完了数

## セキュリティ考慮事項

### アクセス制御

**ルールベースアクセス**:
- プロジェクトメンバーシップベースのアクセス制御
- ロールベース権限（Owner > Editor > Viewer）
- 階層権限の継承

### データプライバシー

**プライバシー保護**:
- ユーザーは参加プロジェクトのみアクセス可能
- 個人データ（User モデル）は所有者のみアクセス
- 招待システムでのメール保護

## 移行戦略

### 段階的移行

**Phase 4 → Phase 5 移行**:
1. 新しいプロジェクト構造並行運用
2. レガシーデータの読み取り専用維持  
3. 段階的データ移行（Cloud Functions）
4. 移行完了後レガシー削除

### データマッピング

**マッピング戦略**:
- Family → Project 変換
- FamilyMember → ProjectMember 変換
- レガシー TaskList → 新 Phase/TaskList 構造変換
- 既存 Task データの階層情報補完

---

**更新日**: 2025-09-05  
**関連Phase**: Phase 5 Session 5.1  
**次ステップ**: セキュリティルール実装とインデックス最適化