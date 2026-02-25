#!/bin/bash
set -euo pipefail

# Eastsea Node — macOS .app 번들 + DMG 생성
# 결과물: dist/Eastsea Node.dmg

APP_NAME="Eastsea Node"
BUNDLE_ID="com.eastsea.node"
VERSION="${1:-0.1.0}"
ZIG="${ZIG_PATH:-/opt/homebrew/opt/zig@0.14/bin/zig}"

DIST_DIR="dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_NAME="$DIST_DIR/EastseaNode-v$VERSION.dmg"

echo "🌊 Eastsea Node DMG 생성 v$VERSION"
echo "================================"

# 1. 빌드
echo "🔨 1/5 빌드..."
"$ZIG" build

# 2. .app 번들 구조 생성
echo "📦 2/5 .app 번들 생성..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 바이너리 복사
cp zig-out/bin/eastsea-production "$APP_DIR/Contents/MacOS/eastsea-production"
chmod +x "$APP_DIR/Contents/MacOS/eastsea-production"

# 래퍼 스크립트: 앱 실행 시 바이너리 시작 + 브라우저 열기
cat > "$APP_DIR/Contents/MacOS/$APP_NAME" << 'LAUNCHER'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/eastsea-production" &
NODE_PID=$!
sleep 2
open "http://127.0.0.1:8545"
wait $NODE_PID
LAUNCHER
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# Info.plist
cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
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
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSBackgroundOnly</key>
    <false/>
</dict>
</plist>
PLIST

# 3. 아이콘 (텍스트 기반 임시 아이콘)
echo "🎨 3/5 아이콘 생성..."
# sips로 간단한 아이콘 생성 (없으면 건너뜀)
if command -v sips >/dev/null 2>&1; then
    # 임시 PNG 생성 (128x128 파란색 사각형 + 텍스트)
    python3 -c "
import struct, zlib
def create_png(w, h, color):
    def raw():
        for y in range(h):
            yield b'\x00'
            for x in range(w):
                cx, cy = abs(x - w//2), abs(y - h//2)
                if cx < w//3 and cy < h//3:
                    yield bytes(color)
                else:
                    yield bytes([10, 14, 26, 255])
    raw_data = b''.join(raw())
    def chunk(ct, data):
        c = ct + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    ihdr = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) + chunk(b'IDAT', zlib.compress(raw_data)) + chunk(b'IEND', b'')
with open('$DIST_DIR/icon.png', 'wb') as f:
    f.write(create_png(128, 128, [59, 130, 246, 255]))
" 2>/dev/null && {
        mkdir -p "$DIST_DIR/AppIcon.iconset"
        sips -z 128 128 "$DIST_DIR/icon.png" --out "$DIST_DIR/AppIcon.iconset/icon_128x128.png" 2>/dev/null
        sips -z 256 256 "$DIST_DIR/icon.png" --out "$DIST_DIR/AppIcon.iconset/icon_128x128@2x.png" 2>/dev/null
        iconutil -c icns "$DIST_DIR/AppIcon.iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns" 2>/dev/null || true
        rm -rf "$DIST_DIR/AppIcon.iconset" "$DIST_DIR/icon.png"
    } || echo "   (아이콘 생성 건너뜀)"
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
