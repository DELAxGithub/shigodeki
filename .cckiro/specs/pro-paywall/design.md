# Design: PRO Subscription Paywall

## Overview
- Add a dedicated `ProPaywallView` that surfaces PRO benefits, monthly/yearly pricing, and purchase CTA using `ProSubscriptionCoordinator`.
- Update existing template paywall to include a PRO upsell entry point when appropriate.
- Integrate paywall into AI surfaces (initially `TaskAIAssistantView`) when the user lacks PRO access.

## Key Components
1. **ProPaywallView**
   - Inputs: `ProSubscriptionCoordinator`, `PurchaseProductCatalog`, callbacks for success/cancel.
   - State: selected plan (`monthly`, `yearly`), price strings, purchase state (idle/loading/pending/success/failure).
   - UI: benefits list, toggles for plan selection, price/CTA, cancel button.
2. **ProPaywallPresenter**
   - Helper to abstract flag checks and environment lookups (coordinator/catalog).
   - Exposed as view extension methods to present the paywall modally.
3. **Template Paywall Integration**
   - Add a PRO upsell button inside `TemplatePaywallView` when PRO flags enabled.
   - On tap, present `ProPaywallView`; successful purchase dismisses both paywalls and proceeds with unlock.
4. **AI Surface Integration**
   - In `TaskAIAssistantView`, when `isPro` is false and the user taps AI actions, present the PRO paywall instead of the current block message.
5. **State Handling**
   - Propagate entitlement updates via existing store; paywall success triggers dismissal and allows the original action to continue.

## Flag Logic
- `FeatureFlags.proSubscriptionEnabled` and `FeatureFlags.purchasesEnabled` must be true to show CTS or allow purchase.
- When flags off, retain existing block messages (AI), and template paywall hides PRO upsell.

## Error Handling
- Map `PurchaseOutcome` to user-visible messages similar to template paywall.
- Log outcomes with template/plan identifiers only; no user info.

