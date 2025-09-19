# Design: Navigation Workspace Refresh

## Goals
- Present a “what should I do next?” dashboard tailored to Shigodeki’s AI-assisted workflow.
- Keep project and team management flows available without duplicating information from the dashboard.
- Introduce navigation affordances that feel modern (cards, contextual badges) while reusing existing stores/managers.

## Architecture Overview
- **DashboardView (new)**
  - SwiftUI view composed of stacks of reusable `DashboardCard` components.
  - Consumes a new `DashboardViewModel` that hydrates:
    - Assigned tasks (`TaskAssignmentService` additions within `SharedManagerStore`).
    - Pending AI drafts via `DraftQueueService` (wrapping existing `DraftSaveFacade` state).
    - Due-soon summaries from `TaskListDetailViewModel` helpers.
  - Cards navigate via `NavigationLink`/`EnvironmentObject` to existing detail views to avoid duplicating logic.
- **MainTabView adjustments**
  - Replace `HomeHubView()` with `DashboardView()`.
  - Add optional central floating action button (SwiftUI overlay) that presents the existing `TaskAddModal` when tapped.
- **Team tab badge**
  - Extend `FamilyViewModel` to publish an `hasPendingInvites` Bool.
  - Tab bar item uses `.badge` when true (iOS 15 API), falling back to a custom overlay label if needed.
- **Project tab cleanup**
  - Remove home-specific shortcuts; ensure `ProjectListView` remains the root for structural edits.

## Data Flow
1. `DashboardView` requests data on appear, delegating to `SharedManagerStore` to avoid reinitializing managers.
2. `DashboardViewModel` derives sections:
   - **My Tasks**: Filter tasks where `assignedTo` equals current user. Uses cached data from `TaskListDetailViewModel` or new lightweight queries.
   - **AI Drafts**: Query pending drafts via `DraftQueueService.pendingDrafts(for:)` (new helper around existing pipeline state).
   - **Due Soon**: Sort assigned tasks by due date; compute counts and highlight overdue ones.
3. Each card yields navigation targets (phase ID, list ID) that existing views can consume.

## UX States
- Empty state cards (“タスクはありません”, “AIドラフトはありません”) mirror tone of current list empty states.
- Loading states reuse `LoadingOverlay` pattern to keep experience consistent.
- Feature flags drive card visibility: e.g., hide AI card when `previewAIEnabled == false`.

## Visual Treatment
- Cards use rounded rectangles with SF Symbols and accent colors matching palette in `ThemeManager`.
- FAB uses `.symbolVariant(.fill)` and `.background(.ultraThinMaterial)` to modernize the interaction.

## Risks & Mitigations
- **Data duplication**: tapping cards must not instantiate duplicate listeners. Mitigate by piping IDs into existing view models rather than creating new ones.
- **Performance**: dashboard aggregation could trigger heavy Firestore reads. Use cached data from managers and throttle refresh via `Task`/`async let` to avoid spikes (reference perf runbook).
- **Accessibility**: ensure cards are accessible buttons with descriptive `accessibilityLabel`. Provide reorderable list for VoiceOver to browse tasks.

## Open Questions
- Should the dashboard support multi-select bulk actions (marking several tasks complete)? Out of scope for the first iteration, but data model should allow later addition.
- How aggressively should we surface notifications/badges (e.g., cross-project comments)? TBD based on beta feedback.
