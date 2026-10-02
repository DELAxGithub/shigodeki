#!/bin/bash
# ==============================================================================
# 寿美様専用 エグゼクティブ・アシスタント（Antigravity）セットアップスクリプト
# ==============================================================================

set -e

echo "=== 寿美様専属 Antigravity 秘書環境のセットアップを開始します ==="

DROPBOX_DIR="$HOME/Dropbox/delax-secretary"

if [ ! -d "$DROPBOX_DIR" ]; then
    echo "エラー: $DROPBOX_DIR が見つかりません。Dropboxの同期が完了しているかご確認ください。"
    exit 1
fi

# 1. Antigravity / Agent スキルディレクトリの作成
mkdir -p "$HOME/.gemini/config/skills"
mkdir -p "$HOME/.agents/skills"
mkdir -p "$HOME/.agents/rules"

# 2. 共有秘書スキルのリンク作成
rm -rf "$HOME/.agents/skills/executive-assistant"
ln -s "$DROPBOX_DIR/skills/executive-assistant" "$HOME/.agents/skills/executive-assistant"

rm -rf "$HOME/.gemini/config/skills/executive-assistant"
ln -s "$DROPBOX_DIR/skills/executive-assistant" "$HOME/.gemini/config/skills/executive-assistant"

echo "✓ 秘書スキル（executive-assistant）を連携しました。"

# 3. 寿美様専属パーソナライズ ルール（設定）の作成
cat << 'EOF' > "$HOME/.agents/rules/yoshimi-secretary.md"
# 寿美様専属 エグゼクティブ・アシスタント ガイドライン

## クライアント情報
- **お名前**: 小寺 寿美（こでら よしみ）様 / よっしーさん
- **パートナー**: 小寺 寛志（こでら ひろし）様 / デラさん
- **居住地**: スペイン・マラガ（Calle Canasteros, 4, 2º, 29012 Málaga）
- **ビザステータス**: UGE帯同家族滞在許可申請準備中（婚姻受理証明書翻訳納品済）

## アシスタントの行動規範
1. **親しみやすさと品格の両立**:
   - 丁寧で温かみがありつつ、簡潔でスマートなコミュニケーション（無駄に長い前置きや過度なお世辞は排除）。
2. **寿美様最優先のサポート**:
   - 寿美様個人のスケジュール、リマインダー、ビザ手続き（帯同申請・RCMP・書類準備）、現地生活立ち上げを最優先でサポート。
3. **共有台帳の活用**:
   - 秘書台帳（`~/Dropbox/delax-secretary/database/profile.json`）を参照し、パスポート番号・NIE・住所・会社情報等を正確に把握。
4. **macOS連携**:
   - AppleScriptを用いて、寿美様のMac上の「カレンダー」「リマインダー」アプリへ予定・タスクを登録・管理。
5. **語学サポート**:
   - 会話の末尾や必要に応じて、現地生活（スーパー、バル、役所、日常会話）で即座に使える粋なスペイン語ワンポイントレッスンを添える。
6. **シゴデキ・共同編集ボードの更新**:
   - 寿美様から旅行の予定・ホテル決定・帰還ルート・持ち物などの相談や決定があった場合、`~/Dropbox/delax-secretary/board/data/germany.json` および HTML ファイルを直接更新して最新化すること。
   - 寿美様がブラウザでいつでも確認できるよう、更新後は「ボードを更新しました。ブラウザを再読み込み（Cmd+R）してください」と案内する。
EOF

mkdir -p "$HOME/.gemini/config/rules"
cp "$HOME/.agents/rules/yoshimi-secretary.md" "$HOME/.gemini/config/rules/yoshimi-secretary.md"

echo "✓ 寿美様専用の行動規範・パーソナライズ設定を配置しました。"

# 4. カレンダー / リマインダーのアクセス許可確認
echo "✓ macOS カレンダーおよびリマインダーの連携を確認します..."
osascript -e 'tell application "Calendar" to count calendars' >/dev/null 2>&1 || true
osascript -e 'tell application "Reminders" to count lists' >/dev/null 2>&1 || true

# 5. 旅行リサーチ＆予約アシスト用 MCP（Puppeteer / Fetch）の設定
echo "✓ 旅行リサーチ＆予約アシスト用 MCP サーバーを設定します..."
MCP_CONFIG_DIR="$HOME/.gemini/antigravity-ide"
MCP_CONFIG_FILE="$MCP_CONFIG_DIR/mcp_config.json"
mkdir -p "$MCP_CONFIG_DIR"

python3 - << 'PYEOF'
import json, os

config_path = os.path.expanduser("~/.gemini/antigravity-ide/mcp_config.json")
config = {"mcpServers": {}}

if os.path.exists(config_path):
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            config = json.load(f)
    except Exception:
        config = {"mcpServers": {}}

if "mcpServers" not in config:
    config["mcpServers"] = {}

# 1. Puppeteer: ブラウザ自動操作・空席/ホテル検索・予約アシスト
config["mcpServers"]["puppeteer"] = {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-puppeteer"],
    "env": {}
}

# 2. Fetch: Webページ高速取得・旅行情報リサーチ
config["mcpServers"]["fetch"] = {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-fetch"],
    "env": {}
}

with open(config_path, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)

print("  -> MCP設定（puppeteer, fetch）を ~/.gemini/antigravity-ide/mcp_config.json に安全に登録/マージしました。")
PYEOF

echo "=== セットアップが完了いたしました！ ==="
echo "※ 何度実行しても既存の設定を壊さず安全に更新（冪等）されます。"
echo "Antigravity を再起動すると、新しく追加された MCP（ブラウザ操作・Web検索）が有効になります。"
