# Requirements: Purchase Service & Entitlement Store

## Context
- Introduce StoreKit 2 purchase foundation and in-memory entitlement cache to support upcoming monetization flows (template IAP + PRO subscription).
- Must respect existing feature flag defaults (`false`) so current behavior remains unchanged when flags are off.

## Functional Requirements
1. Provide a `PurchaseService` abstraction that can:
   - Fetch products for given identifiers asynchronously.
   - Initiate purchases by product identifier and surface success/failure information without crashing on errors.
   - Surface transaction listener registration that is intended to run at app start to watch for updates.
2. Provide an `EntitlementStore` responsible for:
   - Aggregating transaction information into an `Entitlements` value (`isPro`, `ownedTemplates`, `updatedAt`).
   - Exposing the current entitlements via `@Published` for SwiftUI subscribers.
   - Refreshing entitlement state on-demand (e.g., after purchase or on launch) by consulting StoreKit transactions.
3. Interactions between `PurchaseService` and `EntitlementStore` should allow:
   - Listening for transaction updates to trigger entitlement refreshes.
   - Manual refresh calls without requiring UI knowledge of StoreKit internals.

## Non-Functional Requirements
1. Implementation must use StoreKit 2 APIs and compile under the current deployment target (assume iOS 15+; guard availability if necessary).
2. Failures from StoreKit should be handled gracefully (log, propagate result) without crashing.
3. No network or purchase UI is triggered when monetization flags (`purchasesEnabled`, `templateIAPEnabled`, `proSubscriptionEnabled`, `paywallEnabled`) are `false`; services may exist but should be inert unless invoked.
4. Ensure compatibility with existing `DIContainer` for future registration but do not alter global behavior yet (no registration wiring in this slice unless required for compilation/testing).
5. Introduce unit-testability considerations (protocols or abstractions) without adding actual tests in this slice.

## Out of Scope
- UI changes, paywall presentation, or wiring to template/AI flows.
- Telemetry emission.
- Server receipt validation or backend sync.

念のため、実装時にブレやすい“最低限の明確化”だけ添えます。

最小補足（ブレ防止）
	•	結果型の扱い：PurchaseResult は success / userCancelled / pending / failed(Error) 程度でOK。success(.verified) と success(.unverified) の区別は将来のレシート検証で使えるよう、内部ログだけ残せば十分（クラッシュ禁止）。
	•	リスナー契約：listenTransactions() は StoreKit2 の Transaction.updates を消費し finish() まで行う関数として公開。呼び出し側は起動時に Task { await listenTransactions() }、更新が来たら EntitlementStore.refresh() を呼べるように。
	•	Entitlement の算出元：refresh() は Transaction.currentEntitlements を走査して
	•	PRO: 指定の productID 群にヒットしたら isPro = true
	•	単品: productID→TemplateID マップで ownedTemplates を構築
（マップはこのスライスでは stub 可）
	•	スレッド境界：EntitlementStore は @MainActor、@Published entitlements を更新するのはメインで。StoreKit呼び出しは async でOK。
	•	可用性：iOS 15+ を @available(iOS 15.0, *) でガード（下位は未対応でOK）。
	•	フラグとの関係：本スライスでは サービスは“存在するだけ”。フラグOFFでも起動・リフレッシュはしてよいが、UIは何も出さない／購入は呼ばれない前提でOK。
	•	テスト容易性：PurchaseServicing プロトコル＋EntitlementStore の init でDI可能に（モック差し替え用）。テスト実装はスコープ外でOK。

受け入れ基準（このスライス）
	•	ビルド緑（iOS 15+ シミュレータ）。
	•	フラグ全OFFでUI・挙動変化なし。
	•	PurchaseService.products() / .purchase() / .listenTransactions() が呼べ、例外は握りつぶさずfailed(Error)で返る。
	•	EntitlementStore.start() → listenTransactions＆refresh が動いてもUI影響なし、entitlements が .empty から更新可能。