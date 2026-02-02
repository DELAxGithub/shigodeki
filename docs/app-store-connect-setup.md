# App Store Connect セットアップガイド

このドキュメントでは、ShigodekiをTestFlight経由で配信するためのApp Store Connect設定手順を説明します。

---

## 事前準備

### 必要なもの
- Apple Developer Program メンバーシップ（年間$99）
- Xcode 15.0以上
- macOS 14.0 (Sonoma) 以上
- App Store Connectへのアクセス権限（Admin/App Manager/Developer）

### アカウント情報
| 項目 | 値 |
|------|-----|
| Bundle ID | `com.hiroshikodera.shigodeki` |
| App Name | シゴデキ！ |
| Primary Language | Japanese |
| Category | Productivity |

---

## 1. App Store Connectでアプリを登録

### 1.1 新規アプリの作成

1. [App Store Connect](https://appstoreconnect.apple.com) にログイン
2. 「マイ App」→「+」→「新規 App」を選択
3. 以下の情報を入力:

| フィールド | 値 |
|-----------|-----|
| プラットフォーム | iOS |
| 名前 | シゴデキ！ |
| プライマリ言語 | 日本語 |
| バンドル ID | com.hiroshikodera.shigodeki |
| SKU | shigodeki-ios |
| ユーザーアクセス | フルアクセス |

### 1.2 App情報の設定

「App 情報」タブで以下を設定:

- **カテゴリ**: 仕事効率化 (Productivity)
- **サブカテゴリ**: ライフスタイル（任意）
- **コンテンツ権限**: 自社開発であることを確認
- **年齢制限**: 4+ （暴力・性的コンテンツなし）

---

## 2. TestFlight設定

### 2.1 内部テスター（Internal Testing）

内部テスターは即座にビルドにアクセスできます（審査不要）。

1. 「TestFlight」タブを開く
2. 「内部テスト」→「グループを作成」
3. グループ名: "Shigodeki Dev Team"
4. テスターを追加（App Store Connect ユーザーのみ）

**制限事項**:
- 最大100人まで
- App Store Connectのロールが必要

### 2.2 外部テスター（External Testing）

外部テスターは初回ビルドのみApple審査が必要です（通常24-48時間）。

1. 「外部テスト」→「グループを作成」
2. グループ名: "Beta Testers"
3. 公開リンクを有効化（推奨）

**公開リンクの設定**:
- 最大招待数: 10,000人
- リンク有効化後、誰でも参加可能
- URLをSNS等で共有可能

### 2.3 テスト情報（Beta App Information）

「テスト情報」セクションで以下を設定:

| フィールド | 値 |
|-----------|-----|
| ベータ版の説明 | 家族向けプロジェクト管理アプリのベータ版です。コアフローのテストにご協力ください。 |
| フィードバックメール | (開発者メールアドレス) |
| マーケティングURL | (任意) |
| プライバシーポリシーURL | (必須 - 外部テスト時) |

---

## 3. ビルドのアップロード

### 3.1 スクリプトを使用

```bash
cd /path/to/shigodeki

# アーカイブ作成
./scripts/archive-and-upload.sh archive

# Xcode Organizerを開いてアップロード
open build/Shigodeki.xcarchive
```

### 3.2 Xcode Organizerから手動アップロード

1. Xcode → Window → Organizer
2. Shigodekiアーカイブを選択
3. 「Distribute App」をクリック
4. 「App Store Connect」→「Upload」を選択
5. オプションを確認して「Upload」

### 3.3 アップロード後の確認

1. App Store Connect → TestFlight → ビルド
2. 処理完了まで待機（通常10-30分）
3. ステータスが「準備完了」になることを確認

---

## 4. ビルドの配信

### 4.1 内部テスターへの配信

1. TestFlight → 内部テスト → グループを選択
2. 「ビルド」セクションで配信するビルドを選択
3. テスターに自動で通知が送信される

### 4.2 外部テスターへの配信

**初回ビルドの場合**:
1. TestFlight → 外部テスト → グループを選択
2. ビルドを追加
3. 「審査のために送信」をクリック
4. Apple審査を待つ（24-48時間）
5. 承認後、自動で配信開始

**2回目以降のビルド**:
- 同じコンプライアンス設定であれば自動承認
- ビルドを追加するだけで配信開始

---

## 5. バージョン管理

### 5.1 ビルド番号の更新

TestFlightでは同じバージョンでも異なるビルド番号が必要です。

Xcodeで更新:
1. プロジェクト設定 → General → Identity
2. Version: マーケティングバージョン（例: 1.6）
3. Build: ビルド番号をインクリメント（例: 3）

または`agvtool`を使用:
```bash
cd iOS
# ビルド番号をインクリメント
agvtool next-version -all

# 特定の番号に設定
agvtool new-version -all 10
```

### 5.2 バージョニング規則

| 種類 | 例 | 用途 |
|------|-----|------|
| Major | 2.0 | 大規模変更・破壊的変更 |
| Minor | 1.7 | 新機能追加 |
| Patch | 1.6.1 | バグ修正 |
| Build | (1) | 同バージョン内の連番 |

---

## 6. コンプライアンス情報

### 6.1 輸出コンプライアンス

初回アップロード時に質問されます:

Q: アプリは暗号化を使用していますか？
A: **はい**（Firebase/HTTPSを使用）

Q: 暗号化は標準的な暗号化アルゴリズムのみですか？
A: **はい**（TLS/SSL、Firebase標準）

Q: 暗号化の免除に該当しますか？
A: **はい**（Note 4の免除規定に該当）

### 6.2 プライバシー情報

App Store Connectの「App のプライバシー」セクションで以下を設定:

**収集するデータ**:
| データタイプ | 用途 | ユーザーにリンク |
|-------------|------|----------------|
| メールアドレス | アカウント認証 | はい |
| ユーザー ID | アカウント識別 | はい |
| 写真 | タスク添付 | はい |
| 使用状況データ | 分析 | いいえ |

---

## 7. トラブルシューティング

### アップロードエラー

**「Invalid Binary」エラー**:
- Bundle IDがApp Store Connectの設定と一致しているか確認
- プロビジョニングプロファイルが有効か確認

**「Missing Compliance」エラー**:
- 輸出コンプライアンス情報を設定
- Info.plistに `ITSAppUsesNonExemptEncryption = NO` を追加（該当する場合）

### ビルド処理が進まない

- 30分以上「処理中」の場合、新しいビルドを再アップロード
- App Store Connectの「アクティビティ」タブでエラーを確認

### テスターに通知が届かない

- テスターのメールアドレスを確認
- TestFlightアプリがインストールされているか確認
- 迷惑メールフォルダを確認

---

## 8. チェックリスト

### アップロード前
- [ ] バージョン番号を更新
- [ ] ビルド番号をインクリメント
- [ ] Release構成でビルド
- [ ] 基本機能の動作確認

### アップロード後
- [ ] App Store Connectでビルド処理完了を確認
- [ ] コンプライアンス情報を設定
- [ ] テストグループにビルドを追加
- [ ] テスターへの配信を確認

### 外部テスト公開前
- [ ] プライバシーポリシーURLを設定
- [ ] ベータ版の説明を記入
- [ ] フィードバックメールを設定
- [ ] 審査提出

---

## 参考リンク

- [App Store Connect ヘルプ](https://developer.apple.com/help/app-store-connect/)
- [TestFlight ドキュメント](https://developer.apple.com/testflight/)
- [App Store Review ガイドライン](https://developer.apple.com/app-store/review/guidelines/)

---

**作成日**: 2026-01-25
**対象バージョン**: 1.6 (Build 2)
