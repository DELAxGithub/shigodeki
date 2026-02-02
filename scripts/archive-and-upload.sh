#!/bin/bash

# Shigodeki TestFlight Build Script
# アーカイブ作成とIPAエクスポートを行うスクリプト
#
# 使用方法:
#   ./scripts/archive-and-upload.sh [archive|export|all]
#
# 事前準備:
#   1. Apple Developer アカウントでXcodeにサインイン済み
#   2. App Store Connectでアプリが登録済み
#   3. プロビジョニングプロファイルが設定済み

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IOS_DIR="$PROJECT_ROOT/iOS"

# 設定
SCHEME="shigodeki"
CONFIGURATION="Release"
ARCHIVE_PATH="$PROJECT_ROOT/build/Shigodeki.xcarchive"
EXPORT_PATH="$PROJECT_ROOT/build/export"
EXPORT_OPTIONS_PLIST="$SCRIPT_DIR/ExportOptions.plist"

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 使用方法を表示
usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  archive     - アーカイブを作成"
    echo "  export      - IPAをエクスポート（アーカイブ必須）"
    echo "  all         - アーカイブ作成とIPAエクスポートを実行"
    echo "  clean       - ビルド成果物をクリーンアップ"
    echo "  version     - 現在のバージョン情報を表示"
    echo ""
    echo "Examples:"
    echo "  $0 all              # アーカイブ作成 → IPAエクスポート"
    echo "  $0 archive          # アーカイブのみ作成"
    echo "  $0 export           # 既存アーカイブからIPAエクスポート"
    echo ""
    echo "TestFlightへのアップロード:"
    echo "  1. Xcodeを開く: open $ARCHIVE_PATH"
    echo "  2. Organizer → Distribute App → App Store Connect"
    echo "  または"
    echo "  xcrun altool --upload-app -f $EXPORT_PATH/shigodeki.ipa -t ios -u YOUR_APPLE_ID"
}

# バージョン情報を表示
show_version() {
    log_info "プロジェクト情報を取得中..."
    cd "$IOS_DIR"

    MARKETING_VERSION=$(xcodebuild -showBuildSettings -scheme "$SCHEME" -configuration "$CONFIGURATION" 2>/dev/null | grep "MARKETING_VERSION" | head -1 | awk '{print $3}')
    BUILD_NUMBER=$(xcodebuild -showBuildSettings -scheme "$SCHEME" -configuration "$CONFIGURATION" 2>/dev/null | grep "CURRENT_PROJECT_VERSION" | head -1 | awk '{print $3}')
    BUNDLE_ID=$(xcodebuild -showBuildSettings -scheme "$SCHEME" -configuration "$CONFIGURATION" 2>/dev/null | grep "PRODUCT_BUNDLE_IDENTIFIER" | head -1 | awk '{print $3}')

    echo ""
    echo "====================================="
    echo "  Shigodeki Build Information"
    echo "====================================="
    echo "  Version:    $MARKETING_VERSION"
    echo "  Build:      $BUILD_NUMBER"
    echo "  Bundle ID:  $BUNDLE_ID"
    echo "  Scheme:     $SCHEME"
    echo "  Config:     $CONFIGURATION"
    echo "====================================="
    echo ""
}

# アーカイブを作成
archive() {
    log_info "アーカイブを作成中..."
    cd "$IOS_DIR"

    # ビルドディレクトリを作成
    mkdir -p "$PROJECT_ROOT/build"

    # 既存のアーカイブを削除
    if [ -d "$ARCHIVE_PATH" ]; then
        log_warning "既存のアーカイブを削除: $ARCHIVE_PATH"
        rm -rf "$ARCHIVE_PATH"
    fi

    log_info "xcodebuild archive を実行中..."
    log_info "これには数分かかる場合があります..."

    # xcprettyがあれば使用、なければそのまま出力
    if command -v xcpretty &> /dev/null; then
        xcodebuild archive \
            -scheme "$SCHEME" \
            -configuration "$CONFIGURATION" \
            -archivePath "$ARCHIVE_PATH" \
            -destination 'generic/platform=iOS' \
            -allowProvisioningUpdates \
            CODE_SIGN_STYLE=Automatic \
            | xcpretty
        BUILD_RESULT=${PIPESTATUS[0]}
    else
        xcodebuild archive \
            -scheme "$SCHEME" \
            -configuration "$CONFIGURATION" \
            -archivePath "$ARCHIVE_PATH" \
            -destination 'generic/platform=iOS' \
            -allowProvisioningUpdates \
            CODE_SIGN_STYLE=Automatic
        BUILD_RESULT=$?
    fi

    if [ $BUILD_RESULT -ne 0 ]; then
        log_error "アーカイブの作成に失敗しました"
        exit 1
    fi

    log_success "アーカイブ作成完了: $ARCHIVE_PATH"
    echo ""
    log_info "次のステップ:"
    echo "  1. Xcodeでアーカイブを開く: open \"$ARCHIVE_PATH\""
    echo "  2. Organizer → Distribute App → App Store Connect"
    echo "  または"
    echo "  ./scripts/archive-and-upload.sh export"
}

# IPAをエクスポート
export_ipa() {
    log_info "IPAをエクスポート中..."

    # アーカイブの存在確認
    if [ ! -d "$ARCHIVE_PATH" ]; then
        log_error "アーカイブが見つかりません: $ARCHIVE_PATH"
        log_info "まず 'archive' コマンドを実行してください"
        exit 1
    fi

    # ExportOptions.plistの存在確認
    if [ ! -f "$EXPORT_OPTIONS_PLIST" ]; then
        log_error "ExportOptions.plistが見つかりません: $EXPORT_OPTIONS_PLIST"
        log_info "scripts/ExportOptions.plist を作成してください"
        exit 1
    fi

    # エクスポートディレクトリをクリーンアップ
    if [ -d "$EXPORT_PATH" ]; then
        log_warning "既存のエクスポートを削除: $EXPORT_PATH"
        rm -rf "$EXPORT_PATH"
    fi
    mkdir -p "$EXPORT_PATH"

    log_info "xcodebuild -exportArchive を実行中..."

    if command -v xcpretty &> /dev/null; then
        xcodebuild -exportArchive \
            -archivePath "$ARCHIVE_PATH" \
            -exportPath "$EXPORT_PATH" \
            -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
            | xcpretty
        EXPORT_RESULT=${PIPESTATUS[0]}
    else
        xcodebuild -exportArchive \
            -archivePath "$ARCHIVE_PATH" \
            -exportPath "$EXPORT_PATH" \
            -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
        EXPORT_RESULT=$?
    fi

    if [ $EXPORT_RESULT -ne 0 ]; then
        log_error "IPAエクスポートに失敗しました"
        exit 1
    fi

    log_success "IPAエクスポート完了: $EXPORT_PATH"
    echo ""
    log_info "IPAファイル一覧:"
    ls -la "$EXPORT_PATH"/*.ipa 2>/dev/null || echo "  (IPAファイルなし)"
    echo ""
    log_info "TestFlightへのアップロード:"
    echo "  xcrun altool --upload-app -f \"$EXPORT_PATH/shigodeki.ipa\" -t ios -u YOUR_APPLE_ID"
    echo "  または Transporter.app を使用"
}

# クリーンアップ
clean() {
    log_info "ビルド成果物をクリーンアップ中..."

    if [ -d "$PROJECT_ROOT/build" ]; then
        rm -rf "$PROJECT_ROOT/build"
        log_success "build/ ディレクトリを削除しました"
    else
        log_info "クリーンアップするものがありません"
    fi
}

# メイン処理
case "${1:-}" in
    archive)
        show_version
        archive
        ;;
    export)
        export_ipa
        ;;
    all)
        show_version
        archive
        export_ipa
        ;;
    clean)
        clean
        ;;
    version)
        show_version
        ;;
    *)
        usage
        exit 1
        ;;
esac
