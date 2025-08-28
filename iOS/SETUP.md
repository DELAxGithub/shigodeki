# Shigodeki iOS Project Setup

## 完了済み設定

✅ Firebase CLI インストール・認証  
✅ Firebase プロジェクト作成（開発・本番）  
✅ iOS アプリ登録（両環境）  
✅ GoogleService-Info.plist ファイル設定  
✅ プロジェクト構造整理  

## Xcode での残り作業

### 1. Build Phase Script 追加
1. Xcodeでプロジェクトを開く
2. **Target** → **Build Phases** → **+** → **New Run Script Phase**
3. スクリプト欄に入力：
   ```bash
   ${SRCROOT}/Firebase/Scripts/copy-config.sh
   ```
4. **Run script only when installing** のチェックを外す

### 2. Firebase SDK 追加
1. **File** → **Add Packages...**
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. **Add Package** をクリック
4. 以下を選択：
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseFirestoreSwift`

### 3. Firebase 初期化コード追加
`shigodekiApp.swift` を編集：

```swift
import SwiftUI
import FirebaseCore

@main
struct shigodekiApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
```

### 4. Bundle ID 設定確認
- **Debug**: `com.hiroshikodera.shigodeki.dev`
- **Release**: `com.hiroshikodera.shigodeki` (本番用)

### 5. Firebase Console 設定
以下のコンソールで Authentication と Firestore を有効化：
- [開発環境](https://console.firebase.google.com/project/shigodeki-dev/overview)
- [本番環境](https://console.firebase.google.com/project/shigodeki-prod/overview)

## 動作確認
Debug ビルド → 開発環境接続  
Release ビルド → 本番環境接続

詳細は `Firebase/README.md` を参照してください。