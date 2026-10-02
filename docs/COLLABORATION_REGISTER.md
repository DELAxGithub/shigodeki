# 秘書台帳：夫婦共同作業・マルチエージェント環境（シゴデキ）

**最終更新日**: 2026年10月02日  
**統括エージェント**: Antigravity Executive Assistant  
**対象**: 小寺 寛志（デラ） & 小寺 寿美（よっしー）

---

## 1. 共同作業システムの全体アーキテクチャ

デラさんの作業環境（Mac）とヨッシーさんの作業環境（MacBook Air M2）は、**GitHub（コード・ボードSSoT）** と **Dropbox（リアルタイム共有ハブ）** のハイブリッド構成で連携しています。

```mermaid
graph TD
    subgraph DelaMac [デラさん作業環境]
        DelaIDE[Antigravity / Codex]
        DelaLocalGit["/Users/delaxpro/src/10_apps/shigodeki<br>(Git SSoT)"]
        DelaIDE -->|編集 & コミット| DelaLocalGit
    end

    subgraph Cloud [クラウド連携]
        GitHub["GitHub (DELAxGithub/shigodeki)"]
        Dropbox["Dropbox/delax-secretary/"]
    end

    subgraph YoshimiMac [ヨッシーさん作業環境 (M2 MBA)]
        YoshimiDropbox["~/Dropbox/delax-secretary/"]
        YoshimiIDE[Antigravity IDE<br>(delax-secretaryフォルダを開く)]
        YoshimiBrowser[Safari / Chrome<br>(board/*.html を閲覧)]
        YoshimiIDE -->|JSON/HTML更新| YoshimiDropbox
        YoshimiDropbox -->|ダブルクリック| YoshimiBrowser
    end

    DelaLocalGit -->|git push| GitHub
    DelaLocalGit -->|自動ミラーリング| Dropbox
    Dropbox <-->|リアルタイム同期| YoshimiDropbox
```

---

## 2. ディレクトリ構成と役割

| パス | 種別 | 役割・用途 |
|---|---|---|
| `~/src/10_apps/shigodeki/` | Git Repo | シゴデキWebボードおよびアプリの正規ソースコード |
| `~/Dropbox/delax-secretary/` | 共有フォルダ | デラ・ヨッシー間のリアルタイム共有ハブ |
| `~/Dropbox/delax-secretary/board/` | HTML/Web | ブラウザで直接閲覧できるダッシュボード |
| `~/Dropbox/delax-secretary/database/` | 台帳 | `profile.json`、各種マスター情報、本台帳 |
| `~/Dropbox/delax-secretary/handover/` | メモ | エージェント間の引き継ぎ・状態スナップショット |
| `~/Dropbox/delax-secretary/skills/` | スキル | ヨッシー側Antigravity用のAI秘書スキル |

---

## 3. 各マシンの運用ルールと設定

### デラさん環境（Dela Mac）
- **役割**: 司令塔・総合管理・Git push/pull。
- **ミラーリング**: `shigodeki/board/` を変更した際は、必ず `~/Dropbox/delax-secretary/board/` に反映する。

### ヨッシーさん環境（Yoshimi MacBook Air M2）
- **Antigravity設定**:
  - ホームディレクトリ（`~`）全体を開かず、**`Dropbox/delax-secretary` フォルダ単体** を開く（M2チップでの負荷軽減・高速化のため）。
  - モデルは推論の速い **Gemini 2.5 Flash** を推奨。
- **AI秘書への指示例**:
  - 「エッセンのホテル候補を調べてシゴデキボードに入れて」
  - 「10/26の私のデュッセルドルフ〜マラガ便を調べてヒアリングシートに回答反映して」
- **ブラウザ閲覧**:
  - `Dropbox/delax-secretary/board/germany-2026/index.html` をダブルクリックするだけで最新の旅のしおり・スケジュールを確認可能。

---

## 4. トラブルシューティング & 連絡網
- **Q: MacBook AirのAntigravityが急に重くなった**
  - **A**: 開いているプロジェクトフォルダが `~`（ホーム全体）になっていないか確認。「File > Open Folder」で `Dropbox/delax-secretary` のみを開き直してください。
- **Q: ボードが更新されない**
  - **A**: Dropboxアプリが両方のMacで緑色のチェックマーク（同期完了）になっているか確認してください。
