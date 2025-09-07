# デバッグ設定 - SIGABRT/メモリリーク対策

## A. Xcode Scheme 設定（必須）

1. Product → Scheme → Edit Scheme...
2. Run → Diagnostics タブ

### 必須設定
```
✅ Malloc Scribble            (Use after free 検出)
✅ Malloc Guard Malloc        (バッファオーバーラン検出) 
✅ Guard Malloc               (Simulator専用)
✅ Zombie Objects             (解放済みオブジェクトアクセス検出)
✅ Malloc Stack Logging: Lite (既に有効 - メモリ追跡)
```

### 並行処理が多い場合の追加設定
```
✅ Address Sanitizer          (メモリ破損検出 - パフォーマンス低下あり)
✅ Thread Sanitizer          (レースコンディション検出 - Address Sanitizer と排他)
```

### Exception Breakpoint 追加
1. Breakpoint Navigator (⌘+7)
2. + ボタン → Exception Breakpoint
3. Exception: All
4. Break: On Throw

## B. ランタイムチェック

デバッグビルド時に以下のチェックが自動実行されます：

### メモリリーク検出
- TagManager の参照カウント監視
- Task・Timer・Listener の適切な解放確認

### デッドロック検出  
- SharedManagerStore のプリロード状態監視
- メインスレッドブロック検出（250ms超過）

### Firebase リスナー監視
- 重複登録防止
- 適切な remove() 呼び出し確認

## C. クラッシュ時の解析手順

1. **Zombies でクラッシュした場合**
   - Console に解放済みオブジェクトへのアクセス詳細が表示される
   - スタックトレースから原因メソッドを特定

2. **Thread Sanitizer でクラッシュした場合** 
   - レースコンディションの詳細ログが表示される
   - どのスレッドがどの変数に同時アクセスしたかが判明

3. **Address Sanitizer でクラッシュした場合**
   - メモリ破損の詳細（どこで確保、どこで解放、どこで不正アクセス）が表示される

## D. パフォーマンス監視

### メインスレッドブロック監視
```swift
// 250ms以上のブロックを検出
Instruments: Main Thread Checker
```

### メモリ使用量監視  
```swift
// 現在のメモリ使用量表示（デバッグ時）
SharedManagerStore.shared.getCurrentMemoryUsage()
```

## E. 修正済み問題

### ✅ TagManager Memory Leak
- **原因**: Task の強参照サイクル、fallback polling の無限ループ
- **修正**: weak self、proper task cancellation

### ✅ SharedManagerStore Deadlock
- **原因**: プリロード完了フラグが立たない、concurrent preload calls
- **修正**: Single-flight pattern、適切な Task 管理

### ✅ IntegratedPerformanceMonitor Infinite Loop
- **原因**: isPreloaded が false のまま infinite waiting
- **修正**: MainTabView での preload() 呼び出し追加