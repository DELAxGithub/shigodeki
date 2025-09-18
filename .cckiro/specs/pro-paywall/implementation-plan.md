# Implementation Plan: PRO Subscription Paywall

## Steps
1. **View State Types**
   - Add `ProPaywallView.PurchaseState`, selected plan enum, and price loading state.

2. **ProPaywallView**
   - Build SwiftUI view with monthly/yearly toggle, price display (via catalog), CTA linked to `ProSubscriptionCoordinator`.
   - Handle purchase outcomes (success/pending/cancel/failed) with messages.

3. **Environment Wiring**
   - Extend `PurchaseEnvironmentHolder` to provide a `ProSubscriptionCoordinator` and expose via environment key.

4. **Template Paywall Upsell**
   - Insert PRO upsell button within `TemplatePaywallView` when PRO flags + coordinator available.
   - Present `ProPaywallView` modally from template paywall; on success call template unlock.

5. **AI Surface Integration**
   - In `TaskAIAssistantView`, when `isPro` is false and AI action selected, present `ProPaywallView` instead of existing block message; on success, resume AI action.

6. **Flag Guards & Logging**
   - Ensure paywall only accessible when flags permit; otherwise show existing fallback message.
   - Log purchase outcomes without PII.

7. **Build Validation**
   - Run simulator build to ensure compile.

	二重タップ防止
購入CTAはタップ後に一時無効（processing 状態）→結果で戻す。連打で二重購入を防ぐ。
	•	復帰遅延ハンドリング
verified==true でも EntitlementStore.refresh() 反映まで最大数秒ズレることがある前提で、Paywall成功後は
	•	即時クロージャで起点へ通知（AI再実行/テンプレ解錠）
	•	かつ entitlements 変化も購読してUIが確実に同期
の二段構えに。
	•	失敗/保留メッセージ整備
pending / cancelled / failed(code) をユーザー文言にマップ（PIIなし）。pending は「確認中（後で自動反映）」と明示。
	•	ガードの一貫性
purchasesEnabled && proSubscriptionEnabled が両方trueでない限り：
	•	PROアップセルボタン非表示
	•	直接起動が試みられても起点側でガード失敗にフォールバック（既存ブロック文言を表示）
	•	価格キャッシュのリフレッシュ点
初回表示時ロード→以降はセッションキャッシュ。価格取得失敗時はリトライ導線を1つだけ（自動多重リトライ禁止）。
	•	起点コンテキストの保持
起点（テンプレID / AI入力）をPaywallに渡し、成功後の自動再開に使う。閉じると必ずクリア。
	•	リストア考慮（UI無しでも）
既にisPro==trueならPaywallは即クローズして起点を続行（無駄な購入UIを出さない）。
	•	A11y/ローカライズ準備
トグルと価格ラベルにaccessibilityLabel（後のUIテスト用IDにも流用）。文言は日本語仮でOKだがLocalizableへ。

受け入れチェック（追加）
	•	CTA連打で購入が二重実行されない。
	•	成功→即時再開＋entitlements反映のどちらでも解錠が確認できる。
	•	旗OFF時：テンプレPaywallのPROボタンが出ない／AIは既存ブロック導線のまま。
	•	価格ロード失敗→1タップで再試行でき、成功時はキャッシュ反映。
	•	isPro==trueで起動した場合、PRO Paywallは表示されずに起点が続行。