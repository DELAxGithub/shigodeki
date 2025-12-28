# MVP (v0.1 PoC)

## 完成条件（10項目以内）
1. **家族参加フローが安定稼働** — `UnifiedInvitationService` 経由で生成したコードを O/0, I/1 混同でも Join でき、`docs/validation-test.md` の Create→Display→Join 手順を本番 Firestore で再現済み。
2. **招待/家族関連の Firestore ルールが最小権限** — `families/{id}` / `users/{uid}` の明示配列更新、`invitations_unified/{code}` の +1 ルールを厳密化し、レガシー `invitations` ルールを撤廃しても QA を通過する。
3. **タスク追加が TaskAddModal に一本化** — `CreatePhaseTaskView` やダッシュボードの `作業を追加` が常に `TaskAddModal` を開き、`Back to Family` ショートカットと UI テスト（Family→Project→Task→戻る）が緑になる。
4. **すべての追加ルートが Preview→Undo パイプラインに接続** — Manual/AI/Photo/Template が `TaskDraft` を生成して `TasksPreview` に流れ、Accept で `.pending` 作成・Undo で取り消し・`Telemetry.onPreviewShown/onTaskAdded` を発火する。
5. **SyncQueue + バッジで同期状態が見える** — `SyncQueue` が enqueue/retry/backoff を行い、`Task.syncStatus`/`SyncStatusBadge`/Undo toast/Retry ボタンが FeatureFlag 経由で有効になっている。
6. **タスク並び順とドラッグが永続化** — `Task.orderIndex` を明示配列で保存し、フェーズ内のドラッグ→リロードで順序が保持されることを UITest で確認する。
7. **KPI/カードの最小版が PoC で確認できる** — `Project.metrics` を計算するサービスが存在し、ProjectList に進捗カード・ProjectDetail に主要 KPI セクションが FeatureFlag on の家族で表示される。
8. **AI/写真/テンプレが PoC で実用レベル** — `TaskAIAssistantView` の manual fallback と API キー検証により、キー未設定時は案内/代替テンプレが表示され、TidyPlanKit 写真入力が 1 つの成功経路を持つ。
9. **TestFlight 配信 + テレメトリー動線が用意される** — README のリリースチェックリスト（TestFlight 招待リンク、Beta manual 更新、ロギング）を満たし、`Firebase Remote Config` からフラグを切り替えられるビルドを家族端末へ提供できる。

## v0.1 ではやらないこと（スコープ外）
- 課金・サブスクリプション解放（`FeatureFlags.purchasesEnabled`/`proSubscriptionEnabled` は引き続き off）。
- 決済連動テンプレ／テンプレ IAP の実装と審査対応。
- 完全オフラインモードやローカルキャッシュの再設計（現状はオンライン前提）。
- プッシュ通知・メール通知などリアルタイムアラートの外部連携。
- KPI v2（フェーズ依存関係可視化、トレンド可視化の詳細グラフ）や AI コーチングなど将来の高度分析機能。
