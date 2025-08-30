#!/bin/bash

# パフォーマンステスト実行スクリプト
# Phase 1: 問題可視化のための自動測定

echo "🚀 シゴデキ パフォーマンステスト開始"
echo "======================================"

# 変数設定
DEVICE_ID="iPhone 15 Pro"
SCHEME="shigodeki"
BUILD_DIR="./build"
RESULTS_DIR="./PerformanceResults"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 結果ディレクトリの作成
mkdir -p "$RESULTS_DIR/$TIMESTAMP"

echo "📱 テスト環境:"
echo "   Device: $DEVICE_ID"
echo "   Scheme: $SCHEME"
echo "   Results: $RESULTS_DIR/$TIMESTAMP"
echo ""

# 1. Releaseビルドの作成
echo "🔨 Releaseビルド実行中..."
xcodebuild clean -scheme "$SCHEME" -configuration Release > "$RESULTS_DIR/$TIMESTAMP/build.log" 2>&1

if [ $? -eq 0 ]; then
    echo "✅ ビルド成功"
else
    echo "❌ ビルド失敗 - build.logを確認してください"
    exit 1
fi

# 2. シミュレータの起動
echo "📱 シミュレータ起動中..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || echo "シミュレータは既に起動中"

# シミュレータが完全に起動するまで待機
sleep 5

# 3. パフォーマンステストの実行準備
echo "📊 パフォーマンステスト準備中..."

# Instrumentsテンプレートの定義
INSTRUMENTS_TEMPLATES=(
    "Time Profiler"
    "Allocations"
    "Leaks"
    "Core Animation"
)

echo "🔍 実行予定のInstruments:"
for template in "${INSTRUMENTS_TEMPLATES[@]}"; do
    echo "   - $template"
done

echo ""
echo "⚠️  手動実行が必要な項目:"
echo "   1. Xcode → Product → Profile でInstrumentsを起動"
echo "   2. 以下のテンプレートを順番に実行:"

for i in "${!INSTRUMENTS_TEMPLATES[@]}"; do
    template="${INSTRUMENTS_TEMPLATES[$i]}"
    echo ""
    echo "   📊 テスト $((i+1)): $template"
    echo "   -----------------------------------"
    
    case "$template" in
        "Time Profiler")
            echo "   📋 測定対象:"
            echo "      - アプリ起動時間（冷間/温間）"
            echo "      - CPU使用率の分析"
            echo "      - 関数呼び出しのボトルネック特定"
            echo ""
            echo "   🎯 実行手順:"
            echo "      1. Time Profilerを選択"
            echo "      2. Record開始"
            echo "      3. アプリを完全終了→再起動"
            echo "      4. プロジェクト一覧→詳細画面への遷移"
            echo "      5. 30秒後にRecord停止"
            ;;
        "Allocations")
            echo "   📋 測定対象:"
            echo "      - メモリ使用量の推移"
            echo "      - オブジェクト生成・破棄パターン"
            echo "      - @StateObjectの生成状況"
            echo ""
            echo "   🎯 実行手順:"
            echo "      1. Allocationsを選択"
            echo "      2. Record開始"
            echo "      3. 複数画面を順次遷移（10回）"
            echo "      4. メモリ増加パターンを確認"
            echo "      5. Record停止"
            ;;
        "Leaks")
            echo "   📋 測定対象:"
            echo "      - メモリリークの検出"
            echo "      - Firebase リスナーの適切な解放"
            echo "      - Manager の循環参照"
            echo ""
            echo "   🎯 実行手順:"
            echo "      1. Leaksを選択"
            echo "      2. Record開始"
            echo "      3. 画面遷移を繰り返し実行"
            echo "      4. リーク検出の確認"
            echo "      5. Record停止"
            ;;
        "Core Animation")
            echo "   📋 測定対象:"
            echo "      - FPS（フレームレート）"
            echo "      - 画面遷移の滑らかさ"
            echo "      - リスト スクロール性能"
            echo ""
            echo "   🎯 実行手順:"
            echo "      1. Core Animationを選択"
            echo "      2. Record開始"
            echo "      3. タブ切り替え、リストスクロール"
            echo "      4. アニメーション動作確認"
            echo "      5. Record停止"
            ;;
    esac
    
    echo "   💾 保存先: $RESULTS_DIR/$TIMESTAMP/${template// /_}.trace"
    echo ""
done

# 4. 測定チェックリストの作成
cat > "$RESULTS_DIR/$TIMESTAMP/test_checklist.md" << EOF
# パフォーマンステスト チェックリスト

## 測定日時
- 実行日: $(date '+%Y年%m月%d日 %H:%M:%S')
- デバイス: $DEVICE_ID
- Build: Release

## 測定項目チェックリスト

### ✅ Time Profiler
- [ ] 冷間起動時間: _____ 秒 (目標: <3秒)
- [ ] 温間起動時間: _____ 秒 (目標: <1秒)
- [ ] CPU使用率ピーク: ____% 
- [ ] 主要ボトルネック関数: ______________
- [ ] トレースファイル保存済み

### ✅ Allocations
- [ ] 起動時メモリ: _____ MB
- [ ] 通常使用時メモリ: _____ MB (目標: <150MB)
- [ ] ピーク メモリ: _____ MB (目標: <250MB)  
- [ ] @StateObject数: _____ 個
- [ ] トレースファイル保存済み

### ✅ Leaks
- [ ] メモリリーク検出: あり / なし
- [ ] リーク箇所: ______________
- [ ] Firebase リスナー解放: 正常 / 問題あり
- [ ] トレースファイル保存済み

### ✅ Core Animation  
- [ ] 平均FPS: _____ fps (目標: >55fps)
- [ ] 画面遷移時間: _____ 秒 (目標: <0.5秒)
- [ ] スクロール性能: 良好 / 問題あり
- [ ] トレースファイル保存済み

## 🔍 発見された主要問題

### 優先度 高
1. ________________________________
2. ________________________________  
3. ________________________________

### 優先度 中
1. ________________________________
2. ________________________________

### 優先度 低  
1. ________________________________
2. ________________________________

## 📊 測定結果サマリー

| 項目 | 目標値 | 実測値 | 判定 |
|------|--------|--------|------|
| 冷間起動 | <3秒 | ___秒 | 🟢/🟡/🔴 |
| 通常メモリ | <150MB | ___MB | 🟢/🟡/🔴 |
| ピークメモリ | <250MB | ___MB | 🟢/🟡/🔴 |
| 平均FPS | >55fps | ___fps | 🟢/🟡/🔴 |
| 画面遷移 | <0.5秒 | ___秒 | 🟢/🟡/🔴 |

## 📋 次のアクション
- [ ] Phase 2改善計画の作成
- [ ] 優先度付き修正リストの作成  
- [ ] Firebase接続最適化の検討
- [ ] @StateObject管理方法の改善案作成
EOF

echo "📋 測定チェックリスト作成完了:"
echo "   $RESULTS_DIR/$TIMESTAMP/test_checklist.md"
echo ""

# 5. OSLogの確認方法を表示
echo "📝 OSLog確認方法:"
echo "   Console.app で以下のフィルターを使用:"
echo "   subsystem:com.company.shigodeki"
echo ""

# 6. 自動化可能な基本測定の実行
echo "🤖 基本測定の実行..."

# シミュレータの状態確認
BOOT_STATE=$(xcrun simctl list devices | grep "$DEVICE_ID" | head -1)
echo "   シミュレータ状態: $BOOT_STATE"

# ディスク容量確認
DISK_USAGE=$(df -h . | tail -1 | awk '{print $4}')
echo "   利用可能容量: $DISK_USAGE"

# プロセス情報の記録
ps aux | grep -i xcode > "$RESULTS_DIR/$TIMESTAMP/system_info.txt"
echo "   システム情報を記録: system_info.txt"

echo ""
echo "✅ パフォーマンステスト準備完了!"
echo ""
echo "📱 次の手順:"
echo "   1. Xcode → Product → Profile"
echo "   2. 上記のチェックリストに従って測定実行"
echo "   3. 結果を $RESULTS_DIR/$TIMESTAMP/ に保存"
echo "   4. test_checklist.md を記入"
echo ""
echo "🎯 Phase 1完了後は Phase 2 修正フェーズに移行します"