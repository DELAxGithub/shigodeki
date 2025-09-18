# Design: Template Library Lock UI

## Architecture Overview
- Introduce `TemplateMonetizationCatalog` as the shared source of truth for template monetization metadata (paid/free, badge style, teaser limits).
- Extend existing template presentation layers (`TemplateLibraryView`, `TemplateCard`, `TemplatePreviewView`, and supporting preview/phase components) to conditionally render lock indicators based on catalog queries and `FeatureFlags.templateIAPEnabled`.
- Centralize teaser logic in a dedicated helper (`TemplatePreviewTeaser`) to keep view files tidy and to reuse truncation rules.

## Key Components
1. **TemplateMonetizationCatalog**
   - Static struct or singleton living under `Services/Purchases` (next to catalog/pricing helpers) to avoid scattering constants.
   - Exposes:
     - `static func isPaid(template: ProjectTemplate) -> Bool`
     - `static func badge(for template: ProjectTemplate) -> MonetizationBadge?`
     - `static func teaserConfig(for template: ProjectTemplate) -> TemplateTeaserConfig`
   - Maintains stubbed sets of paid template IDs and default teaser configuration (e.g., max task lists/tasks shown).
   - `MonetizationBadge` enum holds label+systemImage for future customization.

2. **TemplateLibrary Badging**
   - Update `TemplateCard` to ask catalog for a badge when `FeatureFlags.templateIAPEnabled` is `true`.
   - Introduce a small `TemplatePriceBadge` view that renders lock/PRO styling without bloating `TemplateCard`.
   - Badge appears near title or metadata for paid templates; free templates remain unchanged.

3. **Preview Teaser**
   - Add helper methods within `TemplatePreviewSections` (or an extracted component) to slice `phase.taskLists` and `taskList.tasks` based on teaser config when template is paid and entitlements missing.
   - Display a clear “Locked content” callout under truncated sections.
   - Ensure teaser logic is opt-in: when `FeatureFlags.templateIAPEnabled == false` or template is free, show full content as before.

4. **Entitlement Stub**
   - Introduce a lightweight `TemplateEntitlementResolver` protocol with default implementation that always returns “not entitled”. Future work can inject real entitlements.
   - Preview/list ask resolver before applying locks; default resolver lives as static on catalog for now.

## Data Flow
1. `TemplateLibraryView` renders templates. For each template:
   - Check `FeatureFlags.templateIAPEnabled`. If false, skip monetization UI.
   - If true, request `TemplateMonetizationCatalog.badge(for: template)` and render badge if non-nil.
2. When a user opens `TemplatePreviewView`:
   - Determine entitlement via resolver. If lacking and template is paid and flag enabled, `TemplatePreviewSections` uses teaser config to limit the number of task lists/tasks displayed.
   - A `LockedContentNotice` view communicates that remaining content is locked.

## Availability & Styling
- SwiftUI-only changes; no StoreKit requirements.
- Keep new helper views small (<100 lines). If `TemplateLibraryComponents.swift` grows too large after badge addition, extract to a nested file (e.g., `TemplatePriceBadge.swift`).

## Future Extension Points
- Tie `TemplateEntitlementResolver` to real `EntitlementStore`.
- Expand catalog to carry price strings and remote metadata.
- Replace stubbed paid template IDs with Remote Config or configuration files.

最小明確化
	•	カタログの単一責務
	•	TemplateMonetizationCatalog は 定数・判定・ティーザー設定までに限定。状態（購入情報）は持たない。
	•	権利の有無は TemplateEntitlementResolver に委譲（今回は常に未所持）。
	•	ティーザー設定の境界
	•	テンプレごとに TemplateTeaserConfig(maxLists:Int, maxTasksPerList:Int) を返し、ゼロや閾値超過でも安全にスライス。
	•	空テンプレや短いテンプレでも例外が起きないよう min(actual, limit) でガード。
	•	Flag優先順位
	•	FeatureFlags.templateIAPEnabled == false のときは
	•	バッジ非表示
	•	ティーザー無効（フル表示）
	•	これを各Viewで早期returnにしておくと漏れが出ません。
	•	UIの一貫性
	•	TemplatePriceBadge の表示位置・色はダークモード/アクセシビリティで読めるコントラストに。
	•	LockedContentNotice は簡潔に（例：鍵アイコン＋「残りはPROで解放」など）。テキストは Localizable.strings へ。

受け入れ基準（再掲）
	•	Flags 全OFFで完全回帰。
	•	templateIAPEnabled == true で
	•	有料テンプレのみバッジ表示
	•	プレビューがティーザーに切り替わり、明示のロック表示
	•	リスト/プレビューとも同じカタログAPIを参照。