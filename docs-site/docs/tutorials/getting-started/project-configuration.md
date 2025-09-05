# プロジェクト設定詳細

Xcodeプロジェクトの詳細設定とビルドシステム最適化ガイドです。

## 🔗 関連情報

- 🛠️ [環境構築](./environment-setup.md) - 基本環境セットアップ
- 🧪 [テスト環境構築](./testing-setup.md) - XCTestセットアップ
- 📚 [開発原則](../../explanation/project-setup/development-principles.md) - TDD原則

---

# Xcode Project Configuration 完全ガイド

環境構築後のプロジェクト詳細設定とビルドシステム最適化を実行します。

## 📋 設定項目概要

構築される設定:
- ✅ Bundle Identifier環境分離
- ✅ Build Configuration最適化
- ✅ Code Signing自動化
- ✅ Build Phase Script自動化
- ✅ Scheme設定環境切り替え
- ✅ Info.plist環境管理

## 🚀 Step 1: Bundle Identifier設定

### 環境別Bundle ID設定

**Target Settings → General → Identity**:

**Debug Configuration**:
```
Bundle Identifier: com.hiroshikodera.shigodeki.dev
Display Name: シゴデキ (Dev)
Version: 1.0.0
Build: 1
```

**Release Configuration**:
```
Bundle Identifier: com.hiroshikodera.shigodeki
Display Name: シゴデキ
Version: 1.0.0
Build: 1
```

### Build Settings調整

**Target → Build Settings**で以下を設定:

**Debug**:
- `PRODUCT_BUNDLE_IDENTIFIER`: `com.hiroshikodera.shigodeki.dev`
- `PRODUCT_NAME`: `shigodeki-dev`
- `SWIFT_COMPILATION_MODE`: `singlefile`
- `SWIFT_OPTIMIZATION_LEVEL`: `-Onone`

**Release**:
- `PRODUCT_BUNDLE_IDENTIFIER`: `com.hiroshikodera.shigodeki`
- `PRODUCT_NAME`: `shigodeki`
- `SWIFT_COMPILATION_MODE`: `wholemodule`
- `SWIFT_OPTIMIZATION_LEVEL`: `-O`

## ⚙️ Step 2: Build Phase Script設定

### Firebase設定自動切り替えスクリプト

**Target → Build Phases → + → New Run Script Phase**:

**スクリプト名**: `Firebase Config Switcher`

**スクリプト内容**:
```bash
#!/bin/bash

set -e

echo "🔥 Firebase設定ファイル切り替え中..."

CONFIG_DIR="${SRCROOT}/Firebase/Config"
TARGET_PATH="${SRCROOT}/shigodeki/GoogleService-Info.plist"

if [ "${CONFIGURATION}" == "Debug" ]; then
    SOURCE_FILE="${CONFIG_DIR}/GoogleService-Info-Dev.plist"
    echo "✅ 開発環境設定を使用: ${SOURCE_FILE}"
else
    SOURCE_FILE="${CONFIG_DIR}/GoogleService-Info-Prod.plist"
    echo "✅ 本番環境設定を使用: ${SOURCE_FILE}"
fi

if [ ! -f "${SOURCE_FILE}" ]; then
    echo "❌ エラー: 設定ファイルが見つかりません: ${SOURCE_FILE}"
    exit 1
fi

cp "${SOURCE_FILE}" "${TARGET_PATH}"
echo "✅ Firebase設定ファイルコピー完了"
```

**実行順序**: 
- **Copy Bundle Resources** フェーズより **前** に配置
- **Run script only when installing** チェックを **外す**

### ビルド番号自動更新スクリプト

**スクリプト名**: `Auto Increment Build Number`

**スクリプト内容**:
```bash
#!/bin/bash

if [ "${CONFIGURATION}" == "Release" ]; then
    buildNumber=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${INFOPLIST_FILE}")
    buildNumber=$(($buildNumber + 1))
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "${INFOPLIST_FILE}"
    echo "✅ ビルド番号を $buildNumber に更新"
fi
```

## 🎯 Step 3: Scheme環境設定

### Debug Scheme設定

**Product → Scheme → Edit Scheme → Run**:

**Environment Variables**:
```
FIREBASE_ENV = dev
DEBUG_MODE = 1
LOG_LEVEL = verbose
```

**Arguments Passed On Launch**:
```
-com.apple.CoreData.SQLDebug 1
-com.apple.CoreData.ConcurrencyDebug 1
```

### Release Scheme設定

**Product → Scheme → Edit Scheme → Archive**:

**Environment Variables**:
```
FIREBASE_ENV = prod
RELEASE_MODE = 1
LOG_LEVEL = error
```

**Build Configuration**: `Release`

## 📱 Step 4: Info.plist環境管理

### 環境別Info.plist設定

**Info.plist Configuration**:

**共通設定**:
```xml
<key>CFBundleDevelopmentRegion</key>
<string>ja_JP</string>
<key>CFBundleDisplayName</key>
<string>$(PRODUCT_NAME)</string>
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
<key>CFBundleVersion</key>
<string>$(CURRENT_PROJECT_VERSION)</string>
<key>CFBundleShortVersionString</key>
<string>$(MARKETING_VERSION)</string>
```

**Firebase設定**:
```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
<key>FirebaseDataCollectionDefaultEnabled</key>
<false/>
<key>FirebaseAutomaticScreenReportingEnabled</key>
<false/>
```

### URL Scheme設定

**URL Types**に追加:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>shigodeki</string>
        </array>
    </dict>
</array>
```

## 🔐 Step 5: Code Signing設定

### 開発証明書設定

**Target → Signing & Capabilities**:

**Debug**:
- **Team**: Your Development Team
- **Signing Certificate**: Apple Development
- **Provisioning Profile**: Automatic

**Release**:
- **Team**: Your Development Team  
- **Signing Certificate**: Apple Distribution
- **Provisioning Profile**: Automatic

### Capabilities追加

**Required Capabilities**:
- ✅ **Sign in with Apple**
- ✅ **Push Notifications** (将来対応)
- ✅ **Background Modes**: Background processing
- ✅ **Keychain Sharing**

## 🧪 Step 6: テスト設定統合

### Test Target設定

**shigodekiTests Target → Build Settings**:

**Test Configuration**:
- `BUNDLE_LOADER`: `$(TEST_HOST)`
- `TEST_HOST`: `$(BUILT_PRODUCTS_DIR)/shigodeki.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/shigodeki`
- `WRAPPER_EXTENSION`: `xctest`

### Test Scheme環境変数

**Test Scheme → Environment Variables**:
```
UNIT_TESTING = 1
USE_FIREBASE_EMULATOR = 1
FIREBASE_EMULATOR_HOST = localhost
FIREBASE_AUTH_EMULATOR_HOST = localhost:9099
FIRESTORE_EMULATOR_HOST = localhost:8080
```

## 📦 Step 7: Archive & Distribution

### Archive設定最適化

**Product → Archive** 前の確認:

**Pre-Archive Checklist**:
- ✅ Scheme が `Release` Configuration
- ✅ Bundle Identifier が本番用
- ✅ Code Signing が Distribution証明書
- ✅ Firebase設定が本番環境
- ✅ すべてのテストがパス

### Export Options設定

**Archive → Distribute App**での推奨設定:

**App Store Distribution**:
```
Method: App Store Connect
Upload Symbols: Yes
Manage Version and Build Number: Yes
Strip Swift Symbols: Yes
```

**Ad Hoc Distribution** (テスト用):
```
Method: Ad Hoc
Include Bitcode: No (iOS 14+)
Rebuild from Bitcode: No
Strip Swift Symbols: No (デバッグ用)
```

## ✅ 設定完了チェックリスト

### プロジェクト設定完了確認

```yaml
✅ Bundle Identifier環境分離設定
✅ Build Phase Script自動実行
✅ Firebase設定自動切り替え確認
✅ ビルド番号自動更新動作
✅ Scheme環境変数設定完了
✅ Info.plist環境管理設定
✅ Code Signing自動化確認
✅ Test Target統合完了
✅ Archive設定最適化完了
```

### 動作確認テスト

```bash
# Debug Build テスト
xcodebuild -project iOS/shigodeki.xcodeproj -scheme shigodeki -configuration Debug -sdk iphonesimulator

# Release Build テスト  
xcodebuild -project iOS/shigodeki.xcodeproj -scheme shigodeki -configuration Release -sdk iphonesimulator

# Test実行テスト
xcodebuild test -project iOS/shigodeki.xcodeproj -scheme shigodeki -destination 'platform=iOS Simulator,name=iPhone 15'

# Archive テスト
xcodebuild archive -project iOS/shigodeki.xcodeproj -scheme shigodeki -archivePath build/shigodeki.xcarchive
```

## 🚨 トラブルシューティング

### よくある問題と解決法

#### Code Signing エラー
```bash
# 証明書確認
security find-identity -v -p codesigning

# Keychain確認
security list-keychains

# Provisioning Profile確認
ls ~/Library/MobileDevice/Provisioning\ Profiles/
```

#### Build Script エラー
```bash
# スクリプト実行権限確認
chmod +x "${SRCROOT}/scripts/firebase-config-switcher.sh"

# パス確認
echo "SRCROOT: ${SRCROOT}"
echo "CONFIGURATION: ${CONFIGURATION}"
```

#### Firebase設定エラー
```bash
# GoogleService-Info.plist存在確認
ls -la "${SRCROOT}/shigodeki/GoogleService-Info.plist"

# Firebase Project ID確認
/usr/libexec/PlistBuddy -c "Print PROJECT_ID" "${SRCROOT}/shigodeki/GoogleService-Info.plist"
```

#### Archive失敗
```bash
# Clean Build Folder
Product → Clean Build Folder (⇧⌘K)

# Derived Data削除
rm -rf ~/Library/Developer/Xcode/DerivedData

# Archive再実行
Product → Archive
```

## 🎯 次のステップ

### 開発フロー確立
- [📱 iOS開発ガイド](../../guides/development/ios-workflows.md)
- [🧪 テスト戦略](../../guides/testing/methodologies.md)
- [🚀 デプロイ手順](../../guides/deployment/appstore-submission.md)

### 品質向上
- [🔍 コード品質管理](../../guides/quality/code-standards.md)
- [⚡ パフォーマンス最適化](../../guides/performance/optimization-strategies.md)
- [🛡️ セキュリティ強化](../../guides/security/best-practices.md)

---

**所要時間**: 約45分  
**難易度**: 中級  
**最終更新**: 2025-09-05