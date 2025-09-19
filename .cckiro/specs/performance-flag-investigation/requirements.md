# Requirements: Feature Flag Performance Investigation

## Context
- Recent internal builds report "挙動が重い" across launch, navigation, list scrolling, and AI preview flows.
- Multiple opt-in features are gated behind Remote Config/UserDefaults driven flags (`FeatureFlags` in `iOS/shigodeki/Utilities/FeatureFlags.swift`).
- Some flags requested for triage (`projectCardsSummary`, `offlineBadgesEnabled`, `taskOrderIndexEnabled`) are only partially wired or missing runtime overrides, so the first pass must confirm their availability before collecting UX samples.

## Objectives
1. Provide a 10-minute toggle matrix to surface the dominant regression by comparing flag-on/off behaviour for key UX surfaces.
2. Capture short-term configuration levers that can be applied without major code surgery.
3. Map durable fixes by subsystem so follow-up specs can focus scope.
4. Align on instrumentation and success metrics so future PRs can validate performance budgets explicitly.

## Phase 1 — Flag A/B Triage (Target: ≤10 min)

### 1.1 Required Prework
- Ensure every flag below resolves through `RemoteConfigGate.bool(forKey:default:)`. Missing accessors must be added in `FeatureFlags` before testing.
  - `projectCardsSummaryEnabled` → guards the expensive statistics row in `ProjectRowView` / `OptimizedProjectRow`.
  - `offlineBadgesEnabled` → controls conflict/pending badges (expected in task rows once wired).
  - `taskOrderIndexEnabled` → enables custom ordering pipeline in `TaskListDetailView` and associated managers.
- Add temporary logging (e.g. `print("[Flags] ...")`) on app launch to confirm the resolved values for each flag before every run.

### 1.2 Toggle Matrix (fill observations inline)
| Flag Key | Primary Touchpoints | Toggle Method (Debug) | Scenario Checklist | Observation Notes |
| --- | --- | --- | --- | --- |
| `kpiDashboardsEnabled` | `ProjectPortfolioKPIViewModel` header fetch (`iOS/shigodeki/ViewModels/ProjectPortfolioKPIViewModel.swift`) | `defaults write com.hiroshikodera.shigodeki.dev kpiDashboardsEnabled -bool 0` (reset via `defaults delete ...`) | App cold launch → Project list idle 5s → Pull-to-refresh | |
| `projectCardsSummaryEnabled` | Project list cell stats (`ProjectRowView`, `OptimizedProjectRow`) | `defaults write ... projectCardsSummaryEnabled -bool 0` | Project list scroll (fast swipe) | |
| `offlineBadgesEnabled` | Task row badges once implemented | `defaults write ... offlineBadgesEnabled -bool 0` | Task list scroll + sync churn (toggle airplane mode) | |
| `taskOrderIndexEnabled` | Drag/drop ordering & diff listeners | `defaults write ... taskOrderIndexEnabled -bool 0` | Long task list drag reorder thrice | |
| `unifiedPreviewEnabled` | `TaskListDetailView` add flow & AI assistant preview | `defaults write ... unifiedPreviewEnabled -bool 0` | AI assistant open → generate → accept | |
| `previewAIEnabled` / `previewPhotoEnabled` / `previewTemplateEnabled` | Submodules under unified preview | Pair with `unifiedPreviewEnabled`; set individual subflag -> 0 | Trigger respective preview types | |
| `previewAIEnabled` (tests paywall as well) | Paywall gating in `TaskAIAssistantView.swift` | Combine with entitlement mocks | AI generate after toggling flag | |

**Reset command:** `defaults delete com.hiroshikodera.shigodeki.dev <flagKey>`.

**Observation template:** Capture (a) scenario (`起動 / 画面遷移 / リストスクロール / Paywall表示 / AI生成後`) and (b) qualitative rating (`◎ / ○ / △ / ✕`). Log a single table in `docs/perf-runbook.md` (create if missing) with timestamp for reproducibility.

### 1.3 Flag Effect Sanity Checks
- `kpiDashboardsEnabled` should suppress the KPI header entirely; verify `state == .hidden` via breakpoint.
- `projectCardsSummaryEnabled` should short-circuit additional Firestore listeners beyond core project fields; if wiring is missing, create a tech-debt ticket before continuing.
- `unifiedPreviewEnabled` false should bypass `DraftSaveFacade` preview pipeline (`iOS/shigodeki/Services/DraftPipeline/DraftSaveFacade.swift`).

## Phase 2 — Immediate Mitigation Playbook

- **Throttle KPI refreshes**: adjust `KPIRefreshScheduler.schedule` ( `iOS/shigodeki/Services/KPI/KPIRefreshScheduler.swift:29` ) to enforce ≥180 s between fetches when app foregrounds frequently, and expose `coalesceInterval` so we can widen from 300 ms → 800 ms without code edits.
- **Extend cache TTLs**: keep `ProjectPortfolioKPIViewModel.cacheTTL` at 5 min but raise `staleThreshold` to ≥3 min when `kpiDashboardsEnabled` is true to avoid forced recompute loops.
- **Scope `collectionGroup("tasks")` queries**: add `.whereField("ownerId", isEqualTo: currentFamily)` or `.limit(to: 200)` on member-facing dashboards (`iOS/shigodeki/Services/KPI/KPIDataSource.swift:17`, `MemberDataService` queries at lines 131/173) to prevent full scans during triage.
- **Project cards lazy-load**: behind `projectCardsSummaryEnabled`, gate the expensive stats body so initial rows only show title/status; fetch summaries asynchronously and hydrate via `Task` or a lightweight cache update.
- **Telemetry gating**: wrap high-volume `print` logs in `#if DEBUG` (see `ProjectListView.swift:94` onward) and aggregate repeated statements to prevent I/O stalls in release-like builds.
- **Image handling**: in `TaskListDetailView` attachments loop (~line 49), cap `AsyncImage` size and set `.interpolation(.low)` plus caching (tap into `ImageCache.shared`).
- **Paywall price cache check**: confirm `PurchaseProductCatalog.products(for:)` caches hits before invoking StoreKit to keep paywall show latency low; add assertion logs if `missingIDs` is empty but fetch still occurs.

## Phase 3 — Durable Fixes by Surface

### A. Task List (`TaskListDetailView.swift`)
- Stabilise IDs: ensure `ShigodekiTask` conforms to `Identifiable` with stable `id` + `orderIndex` combination when the ordering flag is on.
- Precompute decorations: move badge/formatter work into `TaskListDetailViewModel` so the body only binds to lightweight value types.
- Collapse listeners: consolidate `.onReceive` publishers at view-model level to reduce redundant refresh triggers.

### B. Project List & KPI Header
- Offload KPI aggregation to background actors (`PortfolioKPIEngine`) and publish only snapshots via `MainActor` updates.
- Implement diff-based updates: track `projectIds` delta so recalculations operate on changed projects rather than recomputing the full array.

### C. Firestore Access Patterns
- Audit listeners to avoid duplicate `projects/{id}` subscriptions between `ProjectListViewModel` and detail managers.
- Add composite indexes for new where-clause combinations introduced during throttling.

### D. AI / Photo / Template Preview Pipeline
- Ensure LLM calls, JSON decoding, and photo analysis run off the main thread; `TaskAIAssistantView` should only update published state when results are ready.
- Render preview shell immediately (“生成中…”) before heavy work; gate final render by toggles so we can short-circuit experimental features quickly.

### E. Undo / Sync Queue
- Keep queue mutations off the main thread; publish summary (`syncStatus`) changes via a debounced actor to prevent badge thrash.
- Coalesce consecutive badge updates into a single event when toggling `offlineBadgesEnabled`.

## Phase 4 — Instrumentation Plan

- **Time Profiler (Instruments)**: run with `All Thread States` filter and capture top 10 methods when reproducing slow scenario. Flag any SwiftUI body recomputations >5% of total time.
- **SwiftUI Metrics**: attach the SwiftUI template to count body recomputes for `ProjectRowView` and `TaskListDetailView` while toggling flags.
- **Allocations**: sample for 30 s while scrolling; confirm no unbounded growth from `RelativeDateTimeFormatter` or `DateFormatter` instantiations.
- **Network**: use Firestore instrument to plot read spikes during filter changes; record counts to compare against the 200-read budget.
- **OSSignpost hooks** (optional): add `Logger` signposts around KPI fetch, AI generation, and paywall render to correlate with Instruments timelines.

## Phase 5 — Success Criteria
- Scroll (Task list & Project list) p95 frame time `< 16 ms` on iPhone 13 class device.
- KPI header first paint `< 300 ms` after data fetch; stale refresh stays off main thread.
- Filter toggle additional Firestore reads `< 200` per interaction.
- AI preview shell presents `< 100 ms`; final content can land later but should not block UI.
- No more than one paywall product fetch per session when cache seed is available.

## Appendices

### A. Flag Utilities
- To enumerate overrides, run: `defaults domains | grep shigodeki` and `defaults read com.hiroshikodera.shigodeki.dev`.
- Consider adding a debug-only `FeatureFlagToggleView` under `iOS/shigodeki/Debug/` that binds to `UserDefaults` so QA can flip switches without CLI.

### B. Observation Log Template (`docs/perf-runbook.md`)
```
| Timestamp | Scenario | Flag Tweaks | Result (◎/○/△/✕) | Notes |
| --- | --- | --- | --- | --- |
```

直前チェック（5分）
	•	FeatureFlags：specで挙げた“未実装のアクセサ”を すべて追加（RC→UserDefaults→引数のカスケード順）。
	•	観測ポイント：ログ/テレメトリの受け皿（p95、read数、再計算回数）を空でも用意。
	•	ロールバック：各フラグを即OFFできることを確認。

実行順
	1.	フラグ実装を入れてビルド緑 → mainへ。
	2.	Phase-1 マトリクスを spec どおりに一気に回す（10分トグル × 各面）。
	3.	結果を docs/perf-runbook.md に記録（日時・端末・フラグ組合せ・体感/数値）。
	4.	即効ミティゲーションを該当箇所に適用（KPIRefreshScheduler/TaskList attachments など）。
	5.	予算（p95/レイテンシ）に収束しなかった面は、specの「Durable fixes」の粒度で個別Issue化。

GO判定
	•	スクロール p95 < 16ms
	•	初回KPI描画 < 300ms（スケルトン→ready）
	•	フィルタ切替の追加read < 200
	•	AIプレビュー初画面 < 100ms