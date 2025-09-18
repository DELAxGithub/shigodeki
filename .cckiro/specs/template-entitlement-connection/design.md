# Design: Template Monetization Entitlement Connection

## Overview
Leverage the existing `TemplateMonetizationCatalog` and UI hooks by providing a live entitlement resolver that reflects `EntitlementStore` state, while keeping the default stub behavior intact when monetization flags are off or the store is unavailable.

## Key Elements
1. **Resolver Protocol Update**
   - Extend `TemplateEntitlementResolving` with a clear `func isUnlocked(templateID: TemplateID) -> Bool` API (existing `hasEntitlement` helper can delegate to it).
   - Maintain the stub resolver for default use.

2. **Live Resolver Implementation**
   - `EntitlementResolverLive` stores a weak reference or closure to access `EntitlementStore` and consults its `entitlements` property.
   - Unlock logic:
     - If `entitlements.isPro` is `true`, return `true` for any template.
     - Else check `ownedTemplates` set membership.
   - Provide a convenience init that accepts `EntitlementStore` and reads its published value.

3. **Catalog Integration**
   - `TemplateMonetizationCatalog` exposes `setResolver(_:)` (or repurpose existing `configure`) allowing the live resolver to be injected at app runtime.
   - `hasEntitlement(for:)` and any other helper delegate to the resolver’s `isUnlocked` method.

4. **UI Injection Strategy**
   - `TemplateLibraryView` and `TemplatePreviewView` gain optional resolver parameters (defaulting to stub) so preview/testing code remains unchanged.
   - App entry point (or DI wiring) checks `FeatureFlags.purchasesEnabled` and, if true and an `EntitlementStore` is available, supplies the live resolver.

5. **Entitlement Observation**
   - `TemplatePreviewView` adds `@EnvironmentObject var entitlementStore: EntitlementStore?`.
   - On `onReceive`/`onChange` of `entitlementStore?.$entitlements`, recompute local lock state (`isTemplateLocked`).
   - Fail-safe: if the environment object is missing, continue using stub resolver behavior.

## Data Flow
1. App config injects resolver into catalog when purchases are enabled.
2. Template list & preview ask catalog `hasEntitlement` (or `isUnlocked`) when deciding badge/teaser state.
3. Updates to `entitlements` publish via environment object, causing previews to refresh lock indicators.

## Safety Considerations
- Guard all resolver lookups behind feature flag checks to avoid unnecessary work when monetization visuals are hidden.
- Resolver must handle being accessed off-main thread safely (the data read is value-typed `Entitlements`).
- Provide fallback to stub logic if store is nil or entitlements are in initial `.empty` state.

## Future Hooks
- When DI container is ready, move resolver/configuration wiring into `DIContainer.setupDependencies()`.
- Extend resolver to include price or period metadata if needed for analytics.

