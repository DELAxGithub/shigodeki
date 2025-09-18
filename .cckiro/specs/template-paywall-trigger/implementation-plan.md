# Implementation Plan: Template Paywall Trigger

## Steps
1. **View Model / State Types**
   - Define `TemplatePaywallState` enum (idle/loading/success/failure).
   - Optional `TemplatePaywallViewModel` struct to hold template, coordinator, catalog, and purchase state.

2. **TemplatePaywallView**
   - Build SwiftUI view using the state; fetch price on appear via catalog.
   - Provide buttons for cancel and unlock; toggle disabled state while purchasing.
   - Emit completion callbacks (`onUnlock`, `onCancel`).

3. **Integration in TemplatePreviewView**
   - Replace direct coordinator call with presenting `TemplatePaywallView` when locked.
   - Pass callbacks to proceed with selection on success.

4. **Integration in TemplateLibraryView**
   - When a locked template is chosen from the list, present the same paywall view before setting `selectedTemplate`.

5. **Flag Guards**
   - Ensure presentation only occurs when `templateIAPEnabled && purchasesEnabled`.
   - Provide fallback message when paywall not available.

6. **Logging & Messaging**
   - Add `print` statements for purchase results (no PII) and update UI messages accordingly.

7. **Build Validation**
   - Run simulator build to confirm.

