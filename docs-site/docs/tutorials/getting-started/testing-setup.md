# テスト環境構築

XCTestとFirebase Emulatorを使用した包括的テスト環境の構築手順です。

## 🔗 関連情報

- 🛠️ [環境構築](./environment-setup.md) - 基本環境セットアップ
- 📚 [テスト手法](../../guides/testing/methodologies.md) - テスト戦略
- 💡 [開発原則](../../explanation/project-setup/development-principles.md) - TDD原則

---

# XCTest セットアップ完全ガイド

現代的なXCTestインフラストラクチャとFirebaseテスト環境を構築します。

## 📋 テスト機能概要

構築されるテスト機能:
- ✅ XCTest ユニット・統合テスト
- ✅ SwiftUI ViewInspector テスト
- ✅ Firebase Local Emulator Suite
- ✅ メモリリーク検知
- ✅ Async/await テストパターン
- ✅ パフォーマンステスト

## 🚀 Step 1: テストターゲット追加

### Xcodeでテストターゲット作成

1. **Xcodeプロジェクトを開く** (`shigodeki.xcodeproj`)
2. **File → New → Target**
3. **Unit Testing Bundle** (iOS) を選択
4. **設定入力**:
   ```
   Product Name: shigodekiTests
   Team: Your development team
   Bundle Identifier: com.company.shigodeki.tests
   Language: Swift
   ```

### テストターゲット設定

**Build Settings 設定**:
- **Deployment Target**: iOS 15.0
- **Swift Language Version**: Swift 5
- **Enable Testing**: Yes

## 📦 Step 2: テスト依存関係追加

### Swift Package Manager 依存関係

**File → Add Packages** で以下を追加:

```
1. ViewInspector (SwiftUI テスト)
   URL: https://github.com/nalexn/ViewInspector
   Version: 0.9.9+

2. Firebase iOS SDK (既に追加済み)
   テストターゲットに追加:
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseFirestoreSwift
```

### テストターゲットの依存関係設定

**Project Settings → shigodekiTests → Build Phases**:

**Link Binary With Libraries** に追加:
- ✅ XCTest.framework
- ✅ ViewInspector
- ✅ FirebaseAuth
- ✅ FirebaseFirestore
- ✅ FirebaseFirestoreSwift

## ⚙️ Step 3: Firebase Test Configuration

### Firebase Emulator Suite セットアップ

```bash
# Firebase CLI でエミュレーター初期化
cd /path/to/your/project
firebase init emulators

# 選択するエミュレーター:
# ✅ Authentication Emulator (port: 9099)
# ✅ Firestore Emulator (port: 8080)
# ✅ Emulator UI (port: 4000)
```

### firebase.json 設定

```json
{
  "emulators": {
    "auth": {
      "port": 9099
    },
    "firestore": {
      "port": 8080
    },
    "ui": {
      "enabled": true,
      "port": 4000
    },
    "singleProjectMode": true
  }
}
```

### テスト用 Firebase 設定

`FirebaseTestHelper.swift` 作成:

```swift
import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

class FirebaseTestHelper {
    static let shared = FirebaseTestHelper()
    
    private init() {}
    
    func configureForTesting() {
        // テスト用 Firebase 設定
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Emulator 接続設定
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)
        
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings
    }
    
    func clearFirestore() async throws {
        let db = Firestore.firestore()
        // テストデータクリア実装
        try await db.clearPersistence()
    }
    
    func createTestUser() async throws -> User {
        let auth = Auth.auth()
        let result = try await auth.signInAnonymously()
        return result.user
    }
}
```

## 🧪 Step 4: テストクラス作成

### 基本テストクラステンプレート

`BaseTestCase.swift`:

```swift
import XCTest
import FirebaseAuth
import FirebaseFirestore
@testable import shigodeki

class BaseTestCase: XCTestCase {
    
    override func setUpWithError() throws {
        super.setUp()
        
        // Firebase テスト設定
        FirebaseTestHelper.shared.configureForTesting()
        
        // 非同期テストタイムアウト設定
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
        
        // テスト後クリーンアップ
        Task {
            try? await FirebaseTestHelper.shared.clearFirestore()
            try? Auth.auth().signOut()
        }
    }
    
    // MARK: - Test Helpers
    
    func createTestTask() -> ShigodekiTask {
        return ShigodekiTask(
            id: UUID().uuidString,
            title: "Test Task",
            isCompleted: false,
            tags: ["test"],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func waitForAsync<T>(_ operation: @escaping () async throws -> T, timeout: TimeInterval = 10.0) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw XCTError(.timeoutWhileWaiting)
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
```

### SwiftUI View テスト

`ViewTestCase.swift`:

```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import shigodeki

final class ViewTestCase: BaseTestCase {
    
    func testTaskRowView() throws {
        // Given
        let task = createTestTask()
        
        // When
        let view = TaskRowView(task: task)
        
        // Then
        let taskTitle = try view.inspect().find(text: task.title)
        XCTAssertNoThrow(try taskTitle.string())
    }
    
    func testTaskListView() throws {
        // Given
        let tasks = [createTestTask(), createTestTask()]
        
        // When  
        let view = TaskListView(tasks: tasks)
        
        // Then
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertEqual(try list.count(), tasks.count)
    }
    
    func testAsyncViewLoading() async throws {
        // Given
        let viewModel = TaskListViewModel()
        
        // When
        let view = TaskListView(viewModel: viewModel)
        
        // Wait for async loading
        let expectation = view.on(\.didAppear) { view in
            // Verify loading state
            XCTAssertNoThrow(try view.find(text: "Loading..."))
        }
        
        ViewHosting.host(view: view)
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}
```

### Firebase データテスト

`FirebaseTestCase.swift`:

```swift
import XCTest
import FirebaseFirestore
@testable import shigodeki

final class FirebaseTestCase: BaseTestCase {
    
    func testTaskCreation() async throws {
        // Given
        let user = try await FirebaseTestHelper.shared.createTestUser()
        let taskManager = TaskManager()
        let task = createTestTask()
        
        // When
        try await taskManager.createTask(task, userId: user.uid)
        
        // Then
        let savedTask = try await taskManager.getTask(task.id, userId: user.uid)
        XCTAssertEqual(savedTask?.title, task.title)
        XCTAssertEqual(savedTask?.tags, task.tags)
    }
    
    func testTaskUpdate() async throws {
        // Given
        let user = try await FirebaseTestHelper.shared.createTestUser()
        let taskManager = TaskManager()
        var task = createTestTask()
        try await taskManager.createTask(task, userId: user.uid)
        
        // When
        task.title = "Updated Title"
        task.tags = ["updated", "test"]
        try await taskManager.updateTask(task, userId: user.uid)
        
        // Then
        let updatedTask = try await taskManager.getTask(task.id, userId: user.uid)
        XCTAssertEqual(updatedTask?.title, "Updated Title")
        XCTAssertEqual(updatedTask?.tags, ["updated", "test"])
    }
    
    func testFirestoreRules() async throws {
        // Given
        let user1 = try await FirebaseTestHelper.shared.createTestUser()
        let user2 = try await FirebaseTestHelper.shared.createTestUser()
        let taskManager = TaskManager()
        let task = createTestTask()
        
        // When - User1 creates task
        try await taskManager.createTask(task, userId: user1.uid)
        
        // Then - User2 cannot access User1's task
        do {
            _ = try await taskManager.getTask(task.id, userId: user2.uid)
            XCTFail("Should not be able to access other user's task")
        } catch {
            // Expected behavior
            XCTAssert(true, "Correctly denied access to other user's task")
        }
    }
}
```

## 🎯 Step 5: メモリリーク検知

### メモリリークテスト

`MemoryLeakTestCase.swift`:

```swift
import XCTest
@testable import shigodeki

final class MemoryLeakTestCase: XCTestCase {
    
    func testTaskManagerMemoryLeak() {
        // Given
        var taskManager: TaskManager? = TaskManager()
        weak var weakTaskManager = taskManager
        
        // When
        taskManager = nil
        
        // Then
        XCTAssertNil(weakTaskManager, "TaskManager should be deallocated")
    }
    
    func testViewModelMemoryLeak() {
        // Given
        var viewModel: TaskListViewModel? = TaskListViewModel()
        weak var weakViewModel = viewModel
        
        // When
        viewModel = nil
        
        // Then
        XCTAssertNil(weakViewModel, "ViewModel should be deallocated")
    }
    
    func testAsyncTaskMemoryLeak() async {
        // Given
        var taskManager: TaskManager? = TaskManager()
        weak var weakTaskManager = taskManager
        
        // When - Simulate async operation
        let task = ShigodekiTask(id: "test", title: "Test", isCompleted: false, tags: [], createdAt: Date(), updatedAt: Date())
        
        taskManager?.processTask(task) { result in
            // Completion handler should not retain taskManager
        }
        
        taskManager = nil
        
        // Wait for async operations to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Then
        XCTAssertNil(weakTaskManager, "TaskManager should be deallocated even with pending async operations")
    }
}
```

## ⚡ Step 6: パフォーマンステスト

### パフォーマンス測定テスト

`PerformanceTestCase.swift`:

```swift
import XCTest
@testable import shigodeki

final class PerformanceTestCase: BaseTestCase {
    
    func testTaskCreationPerformance() async throws {
        // Given
        let user = try await FirebaseTestHelper.shared.createTestUser()
        let taskManager = TaskManager()
        
        // When & Then
        measure {
            Task {
                let task = createTestTask()
                try? await taskManager.createTask(task, userId: user.uid)
            }
        }
    }
    
    func testLargeDataSetPerformance() {
        // Given
        let tasks = (0..<1000).map { _ in createTestTask() }
        
        // When & Then
        measure {
            let filtered = tasks.filter { !$0.isCompleted }
            XCTAssertNotNil(filtered)
        }
    }
}
```

## 🛠️ Step 7: テストスクリプト作成

### テスト実行スクリプト

`run-tests.sh`:

```bash
#!/bin/bash

set -e

echo "🧪 シゴデキ iOS テスト実行"

# Firebase Emulator 起動
echo "🔥 Firebase Emulator 起動中..."
firebase emulators:start --only auth,firestore &
EMULATOR_PID=$!

# Emulator の起動待ち
sleep 5

# テスト実行
echo "🧪 テスト実行中..."
xcodebuild \
  -project iOS/shigodeki.xcodeproj \
  -scheme shigodeki \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
  -configuration Debug \
  -enableCodeCoverage YES \
  test

# テスト結果
echo "📊 テストカバレッジレポート生成..."
xcrun xccov view --report --json DerivedData/shigodeki/Logs/Test/*.xcresult > coverage.json

# Emulator 停止
echo "🔥 Firebase Emulator 停止中..."
kill $EMULATOR_PID

echo "✅ テスト完了!"
```

実行権限付与:
```bash
chmod +x run-tests.sh
```

## 🎯 Step 8: 継続的インテグレーション

### GitHub Actions 設定

`.github/workflows/ios-tests.yml`:

```yaml
name: iOS Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Select Xcode
      run: sudo xcode-select -switch /Applications/Xcode_15.0.app
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        
    - name: Install Firebase CLI
      run: npm install -g firebase-tools
    
    - name: Cache Firebase Emulators
      uses: actions/cache@v3
      with:
        path: ~/.cache/firebase/emulators
        key: firebase-emulators-${{ runner.os }}
    
    - name: Start Firebase Emulators
      run: firebase emulators:start --only auth,firestore --project demo-test &
    
    - name: Run Tests
      run: |
        xcodebuild \
          -project iOS/shigodeki.xcodeproj \
          -scheme shigodeki \
          -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
          -configuration Debug \
          -enableCodeCoverage YES \
          test
    
    - name: Upload Coverage
      uses: codecov/codecov-action@v3
      with:
        files: ./coverage.json
```

## ✅ 完了チェックリスト

### テスト環境完了確認
```yaml
✅ XCTest ターゲット作成・設定
✅ ViewInspector 依存関係追加
✅ Firebase Emulator Suite 設定
✅ テストヘルパークラス作成
✅ ユニットテストクラス作成
✅ SwiftUI View テスト実装
✅ Firebase データテスト実装
✅ メモリリーク検知テスト
✅ パフォーマンステスト設定
✅ テスト実行スクリプト作成
✅ CI/CD パイプライン設定
```

### テスト実行確認
```bash
# ローカルテスト実行
./run-tests.sh

# 個別テスト実行
xcodebuild test -project iOS/shigodeki.xcodeproj -scheme shigodeki -destination 'platform=iOS Simulator,name=iPhone 15'

# テストカバレッジ確認
open DerivedData/shigodeki/Logs/Test/*.xcresult
```

## 🚨 トラブルシューティング

### よくある問題

#### Emulator 接続エラー
```bash
# Emulator 状態確認
firebase emulators:start --only auth,firestore

# ポート確認
lsof -i :8080
lsof -i :9099
```

#### ViewInspector エラー
```swift
// SwiftUI View の inspect 前に必要
extension YourView: Inspectable { }
```

#### 非同期テストタイムアウト
```swift
// より長いタイムアウト設定
let expectation = XCTestExpectation(description: "async operation")
await fulfillment(of: [expectation], timeout: 30.0)
```

---

**所要時間**: 約60分  
**難易度**: 中級  
**最終更新**: 2025-09-05