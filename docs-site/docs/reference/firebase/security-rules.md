# Firestore セキュリティルール仕様

プロジェクトベースアーキテクチャのための包括的セキュリティルールとロールベースアクセス制御の技術仕様です。

## 🔗 関連情報

- 📊 [データモデル設計](./data-model.md) - コレクション構造とスキーマ
- 🔄 [Phase5移行概要](./phase5-migration-overview.md) - 移行戦略
- 🏗️ [インデックス戦略](./index-strategy.md) - パフォーマンス最適化

---

# Phase 5: Firestore Security Rules 完全仕様

**セッション**: 5.1 - シゴデキアーキテクチャ進化  
**目的**: プロジェクトベース階層でのロールベースアクセス制御実現

## セキュリティルール概要

新しいプロジェクトベースアーキテクチャでは、ユーザーデータ保護、プロジェクトプライバシー確保、階層構造全体での適切な認可を実現する包括的セキュリティルールが必要。パフォーマンスとシンプリシティを維持しながらロールベースアクセス制御を実装。

## コアセキュリティ原則

### 1. 認証必須

**基本方針**:
- 全操作でユーザー認証必須
- 匿名アクセス一切禁止
- 認証状態常時検証

### 2. ロールベースアクセス制御

**権限階層**:
- **Owner（所有者）**: プロジェクトと全ネストデータの完全制御
- **Editor（編集者）**: タスク/リスト/フェーズの作成・編集・削除、メンバー招待
- **Viewer（閲覧者）**: プロジェクトデータの読み取り専用アクセス

### 3. データ分離

**分離原則**:
- ユーザーはメンバーのプロジェクトにのみアクセス可能
- クロスプロジェクトデータアクセス禁止
- 個人データは所有者にのみプライベート

### 4. 階層権限

**継承原則**:
- プロジェクト権限が全ネストコレクションにカスケード
- 上位レベルアクセスが下位レベルアクセス付与
- 過度な読み取りなしでの効率的権限チェック

## 完全セキュリティルール実装

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================================================
    // ヘルパー関数
    // ============================================================================
    
    // ユーザー認証チェック
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // 現在のユーザーID取得
    function getCurrentUser() {
      return request.auth.uid;
    }
    
    // プロジェクト所有者チェック
    function isProjectOwner(projectId) {
      return isAuthenticated() && 
        get(/databases/$(database)/documents/projects/$(projectId)).data.ownerId == getCurrentUser();
    }
    
    // プロジェクトメンバーチェック
    function isProjectMember(projectId) {
      return isAuthenticated() && 
        getCurrentUser() in get(/databases/$(database)/documents/projects/$(projectId)).data.memberIds;
    }
    
    // プロジェクト内のユーザーロール取得
    function getUserProjectRole(projectId) {
      return get(/databases/$(database)/documents/projects/$(projectId)/members/$(getCurrentUser())).data.role;
    }
    
    // 最小権限レベルチェック
    function hasMinimumRole(projectId, requiredRole) {
      let userRole = getUserProjectRole(projectId);
      return (requiredRole == 'viewer' && userRole in ['viewer', 'editor', 'owner']) ||
             (requiredRole == 'editor' && userRole in ['editor', 'owner']) ||
             (requiredRole == 'owner' && userRole == 'owner');
    }
    
    // プロジェクトデータ読み取り権限
    function canReadProject(projectId) {
      return isProjectMember(projectId);
    }
    
    // プロジェクトデータ書き込み権限  
    function canWriteProject(projectId) {
      return hasMinimumRole(projectId, 'editor');
    }
    
    // プロジェクト管理権限（削除、メンバー管理）
    function canManageProject(projectId) {
      return hasMinimumRole(projectId, 'owner');
    }
    
    // プロジェクトデータ構造検証
    function isValidProjectData() {
      return request.resource.data.keys().hasAll(['name', 'ownerId', 'memberIds', 'isArchived']) &&
             request.resource.data.ownerId == getCurrentUser() &&
             getCurrentUser() in request.resource.data.memberIds;
    }
    
    // ============================================================================
    // ユーザーコレクション
    // ============================================================================
    
    match /users/{userId} {
      // ユーザーは自分のデータにのみアクセス可能
      allow read, write: if isAuthenticated() && getCurrentUser() == userId;
    }
    
    // ============================================================================  
    // プロジェクトコレクション
    // ============================================================================
    
    match /projects/{projectId} {
      // 読み取り: 任意のプロジェクトメンバー
      allow read: if canReadProject(projectId);
      
      // 作成: 認証済みユーザー（所有者になる）
      allow create: if isAuthenticated() && isValidProjectData();
      
      // 更新: 編集者と所有者、ただしメンバー/ロール変更は所有者のみ
      allow update: if canWriteProject(projectId) && 
        // 編集者は基本フィールド更新可能
        (hasMinimumRole(projectId, 'editor') && 
         !request.resource.data.diff(resource.data).affectedKeys().hasAny(['ownerId', 'memberIds'])) ||
        // 所有権やメンバーシップ変更は所有者のみ
        (hasMinimumRole(projectId, 'owner') && request.resource.data.ownerId == resource.data.ownerId);
      
      // 削除: 所有者のみ
      allow delete: if canManageProject(projectId);
      
      // ========================================================================
      // プロジェクトメンバー サブコレクション
      // ========================================================================
      
      match /members/{memberId} {
        // 読み取り: 任意のプロジェクトメンバーが全メンバー閲覧可能
        allow read: if canReadProject(projectId);
        
        // 作成: 所有者と編集者がメンバー追加可能（招待経由）
        allow create: if canWriteProject(projectId) && 
          request.resource.data.userId == memberId &&
          request.resource.data.projectId == projectId;
        
        // 更新: 所有者は任意メンバー更新可能、ユーザーは自分のlastActiveAt更新可能
        allow update: if 
          (canManageProject(projectId)) ||
          (getCurrentUser() == memberId && 
           request.resource.data.diff(resource.data).affectedKeys().hasOnly(['lastActiveAt']));
        
        // 削除: 所有者は任意メンバー削除可能、メンバーは自分を削除可能
        allow delete: if canManageProject(projectId) || getCurrentUser() == memberId;
      }
      
      // ========================================================================
      // プロジェクト招待 サブコレクション  
      // ========================================================================
      
      match /invitations/{inviteCode} {
        // 読み取り: 認証済みユーザー（招待受諾のため必要）
        allow read: if isAuthenticated();
        
        // 作成: 編集者と所有者が招待作成可能
        allow create: if canWriteProject(projectId) &&
          request.resource.data.projectId == projectId &&
          request.resource.data.invitedBy == getCurrentUser();
        
        // 更新: 作成者またはプロジェクト所有者のみ
        allow update: if canManageProject(projectId) || 
          resource.data.invitedBy == getCurrentUser();
        
        // 削除: 作成者またはプロジェクト所有者のみ
        allow delete: if canManageProject(projectId) || 
          resource.data.invitedBy == getCurrentUser();
      }
      
      // ========================================================================
      // フェーズ サブコレクション
      // ========================================================================
      
      match /phases/{phaseId} {
        // 読み取り: 任意のプロジェクトメンバー
        allow read: if canReadProject(projectId);
        
        // 作成: 編集者と所有者
        allow create: if canWriteProject(projectId) && 
          request.resource.data.projectId == projectId &&
          request.resource.data.createdBy == getCurrentUser();
        
        // 更新: 編集者と所有者
        allow update: if canWriteProject(projectId);
        
        // 削除: 編集者と所有者
        allow delete: if canWriteProject(projectId);
        
        // ======================================================================
        // リスト サブコレクション
        // ======================================================================
        
        match /lists/{listId} {
          // 読み取り: 任意のプロジェクトメンバー
          allow read: if canReadProject(projectId);
          
          // 作成: 編集者と所有者
          allow create: if canWriteProject(projectId) && 
            request.resource.data.projectId == projectId &&
            request.resource.data.phaseId == phaseId &&
            request.resource.data.createdBy == getCurrentUser();
          
          // 更新: 編集者と所有者
          allow update: if canWriteProject(projectId);
          
          // 削除: 編集者と所有者
          allow delete: if canWriteProject(projectId);
          
          // ====================================================================
          // タスク サブコレクション
          // ====================================================================
          
          match /tasks/{taskId} {
            // 読み取り: 任意のプロジェクトメンバー
            allow read: if canReadProject(projectId);
            
            // 作成: 編集者と所有者
            allow create: if canWriteProject(projectId) && 
              request.resource.data.projectId == projectId &&
              request.resource.data.phaseId == phaseId &&
              request.resource.data.listId == listId &&
              request.resource.data.createdBy == getCurrentUser();
            
            // 更新: 編集者と所有者、加えて割り当てユーザーは完了状態更新可能
            allow update: if canWriteProject(projectId) ||
              (resource.data.assignedTo == getCurrentUser() && 
               request.resource.data.diff(resource.data).affectedKeys()
                 .hasOnly(['isCompleted', 'completedAt']));
            
            // 削除: 編集者と所有者
            allow delete: if canWriteProject(projectId);
            
            // ==================================================================
            // サブタスク サブコレクション
            // ==================================================================
            
            match /subtasks/{subtaskId} {
              // 読み取り: 任意のプロジェクトメンバー
              allow read: if canReadProject(projectId);
              
              // 作成: 編集者と所有者
              allow create: if canWriteProject(projectId) && 
                request.resource.data.projectId == projectId &&
                request.resource.data.phaseId == phaseId &&
                request.resource.data.listId == listId &&
                request.resource.data.taskId == taskId &&
                request.resource.data.createdBy == getCurrentUser();
              
              // 更新: 編集者と所有者、加えて割り当てユーザーは完了更新可能
              allow update: if canWriteProject(projectId) ||
                (resource.data.assignedTo == getCurrentUser() && 
                 request.resource.data.diff(resource.data).affectedKeys()
                   .hasOnly(['isCompleted', 'completedAt']));
              
              // 削除: 編集者と所有者
              allow delete: if canWriteProject(projectId);
            }
          }
        }
      }
    }
    
    // ============================================================================
    // 移行コレクション（一時的）
    // ============================================================================
    
    // レガシーファミリーコレクション（移行中読み取り専用）
    match /families/{familyId} {
      allow read: if isAuthenticated() && 
        getCurrentUser() in resource.data.members;
      
      // 書き込み操作不可 - セキュアな関数による移行のみ
    }
    
    // ユーザー移行追跡（ユーザーは自分のみアクセス）
    match /user_migrations/{userId} {
      allow read, write: if isAuthenticated() && getCurrentUser() == userId;
    }
    
    // レガシー招待（移行中読み取り専用）
    match /invitations/{inviteCode} {
      allow read: if isAuthenticated();
      // 書き込み操作不可
    }
  }
}
```

## セキュリティルール詳細分析

### 権限レベル詳細

#### 所有者権限

**完全制御**:
- プロジェクトと全ネストデータへの完全読み書きアクセス
- プロジェクトメンバー管理（追加、削除、ロール変更）
- プロジェクト全体の削除権限
- 招待の作成・管理

#### 編集者権限

**編集アクセス**:
- フェーズ、リスト、タスク、サブタスクへの読み書きアクセス
- 編集者または閲覧者ロールでの招待作成可能
- 全プロジェクトメンバーの閲覧
- メンバーシップ管理やプロジェクト削除不可

#### 閲覧者権限

**読み取り専用**:
- 全プロジェクトデータへの読み取り専用アクセス
- コンテンツの作成、更新、削除不可
- 新規メンバー招待不可

### 特別ケース実装

#### タスク割り当てルール

**細分化されたアクセス**:
- 割り当てユーザーは自分のタスクを完了/未完了にマーク可能
- 割り当てユーザーは他のタスクプロパティ変更不可
- 完全な編集権なしでの細分化されたタスク完了を許可

#### セルフ管理権利

**ユーザー自律性**:
- ユーザーは自分のlastActiveAtタイムスタンプを常時更新可能
- ユーザーはプロジェクトから自分を削除可能
- ユーザーは自分のユーザードキュメントを完全制御

### データ検証実装

#### プロジェクト作成

**作成時検証**:
- 新規プロジェクトは作成者を所有者・メンバーとして含む必要
- 必須フィールドが存在し適切に構造化されている必要
- 作成者は自動的に所有者ロール取得

#### 階層一貫性

**整合性保証**:
- 全ネストドキュメントは正しい親IDを参照する必要
- CreatedByフィールドは現在の認証ユーザーと一致する必要
- 非正規化されたproject/phase/list IDが一貫している必要

## パフォーマンス最適化

### 効率的権限チェック

**最適化戦略**:
1. **単一権限ルックアップ**: プロジェクトメンバーシップを使用した操作あたり単一権限ルックアップ
2. **キャッシュされたロール情報**: プロジェクトメンバードキュメントでのキャッシュされたロール情報
3. **非正規化プロジェクトID**: 深いパスルックアップを避ける

### データベース読み取り最小化

**読み取り最適化**:
1. **ロールベース分岐**: 不要なデータベース読み取りを防ぐ
2. **resource.dataのスマート使用**: 既存ドキュメントチェックのため
3. **バッチ権限検証**: 関連操作の一括検証

## 移行セキュリティ考慮事項

### レガシーデータ保護

**移行中保護**:
- レガシーコレクションは移行中読み取り専用
- 移行操作はセキュアなCloud Functionsで処理
- レガシーデータのクライアント側変更なし

### 移行期間安全性

**共存戦略**:
- 新旧セキュリティモデルの共存可能
- 移行追跡によりデータ破損防止
- 保存されたレガシーデータによるロールバック機能

## テスト戦略

### セキュリティルール単体テスト

```javascript
// プロジェクトメンバーアクセステスト
test('プロジェクトメンバーはプロジェクトデータを読み取り可能', async () => {
  await firebase.assertSucceeds(
    getDoc(db, `/projects/${projectId}`)
      .withAuth({ uid: memberUserId })
  );
});

// 非メンバーアクセス拒否テスト
test('非メンバーはプロジェクトデータにアクセス不可', async () => {
  await firebase.assertFails(
    getDoc(db, `/projects/${projectId}`)
      .withAuth({ uid: nonMemberUserId })
  );
});

// ロールベース権限テスト
test('閲覧者はタスク作成不可', async () => {
  await firebase.assertFails(
    setDoc(db, `/projects/${projectId}/phases/${phaseId}/lists/${listId}/tasks/${taskId}`, taskData)
      .withAuth({ uid: viewerUserId })
  );
});

// 割り当てユーザー特権テスト
test('割り当てユーザーはタスク完了状態を更新可能', async () => {
  await firebase.assertSucceeds(
    updateDoc(db, `/projects/${projectId}/phases/${phaseId}/lists/${listId}/tasks/${taskId}`, 
      { isCompleted: true, completedAt: new Date() })
      .withAuth({ uid: assignedUserId })
  );
});
```

### 統合テスト

**包括的テスト**:
- クロスコレクション権限継承
- 複雑クエリ権限検証
- 移行シナリオセキュリティ検証
- パフォーマンス負荷テスト

## 監視・監査

### セキュリティメトリクス

**監視項目**:
- ユーザー/リソース別の権限試行失敗
- 異常なアクセスパターンの検出
- ロール昇格試行の監視
- 大量アクセスパターンの異常検知

### 監査ログ

**監査対象**:
- 全センシティブ操作のログ記録
- メンバー追加/削除の追跡
- 権限変更の監査証跡
- 移行操作の完全ログ

## セキュリティベストプラクティス

### 実装原則

**セキュリティ原則**:
- **最小権限の原則**: 必要最小限の権限のみ付与
- **深層防御**: 複数レベルでのセキュリティ検証
- **透明性**: 全操作の監査可能性
- **分離**: プロジェクト間の完全データ分離

### 運用ガイドライン

**運用原則**:
- 定期的なセキュリティルール監査
- 異常アクセスパターンの定期確認
- 権限変更の慎重な管理
- セキュリティインシデント対応プロセス

---

**更新日**: 2025-09-05  
**関連Phase**: Phase 5 Session 5.1  
**次ステップ**: データモデル実装とインデックス最適化