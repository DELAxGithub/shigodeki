# 環境構築ガイド

シゴデキiOSプロジェクトの開発環境を構築する完全ガイドです。

## 🔗 関連情報

- 🛠️ [プロジェクト設定](./project-configuration.md) - 詳細設定手順
- 🧪 [テスト環境構築](./testing-setup.md) - XCTestセットアップ
- 📚 [開発原則](../../explanation/project-setup/development-principles.md) - プロジェクト方針

---

# Shigodeki iOS Project 環境構築

このガイドに従うことで、シゴデキiOSアプリの開発環境を完全にセットアップできます。

## 📋 前提条件

### 必要なツール
- **Xcode 15.0+**: iOS 17対応
- **macOS 14.0+**: 最新開発環境
- **Node.js 18+**: Firebase CLI用
- **Git**: バージョン管理

### アカウント要件
- **Apple Developer Account**: アプリ署名用
- **Firebase Console**: バックエンドサービス用
- **GitHub**: ソースコード管理用

## 🚀 Step 1: 基本ツールインストール

### Firebase CLI セットアップ
```bash
# Firebase CLI インストール
npm install -g firebase-tools

# Firebase ログイン
firebase login

# バージョン確認
firebase --version
```

### Xcode セットアップ
```bash
# Xcode Command Line Tools インストール
xcode-select --install

# Simulatorの確認
xcrun simctl list devices
```

## 🔥 Step 2: Firebase プロジェクト設定

### 開発・本番環境作成
```bash
# 開発環境プロジェクト作成
firebase projects:create shigodeki-dev --display-name "シゴデキ (Dev)"

# 本番環境プロジェクト作成  
firebase projects:create shigodeki-prod --display-name "シゴデキ (Prod)"

# プロジェクト一覧確認
firebase projects:list
```

### iOS アプリ登録
```bash
# プロジェクト選択 (開発環境)
firebase use shigodeki-dev

# iOS アプリ登録 (対話式)
firebase apps:create ios
# Bundle ID: com.company.shigodeki.dev
# App nickname: shigodeki-ios-dev

# 本番環境でも同じ手順
firebase use shigodeki-prod
firebase apps:create ios
# Bundle ID: com.company.shigodeki
# App nickname: shigodeki-ios-prod
```

### 設定ファイル配置
```bash
# 設定ディレクトリ作成
mkdir -p Firebase/Config

# GoogleService-Info.plist ファイルダウンロード
# Firebase Console → プロジェクト設定 → アプリ → 設定ファイルダウンロード

# ファイル配置
# 開発用: Firebase/Config/GoogleService-Info-Dev.plist
# 本番用: Firebase/Config/GoogleService-Info-Prod.plist
```

## 📱 Step 3: Xcode プロジェクト設定

### 1. プロジェクトオープン
```bash
# リポジトリクローン
git clone https://github.com/company/shigodeki.git
cd shigodeki

# Xcodeでプロジェクトを開く
open iOS/shigodeki.xcodeproj
```

### 2. Bundle Identifier 設定
- **Target選択**: shigodeki
- **General** → **Identity**
- **Bundle Identifier**:
  - Debug: `com.company.shigodeki.dev`
  - Release: `com.company.shigodeki`

### 3. Build Phase Script 追加

**Target** → **Build Phases** → **+** → **New Run Script Phase**

```bash
# Firebase 設定ファイル自動選択スクリプト
if [ "${CONFIGURATION}" == "Debug" ]; then
    cp "${SRCROOT}/Firebase/Config/GoogleService-Info-Dev.plist" "${SRCROOT}/shigodeki/GoogleService-Info.plist"
else
    cp "${SRCROOT}/Firebase/Config/GoogleService-Info-Prod.plist" "${SRCROOT}/shigodeki/GoogleService-Info.plist"
fi
```

**重要設定**:
- ✅ **Run script only when installing** のチェックを外す
- ✅ Script実行順序を **Copy Bundle Resources** の前に配置

### 4. Firebase SDK 追加

**File** → **Add Packages...**
- URL: `https://github.com/firebase/firebase-ios-sdk`
- Version: `10.15.0` (最新安定版)

**選択パッケージ**:
```
✅ FirebaseAuth
✅ FirebaseFirestore  
✅ FirebaseFirestoreSwift
```

### 5. App Delegate 設定

`shigodekiApp.swift` に Firebase 初期化追加:

```swift
import SwiftUI
import FirebaseCore

@main
struct shigodekiApp: App {
    init() {
        // Firebase 初期化
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## 🔐 Step 4: 認証設定

### Sign in with Apple 有効化

**Firebase Console**:
1. **Authentication** → **Sign-in method**
2. **Apple** を有効化
3. **Services ID** 設定 (必要に応じて)

**Xcode設定**:
1. **Target** → **Signing & Capabilities**
2. **+ Capability** → **Sign in with Apple**

## 🗄️ Step 5: Firestore 設定

### データベース作成
```bash
# Firestore データベース作成
firebase firestore:databases:create --project=shigodeki-dev
firebase firestore:databases:create --project=shigodeki-prod
```

### セキュリティルール設定

`firestore.rules` ファイル作成:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ユーザーは自分のデータにのみアクセス
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // 家族メンバーのみアクセス
    match /families/{familyId}/tasks/{document=**} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.memberIds;
    }
  }
}
```

## ✅ Step 6: 動作確認

### 1. ビルドテスト
```bash
# プロジェクトのビルド確認
xcodebuild -project iOS/shigodeki.xcodeproj -scheme shigodeki -sdk iphonesimulator -configuration Debug build
```

### 2. Firebase 接続確認

テスト用コード (`ContentView.swift`):
```swift
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @State private var isAuthenticated = false
    
    var body: some View {
        VStack {
            Text("シゴデキ開発環境")
            
            if isAuthenticated {
                Text("✅ Firebase 接続成功")
                    .foregroundColor(.green)
            } else {
                Text("🔄 Firebase 接続中...")
                    .foregroundColor(.orange)
            }
        }
        .onAppear {
            testFirebaseConnection()
        }
    }
    
    private func testFirebaseConnection() {
        // Firebase 接続テスト
        let db = Firestore.firestore()
        db.collection("test").document("connection").setData(["timestamp": Date()]) { error in
            if let error = error {
                print("❌ Firebase Error: \(error)")
            } else {
                print("✅ Firebase 接続成功")
                isAuthenticated = true
            }
        }
    }
}
```

### 3. 実行確認

**シミュレーターで実行**:
1. **Product** → **Run** (⌘R)
2. 「✅ Firebase 接続成功」メッセージ確認
3. Firebase Console でデータ書き込み確認

## 🎯 完了チェックリスト

### 環境構築完了確認
```yaml
✅ Firebase CLI インストール・認証完了
✅ Firebase プロジェクト作成（開発・本番）
✅ iOS アプリ登録（両環境）
✅ GoogleService-Info.plist ファイル設定
✅ Xcode プロジェクト設定完了
✅ Firebase SDK 追加・初期化
✅ Build Phase Script 動作確認
✅ Sign in with Apple 設定
✅ Firestore データベース作成
✅ セキュリティルール設定
✅ ビルド・実行テスト成功
```

### 次のステップ
- [📱 プロジェクト詳細設定](./project-configuration.md)
- [🧪 テスト環境構築](./testing-setup.md)
- [🛠️ 開発ガイド](../../guides/development/)

## 🚨 トラブルシューティング

### よくある問題

#### ビルドエラー: GoogleService-Info.plist not found
```bash
# 設定ファイル存在確認
ls -la iOS/shigodeki/GoogleService-Info.plist

# Build Phase Script 実行確認
# Target → Build Phases → Run Script で内容確認
```

#### Firebase 接続エラー
```bash
# プロジェクトID 確認
firebase use

# Firebase 設定確認  
firebase projects:list
```

#### Simulator 起動しない
```bash
# 利用可能なSimulator確認
xcrun simctl list devices

# Simulator リセット
xcrun simctl erase all
```

### サポート情報
- 🛠️ [ビルドエラー解決](../../guides/troubleshooting/build-errors.md)
- 📚 [Firebase トラブルシューティング](../../reference/firebase/troubleshooting.md)
- 💬 [開発チャット](https://discord.gg/shigodeki-dev)

---

**所要時間**: 約30分  
**難易度**: 初級  
**最終更新**: 2025-09-05