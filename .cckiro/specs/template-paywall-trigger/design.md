# Design: Template Paywall Trigger

## Overview
- Introduce a lightweight `TemplatePaywallView` presented modally when a locked template is chosen.
- Integrate paywall presentation into both the library list and preview flow, using existing environment dependencies (`TemplatePurchaseCoordinator`, `PurchaseProductCatalog`).
- Manage state via a `TemplatePaywallViewModel` (optional) or local state to track price info, loading status, and purchase outcome.

## Components
1. **TemplatePaywallView**
   - Inputs: template (`ProjectTemplate`), `PurchaseProductCatalog`, `TemplatePurchaseCoordinator`, completion callbacks.
   - Displays template name, short benefit list, price fetched from catalog, and buttons (`解錠する`, `キャンセル`).
   - Handles purchase progress (spinner/disabled button) and outcome messages.

2. **TemplatePaywallPresenter**
   - Convenience helper (struct or extension) to determine when to show paywall vs. direct flow.
   - Exposes methods for library/preview views to call.

3. **State Management**
   - `@State` for modal visibility plus simple status enum (`idle`, `purchasing`, `success`, `failed(message)`).
   - On success, dismiss paywall and call completion (which triggers existing selection logic).

## Flow Integration
1. **TemplateLibraryView**
   - When user taps a paid template (`TemplateCard` or preview action), check entitlement; if locked and flags on, set `selectedTemplate` and present paywall sheet.

2. **TemplatePreviewView**
   - Current logic already checks lock; update to present `TemplatePaywallView` instead of direct purchase call. The paywall view will own the purchase call.

3. **Price Fetch**
   - On paywall appear, fetch product info via catalog; cache ensures subsequent opens reuse data.

4. **Status Messages**
   - Map purchase outcome to simple texts (`成功`, `保留`, `キャンセル`, `失敗`).

## Flag Guard
- Paywall presenter should only activate when `templateIAPEnabled == true` and `purchasesEnabled == true`; otherwise fall back to direct selection with short notice message.

