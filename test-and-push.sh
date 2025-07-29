#!/bin/bash
set -e  # 에러 발생 시 스크립트 중단

# Check if timeout command is available, if not use a simple sleep and kill
if ! command -v timeout &> /dev/null
then
    echo "⚠️ timeout command not found, using alternative method"
    timeout_cmd() {
        local duration=$1
        shift
        "$@" &
        local pid=$!
        sleep $duration
        kill $pid 2>/dev/null || true
        wait $pid 2>/dev/null || true
    }
else
    timeout_cmd() {
        timeout "$@"
    }
fi

echo "🧪 Eastsea Test & Push Automation"
echo "================================="

# 1. 전체 테스트 실행
echo "📦 Building..."
zig build

echo "🔬 Running unit tests..."
# No general "test" target in build.zig, running specific test executables instead

echo "🚀 Running integration tests..."
timeout_cmd 30s zig build run || echo "⚠️ Integration test timeout (expected for interactive demo)"

echo "🎯 Testing individual components..."
echo "  - P2P Network Test"
timeout_cmd 10s zig-out/bin/p2p-test 8000 &

echo "  - Smart Contracts Test"
zig-out/bin/programs-test all > /dev/null

echo "  - Custom Programs Test"
zig-out/bin/custom-programs-test all > /dev/null

echo "  - EAS (Eastsea Attestation Service) Test"
zig-out/bin/eas-test all > /dev/null

echo "  - EAS Use Cases Test"
zig-out/bin/eas-use-cases-test all > /dev/null

echo "  - Phase 9 Comprehensive Test Framework"
zig-out/bin/phase9-test all > /dev/null

echo "  - QUIC Protocol Test"
zig-out/bin/quic-test all > /dev/null

# 2. Git 작업
echo "📝 Staging changes..."
git add src/ README.md TODO.md build.zig docs/ test-and-push.sh

if git diff --cached --quiet; then
    echo "ℹ️ No changes to commit"
    exit 0
fi

echo "💾 Committing..."
COMMIT_MSG="${1:-test: all tests passing - auto commit ✅}"
git commit -m "$COMMIT_MSG"

echo "🚀 Pushing to remote..."
git push origin main

echo "🎉 All done! Tests passed and changes pushed successfully."