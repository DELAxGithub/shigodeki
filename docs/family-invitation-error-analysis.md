# 家族招待エラー解析レポート

## 🚨 問題の概要

家族招待機能において、招待コード `71Z0DH` (表示: `INV-71Z0DH`) が正常に生成されているにも関わらず、参加側で「Code not found」エラーが発生している。

## 📊 エラーの詳細分析

### 招待側の動作（正常）
```
✅ Family created successfully with ID: EoVBK7LoPvtBMX5Dw0yy
📝 [FamilyCreationService] InviteIssue normalized=71ZODH shown=INV-71ZODH familyId=EoVBK7LoPvtBMX5Dw0yy
✅ Invitation code generated for family: EoVBK7LoPvtBMX5Dw0yy -> INV-71ZODH
✅ Using server-generated invitation code: INV-71ZODH
✅ [FamilyProjectOperations] Loaded invite code from family scope: INV-71ZODH
```

### 参加側の動作（エラー）
```
📝 [JoinFamilyView] Join: input='71Z0DH', normalized='71Z0DH', kind=new
🔍 FamilyViewModel: Original code: '71Z0DH', normalized: '71Z0DH'
⏳ FamilyViewModel: Starting join process with normalizedCode=71Z0DH, userId=kH49JAs83MQPNRFf9WZ8Xzofboe2
InvitationService: Validating code - original: '71Z0DH', normalized: '71Z0DH'
InvitationService: Code not found: 71Z0DH
❌ FamilyViewModel: Join failed - invalidInvitationCode
```

## 🔍 根本原因の分析

### 1. コード正規化の不整合
- **招待側**: `normalized=71ZODH` (Oの後にDH)
- **参加側**: `normalized=71Z0DH` (ゼロの後にDH)

### 2. 文字認識の問題
招待コード `71Z0DH` の4文字目が以下のどちらかで混同されている：
- `O` (オー, 文字)
- `0` (ゼロ, 数字)

### 3. データベース整合性の問題
- 招待側では `71ZODH` として保存
- 参加側では `71Z0DH` として検索
- → Firestoreで完全一致しないため「Code not found」

## 🏗️ 関連ファイルの推定

### 招待コード生成・検証関連
1. **FamilyCreationService** - 招待コード生成ロジック
2. **InvitationService** - 招待コード検証・検索ロジック
3. **FamilyViewModel** - 家族参加処理
4. **JoinFamilyView** - 招待コード入力UI

### Firebase関連
5. **Firestore Security Rules** - 招待コード検索権限
6. **Family Collection Schema** - 招待コード保存形式

## 🛡️ セキュリティ上の懸念

### Firebase接続の不整合
```
🔧 Firebase: Using production backend for dev environment
🔧 Firebase Project: shigodeki-dev
```
開発環境で本番バックエンドを使用していると表示されているが、実際は `shigodeki-dev` プロジェクトに接続している。ログメッセージの不整合。

### 認証状態の問題
両端末で正常に認証されているが、異なるユーザーID：
- 招待側: `xEMEqpAKdiUPAYjXwQI9BhnziXf1`
- 参加側: `kH49JAs83MQPNRFf9WZ8Xzofboe2`

## 📋 推奨される修正アプローチ

### 1. 緊急修正（即座）
- 招待コード正規化関数の統一
- O(オー)と0(ゼロ)の一意の変換ルール確立

### 2. 根本的修正（短期）
- 混同しやすい文字の除外 (`O`, `0`, `I`, `l` など)
- 招待コード生成アルゴリズムの改善
- 大文字小文字を区別しない検索の実装

### 3. ユーザビリティ改善（中期）
- 招待コード入力時のリアルタイム検証
- より分かりやすい文字セットの使用
- エラーメッセージの改善

## 📁 関連ファイルの詳細

### 🔧 招待コード正規化・検証システム
1. **`InvitationCodeNormalizer.swift`** - 招待コードの正規化処理
2. **`InviteCodeSpec.swift`** - 招待コード仕様（6桁、英数字セット定義）
3. **`FamilyCreationService.swift`** - 招待コード生成（normalized: `71ZODH`, display: `INV-71ZODH`）
4. **`FamilyInvitationService.swift`** - 招待コード検証・参加処理
5. **`JoinFamilyView.swift`** - 招待コード入力UI
6. **`FamilyViewModel.swift`** - 家族参加の状態管理

### 🔥 Firebase Collections
- **`invitations`** - メインの招待コード保存先（displayCode）
- **`invites_by_norm`** - 正規化コードによる保存先
- **`families/{id}/invites`** - ファミリースコープの招待コード

## 🚨 根本原因の確認

### コード生成とデータベース保存の検証

**FamilyCreationService.swift:47-80**:
```swift
let normalizedCode = generateRandomCode()  // 71ZODH を生成
let displayCode = "\(InviteCodeSpec.displayPrefix)\(normalizedCode)"  // INV-71ZODH

// 3つのコレクションに保存:
// 1. invites_by_norm/{normalizedCode}  ← 71ZODH
// 2. invitations/{displayCode}         ← INV-71ZODH  
// 3. families/{id}/invites/{normalizedCode} ← 71ZODH
```

**FamilyInvitationService.swift:142**:
```swift
// 検索時は invitations コレクションから normalizedCode で検索
let codeDoc = try await db.collection("invitations").document(normalizedCode).getDocument()
```

### ❌ 判明した問題

1. **保存**: `invitations` コレクションに **`displayCode`**（`INV-71ZODH`）で保存
2. **検索**: `invitations` コレクションから **`normalizedCode`**（`71Z0DH`）で検索
3. **結果**: ドキュメントIDが一致しない → Code not found

**具体例**:
- 保存ドキュメントID: `INV-71ZODH`
- 検索ドキュメントID: `71Z0DH` (O/0混同もあり)

## 🔧 次のアクションアイテム

### 🚨 緊急修正（Critical Path）
1. **`FamilyInvitationService.swift:142`** - 検索時にdisplayCodeを使用するよう修正
2. **文字混同対策** - O(オー)/0(ゼロ)の正規化ルール統一
3. **テストケース追加** - O/0混同パターンの包括的テスト

### 🛡️ 中長期修正
4. **文字セット改善** - 混同しやすい文字の除外（O, 0, I, l など）
5. **エラーハンドリング強化** - より具体的なエラーメッセージ
6. **セキュリティルール確認** - 招待コード検索権限の検証

## 📊 パフォーマンス観察

### メモリ使用量
- 招待側: 279MB (高使用量でアグレッシブクリーンアップ実行)
- 参加側: 184MB (通常範囲)

### Firebase接続
- 両端末でFirestore接続テスト成功
- リスナー数は適切に管理されている

## 🚨 緊急度: HIGH

この問題はユーザー体験に直結する重要な機能不全であり、即座の修正が必要。