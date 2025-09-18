# Requirements: Purchase Flow Core

## Scope
- Deliver StoreKit-driven purchase orchestration for template IAP and PRO subscription without introducing UI yet.
- Build abstractions that future UI triggers can call to initiate purchases, handle results, and refresh entitlements.
- Ensure coordination works for both single template products and subscription products per the monetization plan.

## Functional Requirements
1. **Purchase Coordinators**
   - `TemplatePurchaseCoordinator` to perform single-template purchases.
   - `ProSubscriptionCoordinator` to perform subscription purchases (monthly/yearly).
   - Each coordinator should:
     - Accept a product identifier (and template ID for template purchases).
     - Call `PurchaseServicing.purchase(productID:)`.
     - Interpret `PurchaseResult` and map to high-level outcomes (`success`, `cancelled`, `pending`, `failed`).
     - On success with `verified == true`, trigger `EntitlementStore.refresh()` and return success.
2. **Product Lookup Support**
   - Provide helper(s) to fetch `Product` metadata for given IDs via `PurchaseServicing.products(for:)` to be reused by paywall UI later.
   - Cache product results in-memory to avoid repeated StoreKit calls within a session.
3. **Flag Awareness**
   - Coordinators should no-op (return guarded failure) when `FeatureFlags.purchasesEnabled` is `false` to prevent accidental StoreKit calls.
4. **Error Handling**
   - All StoreKit failures should surface as descriptive errors without crashing.
   - Pending/unverified transactions should not unlock entitlements but still notify callers.

## Non-Functional Requirements
1. API must be testable; expose protocols or init parameters for dependency injection (e.g., mock `PurchaseServicing`, `EntitlementStore`).
2. Avoid UI dependencies; coordinators should be pure services callable from future views.
3. Keep concurrency on the main actor where `EntitlementStore` is touched; background work can use async functions elsewhere.
4. Maintain existing behavior when not invoked—no automatic purchases or product loads at startup.

## Acceptance Criteria
- Build succeeds on iOS 15+ after integrating the new coordinators.
- Calling template purchase with flags off returns a guarded failure without StoreKit access.
- With flags on and a mocked verified result, entitlements refresh is invoked and coordinator reports success.
- Subscription coordinator mirrors the same behavior for monthly/yearly IDs.
- Product fetch helper returns cached product info on subsequent calls within the same session.
	•	高レベル結果の定義：success / cancelled / pending / failed(Error) の4種で統一し、successは検証済みのみに限定（verified == true）。未検証は pending 扱い。
	•	旗OFF時のガード失敗：戻り値のエラーは 明示的な識別子（例：PurchasesDisabledError）にして、呼び出し側が分岐しやすいように。
	•	キャッシュ粒度：ProductキャッシュはproductIDキーのメモリキャッシュで十分（セッション内のみ）。
	•	スレッド境界：EntitlementStore.refresh() 呼び出しは MainActor で行う前提にしておく（競合を避ける）。
	•	テスト容易性：PurchaseServicing と EntitlementsRefreshing（refresh() を持つ最小契約）をDI可能にしておけば、モックで受け入れ条件を検証可能。