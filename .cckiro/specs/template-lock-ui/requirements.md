# Requirements: Template Library Lock UI

## Context
- Monetization groundwork requires signaling which templates are paid-only before purchase flows are active.
- Step 2 of the rollout focuses on UI affordances: indicate locked templates and limit preview depth when monetization flags opt-in.
- Existing behavior must remain unchanged when all monetization flags are `false`.

## Functional Requirements
1. **Template List Badging**
   - Within `TemplateLibraryView`, paid templates display a lock/`PRO` style badge when `FeatureFlags.templateIAPEnabled == true`.
   - Free templates retain current presentation (no badge).
   - Badge logic relies on a centralized monetization catalog (no scattered hard-coding).
2. **Preview Access Restriction**
   - `TemplatePreviewView` (and supporting sections) show only a teaser subset when a template is paid and the user lacks entitlement (assume “no entitlement” for now; purchase flows ship later).
   - Teaser should reveal the first few tasks/tasklists to hint at content while clearly indicating remaining content is locked.
   - Free templates continue to show the full detail as today.
3. **State Awareness Utilities**
   - Provide an easily testable API (e.g., `TemplateMonetizationCatalog`) that surfaces:
     - Whether a given template ID is paid.
     - Optional metadata such as badge label (lock vs PRO) for future use.
   - Keep catalog data stubbed for now but structured for future remote/RC sourcing.

## Non-Functional Requirements
1. All monetization visuals are hidden when `templateIAPEnabled` is `false` (regardless of other flags).
2. No runtime crashes when StoreKit is unavailable; this slice should not call purchase APIs.
3. Maintain SwiftUI file size/clarity (split helpers if additional views make files unwieldy).
4. Avoid introducing side effects to template selection flow; selecting a template still dismisses the library immediately.

## Out of Scope
- Purchase buttons, paywall navigation hooks, or entitlement-aware unlocks.
- Telemetry instrumentation.
- Persisting entitlement state beyond stub assumption.

## Acceptance Criteria
- Build succeeds on iOS 15+.
- With all monetization flags `false`, Template Library and previews look identical to current behavior.
- When `templateIAPEnabled` is toggled `true`, paid templates in the list show a lock/PRO badge and their previews truncate after the configured teaser length while free templates remain unaffected.
- Monetization catalog offers a single source of truth and is referenced by both list and preview layers.
最小補足（ブレ防止）
	•	単一の真実源：TemplateMonetizationCatalog は
	•	func isPaid(_ id: TemplateID) -> Bool
	•	func badge(for id: TemplateID) -> MonetizationBadge?（例：.lock / .pro / nil）
を提供。リスト/プレビュー両方ここだけ参照（散在ロジック禁止）。
	•	ティーザー長：プレビューの切り詰めは固定数 or しきい値を明示（例：teaserCount = 5 またはセクション2つ）。空テンプレでも例外が出ないようガード。
	•	フラグ優先順位：templateIAPEnabled == false のときは常にバッジ非表示 & ティーザー無効（他フラグに依存しない）。
	•	権利判定は今回は固定：「常に未所持」を前提にUIだけ実装（Entitlement連動は後続）。

受け入れ基準（再掲＋微調整）
	•	iOS 15+ でビルド成功。
	•	Flags 全OFF：リスト/プレビューが現状と完全一致。
	•	templateIAPEnabled == true：
	•	有料テンプレのみバッジ表示（無料は表示無し）。
	•	有料テンプレのプレビューはティーザーで明確に“残りロック”表示。無料は従来どおり全表示。
	•	リスト/プレビューが同じカタログAPIを参照（テストで差し替え可能）。