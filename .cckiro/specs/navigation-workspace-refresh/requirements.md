# Requirements: Navigation Workspace Refresh

## Context
- Current bottom-tab layout (`ホーム`, `プロジェクト`, `チーム`) duplicates entry points and hides the core workflows that beta testers actually perform.
- Shigodeki’s differentiator is AI-assisted WBS creation; users spend more time reviewing drafts, reordering phases, and toggling task state than they do manually adding tasks.
- Feedback during TestFlight prep highlighted that “Home” is just another path to the project list and feels dated compared to modern Apple apps that surface personal workload or shared updates up front.
- We must support shared/team-centric usage without forcing users to hop between tabs to answer “what should I do next?”

## Functional Requirements
1. **Dashboard First Experience**
   - Replace the existing `ホーム` tab with a dashboard surface that aggregates:
     - Tasks assigned to the current user (across projects/families).
     - Pending AI draft reviews or photo/template suggestions waiting for confirmation.
     - Time-sensitive items (due soon / overdue) pulled from `TaskListDetailView` data.
   - The dashboard must deep-link back into the relevant phase/task detail with one tap.
2. **Project Browsing Tab**
   - Maintain a dedicated `プロジェクト` tab focused on full project/phase exploration and management.
   - Remove redundant shortcuts that simply mirror the dashboard lists; this tab should emphasize structural editing (create project, add phase, reorder sections).
3. **Team / Sharing Tab**
   - Keep `チーム` as the hub for family membership, invites, and ownership transfers.
   - Surface unread invite cues (badge/dot) when new codes or requests are pending so that the shared workflow remains obvious from the tab bar.
4. **Persistent Quick Add**
   - Provide a single floating action (or toolbar button) visible on dashboard and project detail screens for creating content (manual task, AI request, template import) so users never need to switch tabs just to add work.
5. **State-aware Navigation**
   - Respect existing feature flags (`FeatureFlags.unifiedPreviewEnabled`, `previewAIEnabled`, etc.) when deciding which actions to present.
   - Navigation elements must fail gracefully if a flag is off (e.g., hide AI preview section, leave manual add available).

## Non-Functional Requirements
1. SwiftUI files must stay within the ~300 line guideline by extracting new components (dashboard cards, badge indicators) as needed.
2. Navigation should remain responsive on iOS 15+ and work with existing `SharedManagerStore` bootstrapping (no double fetch or listener leaks).
3. Maintain accessibility: new surfaces require labels, hints, and Dynamic Type support equivalent to existing views.
4. Beta manual and PlantUML diagrams must be updated alongside UI changes to keep documentation in sync.

## Out of Scope
- Replacing the bottom tab bar with a completely different nav paradigm (e.g., sidebars) for this iteration.
- Reworking Firestore schemas or feature flag infrastructure.
- Monetization or paywall surfacing in dashboard cards.

## Acceptance Criteria
- Launching the app lands on the new dashboard; direct project list transition is removed from `ホーム`.
- Dashboard shows at least one card each for “My tasks” and “Pending AI drafts” when data exists, with tap-through into phase/task views.
- Project tab retains creation/edit flows without duplicate dashboard cards.
- Team tab displays a visible indicator when invite-related changes occur.
- QA can run through the checklist in `docs/testflight-beta-manual.md` without tab confusion, and updated docs reference the new navigation labels.
