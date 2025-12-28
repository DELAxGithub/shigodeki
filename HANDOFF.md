# 引き継ぎ書 (Codex)

## 目的
PoC v0.1 完成に向けて、作業の現状・差分・次の打ち手を共有する。

## 直近の作業内容（2025-12-28 更新）

### ✅ 完了
- Firestore ルールを厳格化し、家族データの境界を強化
- `familyIds` 更新を explicit array 更新に統一（transaction + 既存チェック）
- **Firestore ルールテスト実行完了** - 主要テスト（family-access.test.js）全4件 PASS
- **接続テストを認証後に移動** - `/test/connection` の認証必須化に対応

### 変更ファイル
- `iOS/firestore.rules`
  - `/invitations` レガシー許可を削除
  - `families/{id}` 配下の read/write をメンバー限定に変更
  - `/test/connection` を `authed()` のみに変更
  - `users/{uid}` 更新ルールで `familyIds` の +1 追加を厳密化（初回1件追加も許可）
- `iOS/shigodeki/Managers/FamilyCreationService.swift`
  - `familyIds` 追加を transaction で explicit array 更新に変更
- `iOS/shigodeki/Managers/FamilyMembershipService.swift`
  - `familyIds` 追加を transaction で explicit array 更新に変更
- `iOS/shigodeki/Repository/FirestoreFamilyRepository.swift`
  - `familyIds` 追加を transaction で explicit array 更新に変更
- `iOS/shigodeki/shigodekiApp.swift`
  - 起動時の接続テストを削除（認証前に実行されるため）
- `iOS/shigodeki/Managers/AuthenticationManager.swift`
  - 認証成功後に接続テストを実行（DEBUG のみ）
- `iOS/test/family-access.test.js`
  - Firestore 初期化エラーを修正

## 現状の注意点
- `familyIds` の削除は `arrayRemove` のままで、今のルールでは **削除が拒否される**
  - **決定**: PoC では「家族退出」は P2 へ先送り。現状維持で OK

## テスト結果（2025-12-28）
| テストファイル | 結果 | 備考 |
|--------------|------|------|
| `family-access.test.js` | ✅ 4/4 PASS | 主要テスト全て成功 |
| `security.test.js` | ✅ 6/6 PASS | ボーダー防御テスト成功 |
| `realistic-security.test.js` | ⚠️ 4/6 PASS | 2件は初期化エラー（P1） |
| `invite-security.test.js` | ⚠️ 3/5 PASS | テストコード要修正（P1） |

## 次にやると良いこと（推奨順）
1. 招待の manual validation を完了し、`docs/validation-test.md` を更新
2. 残りのテストファイルの初期化エラーを修正（P1）
3. TaskAddModal/Preview/Undo/Sync の P0 チケットに着手

## コミット案
```
chore: tighten firestore rules and move connection test after auth

- Enforce explicit familyIds array updates with +1 rule
- Move Firestore connection test to post-authentication (DEBUG only)
- Fix family-access.test.js initialization errors
- All 4 family-access tests passing
```
