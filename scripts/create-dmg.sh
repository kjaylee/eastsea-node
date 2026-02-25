#!/bin/bash
set -euo pipefail

# Eastsea Node — macOS .app 번들 + DMG 생성
# 결과물: dist/Eastsea Node.dmg

APP_NAME="Eastsea Node"
APP_EXECUTABLE="eastsea-launcher"
BUNDLE_ID="com.eastsea.node"
VERSION="${1:-0.1.0}"
CUSTOM_BINARY_PATH="${EASTSEA_BINARY_PATH:-}"
ZIG="${ZIG_PATH:-/opt/homebrew/opt/zig@0.14/bin/zig}"

DIST_DIR="dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_NAME="${EASTSEA_DMG_PATH:-$DIST_DIR/EastseaNode-v$VERSION.dmg}"

echo "🌊 Eastsea Node DMG 생성 v$VERSION"
echo "================================"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. 빌드 또는 전달된 바이너리 사용
if [ -n "$CUSTOM_BINARY_PATH" ]; then
    echo "📦 1/5 전달된 바이너리 사용: $CUSTOM_BINARY_PATH"
    if [ ! -x "$CUSTOM_BINARY_PATH" ]; then
        echo "❌ 실행 가능한 바이너리를 찾을 수 없습니다: $CUSTOM_BINARY_PATH"
        exit 1
    fi
else
    echo "🔨 1/5 빌드..."
    "$ZIG" build
fi

# 2. .app 번들 구조 생성
echo "📦 2/5 .app 번들 생성..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 바이너리 복사
if [ -n "$CUSTOM_BINARY_PATH" ]; then
    cp "$CUSTOM_BINARY_PATH" "$APP_DIR/Contents/MacOS/eastsea-production"
else
    cp zig-out/bin/eastsea-production "$APP_DIR/Contents/MacOS/eastsea-production"
fi
chmod +x "$APP_DIR/Contents/MacOS/eastsea-production"

# 2b. 상태바 런처: Swift 컴파일이 가능하면 상태바 앱으로 생성, 실패 시 bash 런처 fallback
echo "🧩 2b/5 상태바 런처 준비..."
STATUSBAR_BINARY="$APP_DIR/Contents/MacOS/$APP_EXECUTABLE"
if command -v swiftc >/dev/null 2>&1; then
    X86_BIN="${STATUSBAR_BINARY}.x86_64"
    ARM_BIN="${STATUSBAR_BINARY}.arm64"
    STATUSBAR_SRC="$SCRIPT_DIR/macos_statusbar.swift"
    if swiftc -parse-as-library -target x86_64-apple-macos12 -O -framework Cocoa -o "$X86_BIN" "$STATUSBAR_SRC" \
       && swiftc -parse-as-library -target arm64-apple-macos12 -O -framework Cocoa -o "$ARM_BIN" "$STATUSBAR_SRC" \
       && lipo -create "$X86_BIN" "$ARM_BIN" -output "$STATUSBAR_BINARY"; then
        rm -f "$X86_BIN" "$ARM_BIN"
    else
        rm -f "$X86_BIN" "$ARM_BIN"
        echo "⚠️  swiftc 컴파일 실패 — bash 런처 사용"
        cat > "$STATUSBAR_BINARY" << 'LAUNCHER'
#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_BIN="$DIR/eastsea-production"
LOG_DIR="$HOME/Library/Logs/com.eastsea.node"
LOG_FILE="$LOG_DIR/launcher.log"

if [ ! -x "$CORE_BIN" ]; then
    mkdir -p "$LOG_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [launcher] binary-not-found: $CORE_BIN" >> "$LOG_FILE"
    echo "Eastsea Node 실행 파일을 찾을 수 없습니다: $CORE_BIN" >&2
    exit 1
fi

mkdir -p "$LOG_DIR"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] starting $(basename "$CORE_BIN")" >> "$LOG_FILE"

(sleep 1; open "http://127.0.0.1:8545") &
exec "$CORE_BIN" "$@"
LAUNCHER
    fi
else
    echo "⚠️  swiftc 미설치 — bash 런처 사용"
    cat > "$STATUSBAR_BINARY" << 'LAUNCHER'
#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_BIN="$DIR/eastsea-production"
LOG_DIR="$HOME/Library/Logs/com.eastsea.node"
LOG_FILE="$LOG_DIR/launcher.log"

if [ ! -x "$CORE_BIN" ]; then
    mkdir -p "$LOG_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [launcher] binary-not-found: $CORE_BIN" >> "$LOG_FILE"
    echo "Eastsea Node 실행 파일을 찾을 수 없습니다: $CORE_BIN" >&2
    exit 1
fi

mkdir -p "$LOG_DIR"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] starting $(basename "$CORE_BIN")" >> "$LOG_FILE"

(sleep 1; open "http://127.0.0.1:8545") &
exec "$CORE_BIN" "$@"
LAUNCHER
fi
chmod +x "$STATUSBAR_BINARY"

# Info.plist
cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_EXECUTABLE</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# 3. 아이콘 생성 (고품질 그라디언트 + 노드 네트워크 심벌)
echo "🎨 3/5 아이콘 생성..."
if command -v python3 >/dev/null 2>&1 && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
    PYTHON_ICON_OK=false
    if python3 "$SCRIPT_DIR/generate-app-icon.py" "$DIST_DIR/icon-source.png" 2>/dev/null; then
        rm -rf "$DIST_DIR/AppIcon.iconset"
        mkdir -p "$DIST_DIR/AppIcon.iconset"
        for size in 16 32 64 128 256 512; do
            out="$DIST_DIR/AppIcon.iconset/icon_${size}x${size}.png"
            out2x="$DIST_DIR/AppIcon.iconset/icon_${size}x${size}@2x.png"
            if sips -z "$size" "$size" "$DIST_DIR/icon-source.png" --out "$out" >/dev/null 2>&1; then
                doubled=$((size * 2))
                sips -z "$doubled" "$doubled" "$DIST_DIR/icon-source.png" --out "$out2x" >/dev/null 2>&1
            fi
        done

        if iconutil -c icns "$DIST_DIR/AppIcon.iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns" 2>/dev/null; then
            PYTHON_ICON_OK=true
        fi
        rm -f "$DIST_DIR/icon-source.png"
    fi

    if [ "$PYTHON_ICON_OK" = true ]; then
        :
    else
        echo "   (아이콘 생성 일부 실패, 기본 스타일로 fallback)"
        rm -rf "$DIST_DIR/AppIcon.iconset"
        mkdir -p "$DIST_DIR/AppIcon.iconset"
        # fallback icon should be exactly 128 and 256 only for compatibility
        rm -f "$DIST_DIR/AppIcon.iconset"/*
        python3 - << 'PY'
import struct, zlib

def create_png(w, h):
    w32 = w
    row_len = 1 + w32 * 4
    raw = bytearray()
    for y in range(h):
        raw.extend(b"\x00")
        for x in range(w):
            if abs(x - w // 2) < w // 3 and abs(y - h // 2) < h // 4:
                raw.extend(bytes([59, 130, 246, 255]))
            else:
                raw.extend(bytes([10, 14, 26, 255]))
    def chunk(t, d):
        c = t + d
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", w32, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(bytes(raw)))
    png += chunk(b"IEND", b"")
    with open("dist/icon.png", "wb") as f:
        f.write(png)
PY
        sips -z 128 128 "dist/icon.png" --out "$DIST_DIR/AppIcon.iconset/icon_128x128.png" >/dev/null 2>&1
        sips -z 256 256 "dist/icon.png" --out "$DIST_DIR/AppIcon.iconset/icon_128x128@2x.png" >/dev/null 2>&1
        iconutil -c icns "$DIST_DIR/AppIcon.iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns" >/dev/null 2>&1 || true
        rm -f "dist/icon.png"
    fi
else
    echo "   (필수 툴 미설치: 아이콘 생성 건너뜀)"
fi

# 4. DMG 생성
echo "💿 4/5 DMG 생성..."
rm -f "$DMG_NAME"

if command -v create-dmg >/dev/null 2>&1; then
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon "$APP_NAME.app" 150 200 \
        --app-drop-link 450 200 \
        "$DMG_NAME" \
        "$APP_DIR" 2>/dev/null
else
    # create-dmg 없으면 hdiutil 직접 사용
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$APP_DIR" \
        -ov -format UDBZ \
        "$DMG_NAME" 2>/dev/null
fi

# 5. 결과
echo "✅ 5/5 완료!"
echo "================================"
echo "📦 .app: $APP_DIR"
echo "💿 .dmg: $DMG_NAME"
ls -lh "$DMG_NAME"
echo ""
echo "설치: DMG 더블클릭 → Applications 폴더로 드래그"
echo "실행: Launchpad에서 '$APP_NAME' 클릭"
echo "================================"
