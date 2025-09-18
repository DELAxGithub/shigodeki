# Implementation Plan: Template Library Lock UI

## Overview
Implement monetization-aware UI decorations and preview teaser limits driven by a shared catalog while keeping behavior unchanged when the `templateIAPEnabled` flag is off.

## Steps
1. **Catalog & Resolver Setup**
   - Create `TemplateMonetizationCatalog` in `Services/Purchases/` alongside existing pricing helpers.
   - Define supporting types: `MonetizationBadge` enum, `TemplateTeaserConfig` struct, and `TemplateEntitlementResolving` protocol.
   - Provide static stub data (`paidTemplateIDs`, default teaser config) and default resolver returning `false` for entitlement checks.

2. **Badge View Component**
   - Add `TemplatePriceBadge` SwiftUI view (new file if needed) rendering lock/PRO visuals with optional label.
   - Ensure design adapts to light/dark modes and scales via Dynamic Type.

3. **TemplateLibraryView Integration**
   - Update `TemplateCard` (within `TemplateLibraryComponents.swift`) to show badge when:
     - `FeatureFlags.templateIAPEnabled` is `true` and
     - `TemplateMonetizationCatalog.badge(for: template)` returns non-nil.
   - Keep layout stable for free templates (no spacing shifts when badge absent).

4. **Preview Teaser Logic**
   - Extend preview components (`TemplatePreviewView` / `TemplatePreviewSections` / `TemplatePreviewComponents`) to query the catalog & resolver.
   - Introduce helper (e.g., `TemplatePreviewTeaser`) to slice phases/task lists/tasks per `TemplateTeaserConfig` when locked.
   - Add `LockedContentNotice` view at the end of truncated sections.

5. **Localization & Strings**
   - Add new localized strings for badge labels and locked notice (Japanese + fallback).

6. **Flag Handling**
   - Gate all new UI via `FeatureFlags.templateIAPEnabled`; early returns prevent monetization UI when flag is `false`.

7. **Validation**
   - Build the project (iphonesimulator) to ensure SwiftUI compilation succeeds.
   - Manual spot check by toggling the flag constant (if easily done) to confirm UI behavior.

## Notes
- Keep modifications focused; no paywall or navigation changes in this slice.
- Ensure new files remain under ~300 lines; split if badge/teaser helpers grow.
- Maintain existing accessibility traits (e.g., voiceover labels for badges/lock notices).

