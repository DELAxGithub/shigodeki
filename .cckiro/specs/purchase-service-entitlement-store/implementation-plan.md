# Implementation Plan: Purchase Service & Entitlement Store

## Overview
Implement StoreKit 2–based purchasing infrastructure per the approved design. Deliverables include the service protocol, concrete StoreKit service, entitlement store, product ID catalog, and supporting models.

## Steps
1. **Define Supporting Models & Protocols**
   - Create `PurchaseResult` enum and `PurchaseServicing` protocol with `products`, `purchase`, `listenForTransactions`, and `currentEntitlements` signatures.
   - Ensure protocol availability guards for iOS 15+.

2. **Introduce TemplatePriceCatalog Helper**
   - Add static constants for pro subscription IDs and template product IDs (stub values from requirements).
   - Provide mapping helpers to translate StoreKit product IDs into entitlement outcomes.

3. **Implement StoreKitPurchaseService**
   - Provide `@available(iOS 15.0, *)` concrete type conforming to `PurchaseServicing`.
   - Implement product fetch, purchase flow (mapping StoreKit errors to `PurchaseResult` cases), transaction listener with finish() calls, and `currentEntitlements` aggregation.
   - For pre-iOS15 builds, add a fallback no-op implementation returning empty results.

4. **Build EntitlementStore**
   - `@MainActor` class with `@Published var entitlements: Entitlements = .empty`.
   - Inject `PurchaseServicing` and maintain a listener `Task`.
   - Implement `start()`, `stop()`, and `refresh()`; ensure `refresh()` calls service’s `currentEntitlements()` and updates state using `TemplatePriceCatalog` mappings.

5. **Wire Up Common Result Handling & Logging**
   - Add minimal logging (print or os_log) for failure paths.
   - Ensure `PurchaseResult.success(verified: Bool)` is interpreted correctly (unverified treated as non-granting).

6. **Integration Touchpoints**
   - Leave TODO/placeholder for DIContainer wiring but do not register yet.
   - Provide stubbed usage comment or sample call site (Doc comment) for future integration.

7. **Validate Build**
   - Run `swift build` or relevant Xcode build to ensure compilation with new files.

## Notes
- Keep files under 300 lines; split types if needed.
- Maintain flag defaults (no UI impact yet).
- No unit tests in this slice, but structure should be testable.

念のための最小メモだけ：
	•	currentEntitlements() の返り値は 検証結果ごとに返す（[VerificationResult<Transaction>]）。EntitlementStore 側で pro/template を集計。
	•	listenForTransactions は Task<Void, Never> を返すので EntitlementStore が stop() で cancel() できる。
	•	PurchaseResult.success(verified:) は verified == false を 成功UIにしない／権利付与もしない（ログのみ）。