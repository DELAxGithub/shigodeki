# Requirements: Template Monetization Entitlement Connection

## Context
- Prior slice introduced UI badging/teasers for paid templates using a stubbed entitlement resolver.
- This slice wires the UI to the real `EntitlementStore` so unlock states reflect live StoreKit entitlements without overhauling the UI.

## Functional Requirements
1. **Live Resolver**
   - Provide a `TemplateEntitlementResolving` implementation backed by `EntitlementStore` (`EntitlementResolverLive`).
   - Unlock logic: `entitlements.isPro == true` unlocks all templates; otherwise `entitlements.ownedTemplates.contains(templateID)` controls individual access.
2. **Resolver Injection**
   - Allow UI surfaces (`TemplateLibraryView`, `TemplatePreviewView`, and helpers they invoke) to accept a resolver dependency.
   - Default remains the existing stub resolver; pass the live resolver only when monetization flags warrant (e.g., `purchasesEnabled == true`).
3. **Entitlement Updates**
   - Preview views observe `EntitlementStore` updates (via `@EnvironmentObject` or similar) and recompute lock state on change to keep UI in sync.

## Non-Functional Requirements
1. Maintain current behavior when all monetization flags are `false` (no badge/lock UI, no resolver work).
2. Avoid crashes if `EntitlementStore` isn’t present (fall back to stub resolver).
3. No new StoreKit calls in this slice; rely solely on the store’s published state.
4. Preserve performance—resolver lookups should be lightweight and cache-friendly.

## Acceptance Criteria
- Build passes on iOS 15+.
- Flags all `false`: UI matches current behavior.
- With `templateIAPEnabled == true` and `purchasesEnabled == true`:
  - `entitlements.isPro == true` unlocks all templates (no badges/teasers).
  - Owned templates listed in `entitlements.ownedTemplates` unlock individually; others remain locked.
- No crashes when entitlements are unavailable or when flags are `false`.
明確化（最小）
	•	Resolver契約：TemplateEntitlementResolving { func isUnlocked(templateID: TemplateID) -> Bool }。Live実装は EntitlementStore.entitlements を読むだけ（O(1)）。
	•	注入の既定値：resolver: TemplateEntitlementResolving = StubResolver() を各Viewの引数デフォルトに設定。purchasesEnabled==true のときだけ Live を渡す。
	•	環境依存の安全化：@EnvironmentObject var entitlementStore: EntitlementStore? のように任意扱いにして、無い場合は Stubで代替。
	•	再計算トリガ：onReceive(entitlementStore.$entitlements) か onChange でロック状態を再評価（再描画）。
	•	Flag優先順位：templateIAPEnabled == false のときはロックUI自体を出さない（resolverは呼ばれてもOKだが結果は使わない）。

受け入れ基準（そのまま）
	•	iOS 15+ ビルド緑。
	•	旗全OFF：現状表示と完全一致。
	•	templateIAPEnabled && purchasesEnabled：
	•	isPro==true → 全テンプレ解放（バッジ/ティーザー消滅）。
	•	ownedTemplates に含まれるIDのみ個別解放、他はロック維持。
	•	EntitlementStore 不在でもクラッシュ無し（Stubにフォールバック）。