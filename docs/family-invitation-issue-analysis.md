# 招待コード表示・参加問題の原因特定レポート

## 🎯 調査結果サマリー

**根本原因**: **Firebase セキュリティルール起因ではなく、クライアント実装の保存先とコード生成の問題**

### ❌ 特定された問題

1. **コード生成の文字混同**: O(オー)と0(ゼロ)が混在
   - 生成側: `71ZODH` (オー)
   - 参加側: `71Z0DH` (ゼロ) → 不一致で検索失敗

2. **保存パスとフィールド不整合**: 
   - `FamilyInvitationService.swift:142`: `invitations/{normalizedCode}` で検索
   - 実際の保存: `invitations/{displayCode}` (INV-付き)

## 📊 詳細分析結果

### 🔒 Firebase セキュリティルール監査 - ✅ 問題なし

**ルール設定状況**:
- `invites_by_norm/{code}`: create/get 許可、list 禁止
- `invitations/{code}`: create/get 許可、list 禁止  
- `families/{id}/invites/{code}`: ファミリーメンバーのみアクセス

**期待動作との一致**: すべて正しく設定済み

### 💾 保存先とフィールド整合性 - ❌ 問題あり

**FamilyCreationService.swift での保存**:
```swift
// Triple-save strategy
1. invites_by_norm/{normalizedCode}  ← "71ZODH" 
2. invitations/{displayCode}         ← "INV-71ZODH"
3. families/{id}/invites/{normalizedCode} ← "71ZODH"
```

**FamilyInvitationService.swift での検索**:
```swift
// ❌ 問題: normalizedCode で invitations コレクション検索
let codeDoc = await db.collection("invitations").document(normalizedCode).getDocument()
// "71Z0DH" で検索 → "INV-71ZODH" ドキュメント見つからず
```

### 🔍 取得方法の整合性 - ✅ 問題なし

- すべて `getDocument()` 使用（`addSnapshotListener` は未使用）
- 多段フォールバック実装済み（`FirestoreFamilyRepository.swift`）
- Permission denied エラーなし

### 📝 正規化ロジック - ❌ 文字混同問題あり

**InvitationCodeNormalizer.swift**:
```swift
// O/0 変換ルールが未実装
// trim → fullwidth→halfwidth → uppercase → INV削除
// しかし O と 0 の統一変換がない
```

**InviteCodeSpec.swift**:
```swift
// 混同文字を含む文字セット使用中
static let newCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
// O, 0, I, l など混同しやすい文字が含まれる
```

## 🚨 緊急修正すべき箇所

### 1. 検索パス修正 (Critical)
**ファイル**: `FamilyInvitationService.swift:142`
```swift
// 現在 (❌)
let codeDoc = try await db.collection("invitations").document(normalizedCode).getDocument()

// 修正案 (✅)  
let displayCode = "\(InviteCodeSpec.displayPrefix)\(normalizedCode)"
let codeDoc = try await db.collection("invitations").document(displayCode).getDocument()
```

### 2. O/0 正規化統一 (High)
**ファイル**: `InvitationCodeNormalizer.swift`
```swift
// 追加すべきロジック
result = result.replacingOccurrences(of: "O", with: "0") // O→0統一
```

### 3. 混同文字除外 (Medium)
**ファイル**: `InviteCodeSpec.swift`  
```swift
// 現在
static let newCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
// 修正案
static let newCharacters = "ABCDEFGHJKMNPQRSTUVWXYZ23456789" // O,I,L,0,1除外
```

## 🔧 暫定復旧手順

### Phase 1: 即座修正 (15分)
```bash
# 1. 検索パス修正
# FamilyInvitationService.swift:142 を displayCode 検索に変更

# 2. O/0 統一
# InvitationCodeNormalizer.normalize() に O→0 変換追加
```

### Phase 2: 検証 (10分)
```bash
# 1. 新規ファミリー作成
# 2. 招待コード表示確認
# 3. 別端末で参加テスト
# 4. O/0 混同パターンテスト
```

### Phase 3: 根本修正 (30分)
```bash
# 1. 混同文字セット除外
# 2. 既存データ移行
# 3. テストケース追加
```

## 📋 再現テスト手順

### ✅ 成功パターン
1. 新規ファミリー作成 → 招待コード `INV-ABC123` 生成
2. Firebase Console で `invitations/INV-ABC123` 存在確認
3. 参加側で `ABC123` 入力 → displayCode 検索で成功

### ❌ 失敗パターン  
1. 招待側: `71ZODH` 生成 → `invitations/INV-71ZODH` 保存
2. 参加側: `71Z0DH` 入力 → `invitations/71Z0DH` 検索 → 見つからず

## 🎯 完了条件

- [x] 根本原因特定: **クライアント実装問題（Firebase ルール問題ではない）**
- [ ] 緊急修正実装: 検索パス修正 + O/0 正規化統一  
- [ ] 動作確認: 新規作成→表示→参加の一連成功
- [ ] Permission denied / Code not found エラー解消

**推定修正時間**: 1時間（緊急修正15分 + 検証45分）