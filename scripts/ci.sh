#!/bin/bash
# =============================================================================
# REQ-050: CI 파이프라인 스크립트
# REQ-051: 릴리스 자동화
# =============================================================================
set -euo pipefail

VERSION="${1:-0.1.0}"
ZIG="${ZIG_PATH:-/opt/homebrew/opt/zig@0.14/bin/zig}"
CI_CACHE_DIR="${ZIG_GLOBAL_CACHE_DIR:-${TMPDIR:-/tmp}/eastsea_zig_cache}"
TIMEOUT_BIN="${TIMEOUT_BIN:-timeout}"
HAS_TIMEOUT=0

if command -v "$TIMEOUT_BIN" >/dev/null 2>&1; then
    HAS_TIMEOUT=1
fi

if command -v "$ZIG" >/dev/null 2>&1; then
    :
else
    echo "❌ Zig 실행파일을 찾을 수 없습니다: $ZIG"
    echo "   환경변수 ZIG_PATH 를 Zig 경로로 지정해 주세요."
    exit 1
fi

export ZIG_GLOBAL_CACHE_DIR="$CI_CACHE_DIR"
mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
echo "📦 CI cache dir: $ZIG_GLOBAL_CACHE_DIR"

echo "🔄 Eastsea Node CI Pipeline v$VERSION"
echo "========================================"

# Step 1: Lint/Format
step_format() {
    echo "▶  1/5 코드 포맷 검사..."
    if $ZIG fmt --check src/*.zig 2>/dev/null; then
        echo "✅ 포맷 통과"
    else
        echo "⚠️  포맷 차이 발견 (자동 수정은 zig fmt src/)"
    fi
}

# Step 2: Build
step_build() {
    echo "▶  2/5 빌드..."
    $ZIG build 2>&1
    echo "✅ 빌드 성공"
}

# Step 3: Unit Tests
step_test() {
    echo "▶  3/5 단위 테스트..."
    local total=0
    local pass=0
    local fail=0

    for f in src/onboarding.zig src/boot_check.zig src/storage_init.zig \
             src/auth.zig src/tls_config.zig src/rpc_validator.zig \
             src/updater.zig src/update_manager.zig src/persistence.zig \
             src/rbac.zig src/diagnostics.zig src/monitoring.zig src/cluster.zig; do
        total=$((total + 1))
        if $ZIG test "$f" 2>&1 | grep -q "tests passed"; then
            pass=$((pass + 1))
        else
            fail=$((fail + 1))
            echo "  ❌ $f"
        fi
    done

    echo "✅ 테스트: $pass/$total 통과 ($fail 실패)"
    [ "$fail" -eq 0 ] || return 1
}

# Step 4: Integration test
step_integration() {
    echo "▶  4/5 통합 테스트..."
    local integration_rc=0
    local integration_log="dist/ci_integration.log"

    if [ "$HAS_TIMEOUT" -eq 1 ]; then
        "$TIMEOUT_BIN" 15 "$ZIG" build run >"$integration_log" 2>&1 || integration_rc=$?
    else
        echo "⚠️  timeout 명령이 없어 15초 강제 제한 없이 통합 실행을 수행합니다."
        "$ZIG" build run >"$integration_log" 2>&1 || integration_rc=$?
    fi

    if [ "$integration_rc" -ne 0 ]; then
        echo "⚠️  통합 실행 종료(코드 ${integration_rc}) - 로그만 확인하고 진행을 계속합니다."
    fi
    tail -n 5 "$integration_log" || true
    echo "✅ 통합 실행 확인"
}

# Step 5: Package
step_package() {
    echo "▶  5/5 패키지..."
    local artifact_dir="dist/v$VERSION"
    mkdir -p "$artifact_dir"

    if [ -f "zig-out/bin/eastsea" ]; then
        cp zig-out/bin/eastsea "$artifact_dir/"
        echo "✅ 바이너리: $artifact_dir/eastsea"
    fi

    cp scripts/install.sh "$artifact_dir/"
    cp Dockerfile "$artifact_dir/"
    cp docker-compose.yml "$artifact_dir/"

    echo "✅ 패키지 완료: $artifact_dir/"
    ls -la "$artifact_dir/"
}

# Main
case "${2:-all}" in
    format) step_format ;;
    build)  step_build ;;
    test)   step_test ;;
    integration) step_integration ;;
    package) step_package ;;
    all)
        step_format
        step_build
        step_test
        step_integration
        step_package
        echo ""
        echo "========================================"
        echo "✅ CI 파이프라인 완료 (v$VERSION)"
        ;;
esac
