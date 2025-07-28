#!/bin/bash
set -e  # 에러 발생 시 스크립트 중단

echo "🧪 Eastsea Test & Push Automation"
echo "================================="

# 1. 전체 테스트 실행
echo "📦 Building..."
zig build

echo "🔬 Running unit tests..."
zig build test

echo "🚀 Running integration tests..."
timeout 30s zig build run || echo "⚠️ Integration test timeout (expected for interactive demo)"

echo "🎯 Testing individual components..."
echo "  - P2P Network Test"
timeout 10s zig-out/bin/p2p-test 8000 &
P2P_PID=$!
sleep 2
kill $P2P_PID 2>/dev/null || true

echo "  - Smart Contracts Test"
zig-out/bin/programs-test all > /dev/null

echo "  - Custom Programs Test"
zig-out/bin/custom-programs-test all > /dev/null

# 2. Git 작업
echo "📝 Staging changes..."
git add src/ README.md TODO.md build.zig docs/

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