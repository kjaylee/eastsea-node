#!/bin/bash
set -euo pipefail

# Eastsea Node — macOS 설치/제거 스크립트
# 사용법:
#   bash scripts/install-macos.sh install   — 설치
#   bash scripts/install-macos.sh uninstall — 제거
#   bash scripts/install-macos.sh status    — 상태 확인

APP_NAME="eastsea-production"
INSTALL_DIR="/usr/local/bin"
PLIST_NAME="com.eastsea.node"
PLIST_SRC="scripts/com.eastsea.node.plist"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
PLIST_DEST="$LAUNCH_DIR/$PLIST_NAME.plist"
DATA_DIR="$HOME/.eastsea"

ZIG="${ZIG_PATH:-/opt/homebrew/opt/zig@0.14/bin/zig}"

ensure_built() {
    if [ ! -f "zig-out/bin/$APP_NAME" ]; then
        echo "🔨 빌드 중..."
        "$ZIG" build
    fi
}

do_install() {
    echo "🌊 Eastsea Node 설치"
    echo "================================"

    ensure_built

    # 바이너리 복사
    echo "📦 바이너리 설치 → $INSTALL_DIR/$APP_NAME"
    sudo cp "zig-out/bin/$APP_NAME" "$INSTALL_DIR/$APP_NAME"
    sudo chmod +x "$INSTALL_DIR/$APP_NAME"

    # 데이터 디렉토리
    mkdir -p "$DATA_DIR"
    echo "📁 데이터 디렉토리: $DATA_DIR"

    # LaunchAgent 설치
    mkdir -p "$LAUNCH_DIR"
    sed "s|/Users/CURRENT_USER|$HOME|g" "$PLIST_SRC" > "$PLIST_DEST"
    echo "⚙️  LaunchAgent 설치: $PLIST_DEST"

    # LaunchAgent 로드
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    launchctl load "$PLIST_DEST"
    echo "✅ Eastsea Node 시작됨 (자동 시작 활성화)"

    echo ""
    echo "🌐 대시보드: http://127.0.0.1:8545"
    echo "📋 로그: tail -f /tmp/eastsea-node.log"
    echo "🛑 중지: launchctl unload $PLIST_DEST"
    echo "================================"
}

do_uninstall() {
    echo "🗑️  Eastsea Node 제거"
    echo "================================"

    # LaunchAgent 언로드
    if [ -f "$PLIST_DEST" ]; then
        launchctl unload "$PLIST_DEST" 2>/dev/null || true
        rm -f "$PLIST_DEST"
        echo "⚙️  LaunchAgent 제거됨"
    fi

    # 바이너리 제거
    if [ -f "$INSTALL_DIR/$APP_NAME" ]; then
        sudo rm -f "$INSTALL_DIR/$APP_NAME"
        echo "📦 바이너리 제거됨"
    fi

    echo ""
    read -p "데이터($DATA_DIR)도 삭제할까요? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$DATA_DIR"
        echo "📁 데이터 삭제됨"
    fi

    echo "✅ 제거 완료"
    echo "================================"
}

do_status() {
    echo "📊 Eastsea Node 상태"
    echo "================================"

    if pgrep -x "$APP_NAME" > /dev/null 2>&1; then
        echo "🟢 실행 중 (PID: $(pgrep -x $APP_NAME))"
    else
        echo "🔴 중지됨"
    fi

    if [ -f "$PLIST_DEST" ]; then
        echo "⚙️  LaunchAgent: 설치됨"
    else
        echo "⚙️  LaunchAgent: 미설치"
    fi

    if [ -d "$DATA_DIR" ]; then
        local size=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1)
        echo "📁 데이터: $DATA_DIR ($size)"
    fi

    if [ -f "$INSTALL_DIR/$APP_NAME" ]; then
        echo "📦 바이너리: $INSTALL_DIR/$APP_NAME"
    fi

    echo "================================"
}

case "${1:-help}" in
    install)   do_install ;;
    uninstall) do_uninstall ;;
    status)    do_status ;;
    *)
        echo "사용법: $0 {install|uninstall|status}"
        exit 1
        ;;
esac
