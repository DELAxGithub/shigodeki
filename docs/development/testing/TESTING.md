# シゴデキ iOS テストフレームワーク

包括的なiOSアプリテストシステム - メモリリーク検出、テンプレートシステム検証、自動化テスト

## 📋 セットアップ

### 1. Xcodeでテストターゲット追加

**重要**: 現在、テストファイルは作成されていますが、Xcodeプロジェクトにテストターゲットを追加する必要があります。

1. **Xcode で `shigodeki.xcodeproj` を開く**
2. **File → New → Target**
3. **Unit Testing Bundle** を選択
4. **Product Name**: `shigodekiTests`
5. **Team と Language**: 既存設定と同じ
6. **Finish** をクリック

### 2. テストファイルをXcodeプロジェクトに追加

1. **Xcode Project Navigator でテストターゲットを右クリック**
2. **Add Files to "shigodeki"** を選択
3. **`shigodekiTests` フォルダ全体を選択**
4. **Target: `shigodekiTests` にチェック**
5. **Add** をクリック

### 3. 依存関係追加 (オプション)

ViewInspectorをSwiftUI テスト用に追加：

1. **File → Add Package Dependencies**
2. **URL**: `https://github.com/nalexn/ViewInspector`
3. **テストターゲットのみに追加**

## 🚀 テスト実行方法

### 自動化テストランナー（推奨）

```bash
# 全テスト実行
./run-tests.sh all

# メモリリークテストのみ
./run-tests.sh memory

# 統合テストのみ  
./run-tests.sh integration

# 詳細出力付きで実行
./run-tests.sh all --verbose

# カバレッジレポート生成
./run-tests.sh all --coverage

# クリーンビルドしてテスト
./run-tests.sh all --clean
```

### Xcodeでのテスト実行

1. **Product → Test (⌘+U)**
2. **特定テストクラス実行**: テストナビゲーターでクラス名をクリック
3. **メモリリーク検出**: `SubtaskManagerMemoryTests` クラスを実行

### コマンドラインでの直接実行

```bash
# プロジェクトビルド
xcodebuild build-for-testing \
  -project shigodeki.xcodeproj \
  -scheme shigodeki \
  -destination "platform=iOS Simulator,name=iPhone 16"

# テスト実行
xcodebuild test-without-building \
  -project shigodeki.xcodeproj \
  -scheme shigodeki \
  -destination "platform=iOS Simulator,name=iPhone 16"
```

## 🧪 テストカテゴリ

### Memory Tests (`/Memory/`)
- **SubtaskManagerMemoryTests**: 循環参照とメモリリーク検出
- **重要**: 修正したSubtaskManagerの `deinit` 問題を検証
- **回帰テスト**: `deinit { Task { @MainActor in } }` パターンの修正検証

### Integration Tests (`/Integration/`)
- **TemplateSystemTests**: テンプレートインポート/エクスポート
- **Firebase統合テスト**: Firestore操作とリスナー管理
- **状態同期テスト**: "No template selected" バグの修正検証

### Unit Tests (`/Unit/`)
- **SwiftUI View テスト**: 個別コンポーネントの動作検証
- **Model テスト**: データモデルの検証とバリデーション

## 🔧 メモリリーク検出機能

### 自動メモリリーク追跡

```swift
func testSubtaskManagerMemoryLeak() {
    let manager = SubtaskManager()
    
    // 自動的にメモリリークを追跡
    trackForMemoryLeak(manager)
    
    // テスト終了時に自動的にdeallocationを確認
}
```

### メモリ使用量監視

```swift
func testMemoryUsage() {
    // 最大50MBまで許可
    trackMemoryUsage(maxMemoryMB: 50.0)
    
    // テストロジック...
}
```

### SwiftUI View メモリテスト

```swift
func testViewMemoryLeak() {
    testViewForMemoryLeak {
        ContentView()
            .environmentObject(MockManager())
    }
}
```

## 📊 テスト結果の解釈

### 成功ログ例

```
✅ All tests passed! 🎉
ℹ️  Memory usage check:
Test runner memory usage: 45.2 MB
✅ No memory leaks detected
Ready for deployment! ✅
```

### メモリリーク検出例

```
⚠️  Potential memory leak detected in memory_tests.log
memory_tests.log:45: Instance should have been deallocated. Potential memory leak detected.
❌ Memory tests failed
```

### パフォーマンス指標

```
ℹ️  Test Performance Metrics:
Total log lines: 1,250
Build directory size: 125M
Test runner memory usage: 32.4 MB
```

## 🐛 トラブルシューティング

### よくある問題

1. **"Build failed" エラー**
   ```bash
   # クリーンビルドを試す
   ./run-tests.sh all --clean
   ```

2. **シミュレーター関連エラー**
   ```bash
   # 利用可能デバイス確認
   xcrun simctl list devices
   
   # 特定デバイス指定
   ./run-tests.sh all --device "iPhone 15"
   ```

3. **メモリリーク誤検出**
   ```bash
   # より長い待機時間でテスト
   ./run-tests.sh memory --verbose
   ```

### ログファイル確認

テスト実行後、以下の場所にログが保存されます：

```
./build/
├── build.log           # ビルドログ
├── unit_tests.log      # ユニットテストログ
├── integration_tests.log # 統合テストログ  
├── memory_tests.log    # メモリテストログ
└── Coverage/           # カバレッジレポート
    ├── coverage.json
    └── coverage.txt
```

## 🔄 CI/CD統合

### GitHub Actions（推奨設定）

```yaml
name: iOS Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - name: Run Tests
      run: |
        cd iOS
        ./run-tests.sh all --coverage
    - name: Upload Coverage
      uses: actions/upload-artifact@v3
      with:
        name: coverage-report
        path: iOS/build/Coverage/
```

## 📈 継続的改善

### テスト追加ガイドライン

1. **新機能**: 必ずメモリリークテストを追加
2. **バグ修正**: 回帰テストを作成
3. **パフォーマンス**: ベンチマークテストを実装

### カバレッジ目標

- **ユニットテスト**: 80%以上
- **統合テスト**: 70%以上  
- **メモリテスト**: クリティカルパス100%

## 🎯 重要な検証ポイント

このテストフレームワークは特に以下の修正された問題を検証します：

1. **SubtaskManager メモリリーク**: `retain count 2 deallocated` 問題
2. **Template Selection**: "No template selected" エラー
3. **Auto Layout競合**: SignInWithAppleButton制約問題

定期的にこれらのテストを実行して、回帰を防ぎましょう！