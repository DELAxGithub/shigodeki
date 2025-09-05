# シゴデキ iOS アプリ テストシナリオ

## 概要
本ドキュメントは、シゴデキ iOS アプリの包括的なテストシナリオを定義し、各場面での問題点とコンソールログを整理してイシュー化するためのドキュメントです。

## テストシナリオ一覧

### 1. アプリ起動・初期化テスト

#### シナリオ1-1: 初回起動
**手順:**
1. アプリを初回インストール後に起動
2. Firebase接続確認ログをチェック
3. 認証画面の表示確認

**期待される動作:**
- Firebase設定が正常に読み込まれる
- Firestore接続テストが成功する
- Sign in with Apple 画面が表示される

**確認すべきコンソールログ:**
```
🔧 Firebase: Using production backend for dev environment
🔧 Firebase Project: [project-id]
🔧 Firestore: Backend configured for project
✅ Firestore: Connection test successful
```

**考えられる問題点:**
- Firebase設定ファイルの読み込みエラー
- Firestore接続失敗
- 認証プロバイダーの設定不備

---

#### シナリオ1-2: 2回目以降の起動（ログイン済み）
**手順:**
1. 既にログイン済みの状態でアプリを起動
2. SharedManagerStoreの初期化確認
3. MainTabViewの表示確認

**期待される動作:**
- 自動ログインが実行される
- メインタブビューが表示される
- Managerが適切に初期化される

**確認すべきコンソールログ:**
```
✅ SharedManagerStore: Initialized successfully
🔧 Manager作成遅延: AuthManager created
```

**考えられる問題点:**
- トークンの期限切れ
- Manager初期化の失敗
- メモリ使用量の異常な増加

---

### 2. 認証機能テスト

#### シナリオ2-1: Sign in with Apple
**手順:**
1. 「Sign in with Apple」ボタンをタップ
2. Apple IDでサインイン
3. ユーザープロフィールの作成/取得

**期待される動作:**
- Apple認証フローが正常に完了
- Firestoreにユーザー情報が保存される
- MainTabViewに遷移

**確認すべきコンソールログ:**
```
✅ Auth: Apple Sign-In successful
✅ Firestore: User profile created/updated
🔄 NavigationManager: Transitioning to MainTab
```

**考えられる問題点:**
- Apple ID認証の失敗
- Firestore書き込み権限エラー
- ユーザープロフィール作成エラー

---

#### シナリオ2-2: サインアウト
**手順:**
1. 設定画面を開く
2. 「サインアウト」ボタンをタップ
3. ログイン画面への遷移確認

**期待される動作:**
- すべてのManagerがクリアされる
- 認証画面に戻る
- キャッシュデータがクリア

**確認すべきコンソールログ:**
```
🔄 Auth: Signing out user
✅ SharedManagerStore: Managers cleared
🔄 NavigationManager: Transitioning to Login
```

**考えられる問題点:**
- Manager状態のクリア不完全
- メモリリークの発生
- 画面遷移の失敗

---

### 3. データ操作テスト

#### シナリオ3-1: プロジェクト作成
**手順:**
1. プロジェクト一覧画面を開く
2. 「新規プロジェクト」ボタンをタップ
3. プロジェクト名を入力して保存

**期待される動作:**
- ProjectManagerが初期化される
- Firestoreにプロジェクトデータが保存される
- 一覧に新しいプロジェクトが表示される

**確認すべきコンソールログ:**
```
🔄 ProjectManager: Creating new project
✅ Firestore: Project saved successfully
🔄 UI: Project list updated
```

**考えられる問題点:**
- Firestore書き込み権限エラー
- データバリデーションエラー
- UI更新の失敗

---

#### シナリオ3-2: タスク作成・編集
**手順:**
1. タスク一覧画面を開く
2. 新規タスクを作成
3. タスクの詳細を編集
4. 完了状態を切り替え

**期待される動作:**
- TaskManagerが正常に動作
- リアルタイム同期が機能
- 家族間でのデータ共有が正常

**確認すべきコンソールログ:**
```
🔄 TaskManager: Creating task
✅ Firestore: Task synchronized
🔄 FirebaseListener: Real-time update received
```

**考えられる問題点:**
- リアルタイム同期の失敗
- 家族権限チェックエラー
- データ競合状態の発生

---

### 4. AI機能テスト

#### シナリオ4-1: AI設定画面
**手順:**
1. 設定画面からAI設定を開く
2. APIキーの設定
3. 設定の保存・検証

**期待される動作:**
- API設定画面が正常表示
- 設定が正しく保存される
- API接続テストが成功

**確認すべきコンソールログ:**
```
🔄 AIGenerator: Initializing with API settings
✅ API: Connection test successful
✅ Settings: AI configuration saved
```

**考えられる問題点:**
- APIキー検証エラー
- 設定保存の失敗
- セキュアストレージアクセスエラー

---

#### シナリオ4-2: タスク改善提案
**手順:**
1. 設定画面から「タスク改善提案」を開く
2. AI分析の実行
3. 改善提案の表示

**期待される動作:**
- 既存タスクの分析実行
- AI提案の生成と表示
- 提案の適用オプション表示

**確認すべきコンソールログ:**
```
🔄 AIGenerator: Analyzing existing tasks
🔄 API: Generating improvement suggestions
✅ AI: Suggestions generated successfully
```

**考えられる問題点:**
- API呼び出し制限エラー
- タスクデータ読み込み失敗
- レスポンス解析エラー

---

### 5. パフォーマンス・メモリテスト

#### シナリオ5-1: メモリ使用量監視
**手順:**
1. アプリを起動
2. 各画面を順次表示
3. メモリ警告をシミュレート
4. 自動クリーンアップの確認

**期待される動作:**
- メモリ使用量が適切に管理される
- 警告時に自動クリーンアップが実行
- 未使用Managerが解放される

**確認すべきコンソールログ:**
```
📊 Memory: Current usage: XXX MB
⚠️ Memory: Warning detected
🔄 SharedManagerStore: Cleanup unused managers
✅ Memory: Cleanup completed
```

**考えられる問題点:**
- メモリリークの発生
- Manager解放の失敗
- パフォーマンス監視の不正確さ

---

#### シナリオ5-2: パフォーマンス監視
**手順:**
1. パフォーマンス集約的な操作を実行
2. レスポンス時間の測定
3. UIフレームレートの確認

**期待される動作:**
- 操作レスポンスが適切な時間内
- UIが滑らかに動作
- パフォーマンス指標が正常範囲

**確認すべきコンソールログ:**
```
⚡ Performance: Operation completed in XXXms
📊 Performance: Frame rate: XX fps
✅ Performance: All metrics within acceptable range
```

**考えられる問題点:**
- レスポンス時間の遅延
- UIフレームドロップ
- バックグラウンド処理の不適切な実行

---

### 6. エラーハンドリングテスト

#### シナリオ6-1: ネットワークエラー
**手順:**
1. ネットワーク接続を切断
2. データ操作を実行
3. エラー処理の確認
4. ネットワーク復旧後の動作確認

**期待される動作:**
- 適切なエラーメッセージ表示
- オフライン状態での適切な動作
- 復旧時の自動同期

**確認すべきコンソールログ:**
```
❌ Network: Connection lost
🔄 Offline: Queuing operations for later sync
✅ Network: Connection restored
🔄 Sync: Resuming pending operations
```

**考えられる問題点:**
- エラー処理の不備
- オフラインデータ管理の失敗
- 同期復旧の失敗

---

#### シナリオ6-2: Firebaseエラー
**手順:**
1. 権限エラーを意図的に発生
2. クォータ制限エラーをシミュレート
3. 各種Firebase例外の処理確認

**期待される動作:**
- 各エラーに対する適切な処理
- ユーザーフレンドリーなエラー表示
- 自動リトライメカニズム

**確認すべきコンソールログ:**
```
❌ Firestore: Permission denied error
🔄 ErrorHandler: Attempting retry (1/3)
⚠️ Firestore: Quota exceeded
🔄 ErrorHandler: Scheduling retry for later
```

**考えられる問題点:**
- エラー分類の不適切さ
- リトライロジックの問題
- ユーザビリティの悪化

---

## テスト実行の進め方

### Phase 1: 基本機能テスト
1. シナリオ1-1, 1-2 (アプリ起動)
2. シナリオ2-1, 2-2 (認証機能)
3. 問題点の特定とイシュー化

### Phase 2: データ操作テスト
1. シナリオ3-1, 3-2 (データ操作)
2. コンソールログの詳細分析
3. 問題点の特定とイシュー化

### Phase 3: AI機能テスト
1. シナリオ4-1, 4-2 (AI機能)
2. API連携の検証
3. 問題点の特定とイシュー化

### Phase 4: パフォーマンステスト
1. シナリオ5-1, 5-2 (パフォーマンス)
2. メモリ・CPU使用量分析
3. 問題点の特定とイシュー化

### Phase 5: エラーハンドリングテスト
1. シナリオ6-1, 6-2 (エラー処理)
2. 各種例外状況のテスト
3. 問題点の特定とイシュー化

## 次のステップ
1. 各シナリオを順次実行
2. 問題点の詳細分析
3. GitHubイシューの作成
4. 優先順位付けと対応計画