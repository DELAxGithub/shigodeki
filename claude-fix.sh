#!/bin/bash

# --- 設定 ---
PROJECT_NAME="shigodeki.xcodeproj"
SCHEME_NAME="shigodeki"
LOG_FILE="build_error.log"
PROMPT_FILE="claude_prompt.txt"

echo "🥊 ビルドを開始します..."

# xcodebuildを実行し、出力をログファイルとコンソールの両方に出力
# teeコマンドで出力を分岐させるのがポイント
xcodebuild -project "${PROJECT_NAME}" -scheme "${SCHEME_NAME}" -destination 'generic/platform=iOS' build | tee "${LOG_FILE}"

# ビルドが失敗した場合のみ実行
if [ ${PIPESTATUS[0]} -ne 0 ]; then
  echo "🚨 ビルドエラー発生！ Claudeへの質問を生成します..."

  # --- ここからが必殺技のコマンド入力 ---
  cat << EOF > "${PROMPT_FILE}"
あなたは、CLAUDE.mdの規約を熟知した、世界クラスのiOSエンジニアです。
以下のビルドエラーを解決するための修正案を、diff形式で提案してください。

# プロジェクトの前提条件
- 開発ルールはCLAUDE.mdに従います。特に300行ルールと単一責任の原則を重視してください。
- 修正は影響範囲を最小限に留めてください。

# ビルドエラーログ
\`\`\`
$(cat ${LOG_FILE})
\`\`\`

# 関連ファイル（必要に応じて手動で追加）
# 例：
# --- a/path/to/YourFile.swift
# ... file content ...
# +++ b/path/to/YourFile.swift
# ... file content ...

エラーの原因を分析し、具体的な修正コードを提示してください。
EOF

  echo "✅ 質問ファイル（${PROMPT_FILE}）が生成されました。内容をClaudeにコピーしてください。"
  # pbcopy < "${PROMPT_FILE}" # Macならこれでクリップボードに直接コピーできる
  open "${PROMPT_FILE}"

else
  echo "✅ ビルド成功！お見事！"
fi
