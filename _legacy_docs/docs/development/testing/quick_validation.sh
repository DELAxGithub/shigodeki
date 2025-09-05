#!/bin/bash

# 📱 シゴデキアプリ クイック検証スクリプト
# 使用方法: ./quick_validation.sh
# 実行場所: /docs/development/testing/

echo "🚀 シゴデキアプリ クイック検証開始"
echo "=================================="

# iOSプロジェクトディレクトリに移動
cd "$(dirname "$0")/../../../iOS"

echo "📍 現在のディレクトリ: $(pwd)"

# 1. ビルド確認
echo ""
echo "🔨 Step 1: ビルド確認"
echo "-------------------"
if xcodebuild -scheme shigodeki -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6,arch=arm64' build -quiet; then
    echo "✅ ビルド成功"
else
    echo "❌ ビルド失敗"
    exit 1
fi

# 2. 静的解析（warnings確認）
echo ""
echo "⚠️  Step 2: 警告確認"
echo "-------------------"
warning_count=$(xcodebuild -scheme shigodeki -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6,arch=arm64' build 2>&1 | grep -c "warning:")
echo "警告数: $warning_count"

if [ $warning_count -gt 10 ]; then
    echo "⚠️  警告が多すぎます（$warning_count個）"
else
    echo "✅ 警告数は許容範囲内"
fi

# 3. 重要ファイルの存在確認
echo ""
echo "📁 Step 3: 重要ファイル確認"
echo "------------------------"
files_to_check=(
    "shigodeki/ContentView.swift"
    "shigodeki/ProjectListView.swift" 
    "shigodeki/AuthenticationManager.swift"
    "shigodeki/ProjectManager.swift"
    "shigodeki/Components/SharedManagerStore.swift"
)

for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file が見つかりません"
    fi
done

# 4. Firebase設定確認
echo ""
echo "🔥 Step 4: Firebase設定確認"
echo "--------------------------"
if [ -f "Firebase/Config/GoogleService-Info-Dev.plist" ]; then
    echo "✅ 開発用Firebase設定"
else
    echo "❌ 開発用Firebase設定が見つかりません"
fi

if [ -f "Firebase/Config/GoogleService-Info-Prod.plist" ]; then
    echo "✅ 本番用Firebase設定"  
else
    echo "❌ 本番用Firebase設定が見つかりません"
fi

# 5. シミュレータ起動準備
echo ""
echo "📱 Step 5: シミュレータ準備"
echo "-------------------------"
if xcrun simctl boot "iPhone 16" 2>/dev/null; then
    echo "✅ iPhone 16シミュレータ起動完了"
else
    echo "ℹ️  iPhone 16シミュレータは既に起動中"
fi

# 6. 手動テスト指示
echo ""
echo "🎯 次のステップ: 手動テスト実行"
echo "=============================="
echo ""
echo "Xcodeでアプリを起動して、以下を確認してください："
echo ""
echo "【クリティカル確認項目】"
echo "1. アプリが正常に起動する"
echo "2. 「+」ボタンでプロジェクト作成画面が開く"
echo "3. プロジェクト作成・保存が動作する"
echo "4. プロジェクト一覧に新しいプロジェクトが表示される"
echo "5. プロジェクトタップで詳細画面に遷移する"
echo ""
echo "【詳細チェック】"
echo "- manual-checklist.md を参照"
echo ""
echo "問題を発見した場合は、以下の情報を記録してください："
echo "- 再現手順"
echo "- 期待値と実際の結果"
echo "- デバイス・OSバージョン"
echo "- コンソールのエラーメッセージ"
echo ""
echo "🏁 検証完了後、結果をmanual-checklist.mdに記録してください"

# 7. 検証結果テンプレート作成
echo ""
echo "📝 検証結果記録用ファイルを作成中..."
current_date=$(date +"%Y-%m-%d_%H-%M")
result_file="validation_results_${current_date}.log"

cat > "$result_file" << EOL
# シゴデキアプリ検証結果
検証日時: $(date)
検証者: [名前を記入]
アプリバージョン: [バージョンを記入]
iOS バージョン: [バージョンを記入] 
デバイス: iPhone 16 Simulator

## ビルド結果
- ビルド: ✅ 成功
- 警告数: $warning_count

## 基本機能確認
- [ ] アプリ起動
- [ ] プロジェクト作成
- [ ] プロジェクト一覧表示
- [ ] プロジェクト詳細遷移
- [ ] 認証フロー

## 発見した問題
[問題があれば記入]

## 総合評価
- [ ] 本番リリース可能
- [ ] 軽微な修正が必要
- [ ] 重大な問題あり

EOL

echo "✅ 検証結果記録ファイル作成: $result_file"
echo ""
echo "🚀 手動検証を開始してください！"