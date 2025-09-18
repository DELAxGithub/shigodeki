# Requirements: Template Paywall Trigger (Step 4)

## Goal
Expose purchase entry points for paid templates in the library/preview flows using the existing coordinators, while keeping the UI minimal. No actual paywall design yet—just trigger points and placeholder UI to signal purchase vs. use.

## Functional Requirements
1. **Template Library List**
   - For paid templates (per `TemplateMonetizationCatalog`), show a “Unlock” CTA when user selects preview/draft actions and lacks entitlement.
   - CTA should open a simple modal (temporary paywall stub) explaining the need to purchase, with a button to start purchase via template coordinator.
2. **Template Preview Menu**
   - Replace the current direct “このテンプレートを使用” / “カスタマイズして使用” when locked with a path that routes through the paywall stub.
   - If the template is already unlocked (owned or PRO), keep existing behavior.
3. **Unlock Flow**
   - Paywall stub calls `TemplatePurchaseCoordinator.buyTemplate`; on success, dismiss modal and proceed with selection.
   - On failure/pending/cancel, remain in modal and show a user-friendly status message.
4. **Flag Handling**
   - Entire paywall trigger only appears when `templateIAPEnabled == true`. Otherwise, keep prior direct flow.
   - Respect `purchasesEnabled`; when false, show a disabled state with message (e.g., “Purchases unavailable”).

## Non-Functional Requirements
1. UI can be basic SwiftUI modal/sheet; no polished design needed.
2. Strings should be prepared for localization but can remain inline for now (Japanese text as current style).
3. Logging via `print` is acceptable but must avoid PII (only template IDs/status).
4. Purchase buttons should show progress state to avoid duplicate taps.

## Acceptance Criteria
- Build succeeds on iOS 15+ after changes.
- Flag-off paths behave as before (no paywall modal, direct template use).
- With flags on and entitlement missing, selecting a paid template shows the stub modal; successful purchase unlocks and proceeds automatically.
- Coordinator errors/pending map to visible messages without dismissing the modal.
- No StoreKit calls occur when `purchasesEnabled` is false (guard remains in coordinator).
