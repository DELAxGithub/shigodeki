# Design: Purchase Flow Core

## Architecture Overview
- Introduce coordinator objects that orchestrate StoreKit purchase calls and entitlement refreshes, sitting on top of `PurchaseServicing`.
- Reuse existing concurrency primitives: coordinators operate on async functions, refreshing entitlements on the main actor.
- Add a lightweight product catalog service (cache) that wraps `PurchaseServicing.products(for:)` to provide `Product` metadata downstream.

## Key Components
1. **PurchaseResultMapping**
   - Utility that converts `PurchaseResult` (StoreKit-specific) into coordinator-level `PurchaseOutcome`.
   - Ensures `success` only when `verified == true`; `unverified` becomes `pending`.

2. **EntitlementRefreshing Protocol**
   - Protocol with `@MainActor func refresh() async` adopted by `EntitlementStore`.
   - Enables mocking in tests.

3. **TemplatePurchaseCoordinator**
   - `init(purchaseService: PurchaseServicing, entitlementRefresher: EntitlementRefreshing)`
   - `func buyTemplate(templateID: TemplateID, productID: String) async -> PurchaseOutcome`
   - Guards `FeatureFlags.purchasesEnabled`; returns `.failed(.purchasesDisabled)` when false.
   - Calls purchase; maps outcome; on success triggers `await entitlementRefresher.refresh()`.

4. **ProSubscriptionCoordinator**
   - Similar structure with `func buyPro(productID: String) async -> PurchaseOutcome`.
   - Shares purchase mapping logic via shared helper.

5. **ProductCatalogService**
   - `init(purchaseService: PurchaseServicing)`.
   - `func products(for ids: [String]) async throws -> [Product]` with in-memory cache.
   - Cache keyed by product ID; invalidated only when app relaunches (in-memory).

## Data Flow
1. Caller requests product info → Catalog service returns cached/fetched `Product`.
2. Caller triggers purchase via coordinator → coordinator checks flags, calls `PurchaseServicing`, maps result, refreshes entitlements if verified.
3. Coordinator returns `PurchaseOutcome` to caller for UI handling.

## Error Handling & Types
- Define `PurchaseFlowError: Error` including cases like `.purchasesDisabled`, `.storeKitError(Error)`, `.unknown`.
- `PurchaseOutcome` enum: `.success`, `.cancelled`, `.pending`, `.failed(PurchaseFlowError)`.
- Coordinators wrap underlying errors to `PurchaseFlowError.storeKitError` with message propagation.

## Concurrency & Main Actor Rules
- `EntitlementStore.refresh()` must run on the main actor; coordinators call it with `await MainActor.run` if necessary.
- Coordinators themselves can be `struct`/`final class`; no global state beyond caches.

## Extensibility
- Future paywall UI can inject these coordinators via DI.
- Additional telemetry hooks can wrap purchase outcomes later.

