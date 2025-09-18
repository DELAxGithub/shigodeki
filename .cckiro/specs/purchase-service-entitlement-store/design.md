# Design: Purchase Service & Entitlement Store

## High-Level Architecture
- Introduce a StoreKit 2–backed `PurchaseService` concrete class (`StoreKitPurchaseService`) implementing a `PurchaseServicing` protocol.
- Introduce an `EntitlementStore` class seeded with a `PurchaseServicing` dependency to access StoreKit transactions/products indirectly.
- `EntitlementStore` runs on the main actor; its public API provides `@Published var entitlements` and `func refresh()`.
- A lightweight `TemplatePriceCatalog` helper owns the map between StoreKit product IDs and logical template IDs/pro subscription identifiers.

## Key Types
1. `PurchaseServicing` protocol
   - `func products(for ids: [String]) async throws -> [Product]`
   - `func purchase(productID: String) async -> PurchaseResult`
   - `func listenForTransactions(handler: @escaping (VerificationResult<Transaction>) async -> Void) -> Task<Void, Never>`
2. `PurchaseResult` enum encapsulating `success`, `userCancelled`, `pending`, and `failed(Error)`; `success` carries whether the transaction was verified.
3. `StoreKitPurchaseService`
   - Uses StoreKit 2 APIs (`Product.products`, `Transaction.updates`, `Transaction.currentEntitlements`).
   - Handles verification via `Transaction.latest(for:)` helpers; verification failures map to `.failed` or `.pending` depending on state.
4. `TemplatePriceCatalog`
   - Struct housing static product ID constants (temporary stub values from requirements).
   - Exposes helper methods to map product IDs → entitlement type (`pro` vs. template ID) to keep logic centralized.
5. `EntitlementStore`
   - `@MainActor` class with `@Published var entitlements: Entitlements = .empty`.
   - Keeps a reference to `PurchaseServicing` and a transaction listener task (for lifecycle management).
   - `func start()` sets up the background listener and triggers `refresh()`.
   - `func stop()` cancels listener (for tests or teardown).
   - `refresh()` gathers `Transaction.currentEntitlements` via the service, aggregates results, and updates `entitlements`.

## Data Flow
1. App (future caller) instantiates `EntitlementStore` with a `PurchaseServicing` implementation.
2. Call `start()` on app launch when purchases are enabled; this triggers:
   - `listenForTransactions` → on each transaction update, call `refresh()` asynchronously.
   - Initial `refresh()` to populate entitlements from `currentEntitlements`.
3. UI can observe `entitlements` via SwiftUI.

## Concurrency & Error Handling
- `StoreKitPurchaseService` operations run on background actors but return results to the caller; errors are surfaced via `PurchaseResult.failed` or thrown from `products`.
- `EntitlementStore.refresh()` runs async, awaiting service calls; it catches errors and logs them without failing the main task.
- Ensure `@MainActor` is applied to `EntitlementStore` so state updates remain safe.

## Availability & Guards
- Wrap StoreKit 2 usage with `@available(iOS 15.0, *)`. For unsupported OS versions, provide fallback implementations which return empty products and `.failed` results (or skip listener) to satisfy compiler checks.

## Future Extension Points
- Telemetry hooks within purchase results.
- Remote receipt validation or server sync post-refresh.
- DI container wiring once flows require runtime access.

クリティカルな明確化（5点だけ）
	1.	トランザクションの finish
listenForTransactions のハンドラ内で Transaction を検証→必要なら finish() まで責務を明確化（ダブル課金や再発行のループ防止）。
	2.	currentEntitlements の取得経路
EntitlementStore.refresh() は サービス経由で currentEntitlements を読みに行く（StoreKit直叩き禁止）。
→ PurchaseServicing に func currentEntitlements() async -> [VerificationResult<Transaction>] を追加するとテスト容易。
	3.	プロダクトID→権利のマップ
TemplatePriceCatalog は 一元マップを持つ：

	•	proProductIDs: Set<String>
	•	templateProductToID: [String: TemplateID]
復元や領収再送にも使うので、ここが唯一の真理。

	4.	結果型の扱い
PurchaseResult.success(verified: Bool) の verified=false は 購入扱いにしない（Entitlementは付与しない）。ログは残すがUIは成功表示しない。
	5.	旗との関係
旗OFFでも EntitlementStore.start() は動いてOK（UIを出さない限り無害）。
ただし 購入API（purchase(productID:)）の呼び出しはUI側で旗を見て抑止。

受け入れ基準（この設計スライス）
	•	iOS 15+ でビルド緑、旗OFFでUI・挙動不変。
	•	PurchaseService：products/purchase/listenForTransactions が利用可能、例外は .failed(Error) で返る。
	•	EntitlementStore.start() → リスナー起動＋refresh() が走り、entitlements が .empty から更新可能（プロダクトIDマップはスタブでOK）。
	•	listenForTransactions 経由で更新が来たら refresh() が一度だけ走る（重複発火しない）。
