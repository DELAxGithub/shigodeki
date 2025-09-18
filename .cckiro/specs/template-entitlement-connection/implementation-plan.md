# Implementation Plan: Template Monetization Entitlement Connection

## Steps
1. **Protocol Refinement**
   - Update `TemplateEntitlementResolving` to include `isUnlocked(templateID:)`.
   - Adjust stub resolver (default implementation) to satisfy new protocol requirements.

2. **Live Resolver Implementation**
   - Add `EntitlementResolverLive` under `Services/Purchases/` that holds a reference to `EntitlementStore`.
   - Implement logic: return `true` when `entitlements.isPro` or when template ID appears in `ownedTemplates`.

3. **Catalog Wiring**
   - Extend `TemplateMonetizationCatalog` to store the resolver and expose `setResolver(_:)` (rename existing `configure` if needed).
   - Update `hasEntitlement(for:)` / `isPaid` consumers to use `resolver.isUnlocked(templateID:)`.

4. **View Injection**
   - Add resolver parameters with default stub to `TemplateLibraryView` and `TemplatePreviewView`; propagate to internal helpers if necessary.
   - Ensure `TemplateLibraryView` passes resolver to `TemplateCard`/child views where lock state is computed.

5. **Environment Hook-Up**
   - Declare `@EnvironmentObject var entitlementStore: EntitlementStore?` in `TemplatePreviewView` (and any other view needing live updates).
   - On appear / on change of `entitlements`, refresh computed lock state (e.g., recompute `isTemplateLocked`).

6. **Flag-Based Resolver Selection**
   - At view creation sites (likely in calling screens), supply `EntitlementResolverLive` when `FeatureFlags.purchasesEnabled` is `true` and `EntitlementStore` is available; otherwise rely on default stub.

7. **Verification**
   - Build the project for iOS simulator to ensure changes compile.
   - Manual reasoning: verify pro entitlement unlocks all templates; owned set unlocks specific ones; when flags off, behavior unchanged.

## Notes
- Keep new files under ~200 LOC; avoid UI churn.
- No networking or StoreKit operations introduced here.
- Ensure resolver lookups remain O(1) by using sets.

	•	TemplateMonetizationCatalog.setResolver(_:) は 弱参照 or 非保持でもOK（グローバル保持が嫌なら、各View引数優先）。ただ、実装簡便さを優先するなら静的保持で可。
	•	@EnvironmentObject var entitlementStore: EntitlementStore? は Optional で安全化し、無い場合は StubResolver を使用。
	•	onReceive(entitlementStore.$entitlements) でロック状態を recompute。UI側のステートはderivedに留め、二重保持を避けると安全。
