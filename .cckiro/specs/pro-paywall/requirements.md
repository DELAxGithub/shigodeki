# Requirements: PRO Subscription Paywall (Step 5)

## Goal
Introduce PRO subscription triggers and paywall presentation that leverage the existing purchase infrastructure. Focus is on functionality and wiring; visual polish can remain minimal.

## Functional Requirements
1. **Paywall Entry Points**
   - From template paywall view: provide an upsell CTA (“PROで全て解錠”) when encountering a paid template while PRO benefits apply (AI unlock, full template access).
   - From AI-related UI (e.g., TaskAIAssistantView) when the user lacks `isPro`, prompt the PRO paywall.
2. **PRO Paywall View**
   - Display benefits list: unlimited templates, AI assistant, family sharing.
   - Show monthly and yearly options with pricing retrieved via `PurchaseProductCatalog`.
   - Allow switching between plans (segmented control or simple buttons).
   - Trigger purchase via `ProSubscriptionCoordinator`; respect `FeatureFlags.proSubscriptionEnabled` and `purchasesEnabled`.
3. **Purchase Handling**
   - On verified success, dismiss paywall and allow the originating action to proceed (templates unlock, AI action resumes).
   - Pending/cancelled/failed states stay on paywall with status message.
4. **Flag Handling**
   - Entire paywall/PRO CTAs appear only when `proSubscriptionEnabled == true` and `purchasesEnabled == true`.
   - When flags off, fallback to existing behavior (AI blocked message, template paywall only showing single purchase).

## Non-Functional Requirements
1. Reuse environment-injected coordinator/catalog; no global singletons.
2. PII-free logging on errors.
3. Keep UI simple; strings localized later but Japanese text acceptable for now.
4. Ensure paywall can be presented from multiple contexts without leaking state (use `@State` per presenter).

## Acceptance Criteria
- Build succeeds after integration.
- When PRO flags are off, UI behaves exactly as before (no new CTAs).
- With flags on and user not PRO: selecting PRO CTA launches paywall; successful purchase sets `isPro`, unlocking AI and templates (observed via entitlement flow).
- Monthly/yearly toggle updates price labels using cached product data; repeated openings reuse cached values.
- Purchases disabled flag produces guarded failure without reaching StoreKit.
最小明確化ポイント
	•	フラグ優先順位
	•	proSubscriptionEnabled && purchasesEnabled が 両方true のときのみ PRO CTA と Paywallを露出。
	•	どちらかfalseなら 既存挙動（テンプレ単品のみ／AIブロックメッセージ）。
	•	遷移復帰
	•	Verified成功時は 呼び出し元へクロージャで成功通知（例：onProUnlocked()）。
	•	テンプレ起点：onProUnlocked → そのテンプレのDraft生成→Previewを自動再開。
	•	AI起点：onProUnlocked → AIアクションを同一入力で再実行（入力を保持するPendingAIActionなどの軽量ステートが必要）。
	•	価格取得
	•	PurchaseProductCatalog の セッションキャッシュを必ず経由。
	•	キャッシュ未ヒットのみ StoreKit へ。プラン切替時はキャッシュから即時反映。
	•	結果ハンドリング
	•	verified==true → EntitlementStore.refresh() 済み → Paywall閉じる→onProUnlocked()実行。
	•	pending/cancelled/failed → Paywall上に簡潔なステータスメッセージ、閉じるまで待機。
	•	purchasesEnabled==false → ガード失敗（UIに「購入を有効化してください」等のメッセージ）。
	•	状態の漏れ防止
	•	Paywallは各プレゼンターで @State 管理（選択プラン、ローディング、結果）。
	•	閉じたらステート初期化。

受け入れ基準（再掲・具体化）
	•	フラグOFF時は UI/導線の差分ゼロ。
	•	フラグON＋非PRO：
	•	PRO CTA押下でPaywall表示 → 月/年の表示価格が即時出る（キャッシュ利用）。
	•	成功（verified）で isPro==true が反映され、AIと有料テンプレが即解錠。
	•	同じセッションで再度開いても価格はキャッシュから（StoreKit再呼び出しなし）。
	•	purchasesEnabled==false でCTA押下：StoreKit未呼び出しの guarded failure。