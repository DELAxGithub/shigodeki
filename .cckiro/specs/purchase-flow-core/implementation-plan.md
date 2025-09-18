# Implementation Plan: Purchase Flow Core

## Steps
1. **Type Definitions**
   - Add `PurchaseOutcome` enum and `PurchaseFlowError` to represent coordinator results.
   - Introduce `EntitlementRefreshing` protocol adopted by `EntitlementStore`.

2. **Product Catalog Service**
   - Implement `PurchaseProductCatalog` with in-memory cache.
   - Provide async `products(for:)` API and optional `product(for:)` convenience.

3. **Coordinator Base Logic**
   - Create shared helper for mapping `PurchaseResult` to `PurchaseOutcome`.
   - Ensure purchases are guarded by `FeatureFlags.purchasesEnabled`.

4. **TemplatePurchaseCoordinator**
   - Implement `buyTemplate(templateID:productID:)` per design, including entitlement refresh on verified success.

5. **ProSubscriptionCoordinator**
   - Implement `buyPro(productID:)` mirroring template coordinator logic.

6. **Adopt EntitlementRefreshing**
   - Conform `EntitlementStore` to `EntitlementRefreshing` with `refresh()`.

7. **Build Validation**
   - Run simulator build to confirm compilation.

## Notes
- Coordinators should be lightweight structs or final classes; pick whichever simplifies dependency injection.
- Keep StoreKit imports behind availability checks where necessary.
- No UI wiring in this slice.

