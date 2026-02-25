#!/bin/bash
# =============================================================================
# Eastsea Node - CLI 설치 스크립트
# REQ-103: Linux CLI 자동 설치 스크립트
# =============================================================================
set -euo pipefail

VERSION="${EASTSEA_VERSION:-0.1.0}"
INSTALL_DIR="${EASTSEA_INSTALL_DIR:-/usr/local/bin}"
DATA_DIR="${EASTSEA_DATA_DIR:-$HOME/.eastsea}"
CONFIG_FILE="$DATA_DIR/config.json"
SERVICE_NAME="eastsea-node"

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# === 유틸리티 함수 ===

log_info()  { echo -e "${GREEN}✅${NC} $1"; }
log_warn()  { echo -e "${YELLOW}⚠️${NC}  $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }
log_step()  { echo -e "${BLUE}▶${NC}  $1"; }

# === OS 탐지 (UT-103-01 대응) ===

detect_os() {
    local os=""
    local arch=""

    # OS 탐지
    case "$(uname -s)" in
        Linux*)   os="linux" ;;
        Darwin*)  os="macos" ;;
        MINGW*|MSYS*|CYGWIN*) os="windows" ;;
        *)        os="unknown" ;;
    esac

    # 아키텍처 탐지
    case "$(uname -m)" in
        x86_64|amd64)   arch="x86_64" ;;
        aarch64|arm64)  arch="aarch64" ;;
        armv7l)         arch="armv7" ;;
        *)              arch="unknown" ;;
    esac

    echo "$os $arch"
}

# === 권한 확인 ===

check_privileges() {
    if [ "$(id -u)" -eq 0 ]; then
        log_info "root 권한으로 실행 중"
        return 0
    fi

    if [ -w "$INSTALL_DIR" ]; then
        log_info "설치 경로 쓰기 권한 확인: $INSTALL_DIR"
        return 0
    fi

    log_warn "설치 경로($INSTALL_DIR)에 쓰기 권한이 없습니다."
    echo "  다음 중 하나를 선택하세요:"
    echo "  1. sudo로 재실행: sudo $0 $*"
    echo "  2. 사용자 경로 지정: EASTSEA_INSTALL_DIR=\$HOME/.local/bin $0"
    return 1
}

# === 포트 확인 ===

check_port() {
    local port=$1
    if command -v ss &>/dev/null; then
        if ss -tlnp 2>/dev/null | grep -q ":$port "; then
            return 1  # 포트 사용 중
        fi
    elif command -v netstat &>/dev/null; then
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            return 1
        fi
    fi
    return 0  # 포트 사용 가능
}

find_available_port() {
    local base_port=$1
    local port=$base_port
    local max_attempts=10

    for i in $(seq 0 $((max_attempts - 1))); do
        port=$((base_port + i))
        if check_port "$port"; then
            echo "$port"
            return 0
        fi
    done

    echo "$base_port"
    return 1
}

# === 데이터 디렉토리 설정 ===

setup_data_dir() {
    if [ ! -d "$DATA_DIR" ]; then
        mkdir -p "$DATA_DIR"
        log_info "데이터 디렉토리 생성: $DATA_DIR"
    else
        log_info "데이터 디렉토리 확인: $DATA_DIR"
    fi
}

# === 기본 설정 생성 ===

create_default_config() {
    if [ -f "$CONFIG_FILE" ]; then
        log_info "기존 설정 파일 유지: $CONFIG_FILE"
        return 0
    fi

    local node_port
    local rpc_port
    node_port=$(find_available_port 8000)
    rpc_port=$(find_available_port 8545)

    cat > "$CONFIG_FILE" <<EOF
{
  "node_address": "127.0.0.1",
  "node_port": $node_port,
  "rpc_port": $rpc_port,
  "data_dir": "$DATA_DIR",
  "is_validator": true,
  "max_peers": 50,
  "log_level": "info"
}
EOF

    log_info "기본 설정 생성: $CONFIG_FILE"
    log_info "  node_port=$node_port, rpc_port=$rpc_port"
}

# === 바이너리 설치 (빌드 또는 다운로드) ===

install_binary() {
    local os_info
    os_info=$(detect_os)
    local os=$(echo "$os_info" | cut -d' ' -f1)
    local arch=$(echo "$os_info" | cut -d' ' -f2)

    log_step "OS: $os, Arch: $arch"

    # 현재 소스에서 빌드하는 방식 (Zig 빌드)
    if command -v zig &>/dev/null; then
        log_step "Zig 컴파일러 발견, 소스에서 빌드..."

        local script_dir
        script_dir="$(cd "$(dirname "$0")/.." && pwd)"

        if [ -f "$script_dir/build.zig" ]; then
            (cd "$script_dir" && zig build -Doptimize=ReleaseSafe 2>&1)
            
            if [ -f "$script_dir/zig-out/bin/eastsea" ]; then
                cp "$script_dir/zig-out/bin/eastsea" "$INSTALL_DIR/eastsea"
                chmod +x "$INSTALL_DIR/eastsea"
                log_info "바이너리 설치: $INSTALL_DIR/eastsea"
                return 0
            fi
        fi
    fi

    # Zig가 없으면 미리 빌드된 바이너리 확인
    if [ -f "./zig-out/bin/eastsea" ]; then
        cp "./zig-out/bin/eastsea" "$INSTALL_DIR/eastsea"
        chmod +x "$INSTALL_DIR/eastsea"
        log_info "바이너리 설치: $INSTALL_DIR/eastsea"
        return 0
    fi

    log_warn "Zig 컴파일러가 없습니다. 먼저 Zig를 설치하세요:"
    echo "  curl -fsSL https://ziglang.org/download/index.json | jq '.master.\"$arch-$os\"'"
    echo "  또는: brew install zig (macOS)"
    return 1
}

# === 서비스 상태 확인 ===

check_service_status() {
    if command -v eastsea &>/dev/null; then
        log_info "eastsea 명령어 사용 가능: $(which eastsea)"
        
        # 설정 파일 확인
        if [ -f "$CONFIG_FILE" ]; then
            local node_port
            node_port=$(grep '"node_port"' "$CONFIG_FILE" | grep -o '[0-9]*')
            local rpc_port
            rpc_port=$(grep '"rpc_port"' "$CONFIG_FILE" | grep -o '[0-9]*')
            log_info "설정: node_port=$node_port, rpc_port=$rpc_port"
        fi
        return 0
    else
        log_warn "eastsea 바이너리를 찾을 수 없습니다"
        return 1
    fi
}

# === 도움말 ===

print_help() {
    echo "Eastsea Node 설치 스크립트 v$VERSION"
    echo ""
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  --help          이 도움말 표시"
    echo "  --version       버전 정보 표시"
    echo "  --dry-run       실제 설치 없이 시뮬레이션"
    echo "  --check         설치 상태 확인"
    echo "  --uninstall     설치 제거"
    echo ""
    echo "환경 변수:"
    echo "  EASTSEA_VERSION       설치 버전 (기본: $VERSION)"
    echo "  EASTSEA_INSTALL_DIR   설치 경로 (기본: $INSTALL_DIR)"
    echo "  EASTSEA_DATA_DIR      데이터 경로 (기본: $DATA_DIR)"
}

# === dry-run 모드 ===

dry_run() {
    local os_info
    os_info=$(detect_os)
    
    echo "🔍 Dry-run 모드 (실제 변경 없음)"
    echo "================================"
    echo "OS 탐지:     $os_info"
    echo "설치 경로:   $INSTALL_DIR"
    echo "데이터 경로: $DATA_DIR"
    echo "설정 파일:   $CONFIG_FILE"
    
    local node_port rpc_port
    node_port=$(find_available_port 8000)
    rpc_port=$(find_available_port 8545)
    echo "Node 포트:   $node_port"
    echo "RPC 포트:    $rpc_port"
    
    if [ "$(id -u)" -eq 0 ]; then
        echo "권한:        root"
    elif [ -w "$INSTALL_DIR" ]; then
        echo "권한:        쓰기 가능"
    else
        echo "권한:        ⚠️  쓰기 불가 (sudo 필요)"
    fi
    
    echo "================================"
    echo "✅ dry-run 완료 (문제 없음)"
}

# === 설치 제거 ===

uninstall() {
    log_step "Eastsea Node 제거 중..."
    
    if [ -f "$INSTALL_DIR/eastsea" ]; then
        rm -f "$INSTALL_DIR/eastsea"
        log_info "바이너리 제거: $INSTALL_DIR/eastsea"
    fi
    
    echo ""
    echo "데이터 디렉토리를 삭제하시겠습니까? ($DATA_DIR)"
    echo "  수동 삭제: rm -rf $DATA_DIR"
    log_info "제거 완료"
}

# === 메인 실행 ===

main() {
    echo ""
    echo "🌊 Eastsea Node 설치 스크립트 v$VERSION"
    echo "========================================"
    
    # 인자 파싱 (UT-103-01)
    case "${1:-install}" in
        --help|-h)
            print_help
            exit 0
            ;;
        --version|-v)
            echo "v$VERSION"
            exit 0
            ;;
        --dry-run)
            dry_run
            exit 0
            ;;
        --check)
            check_service_status
            exit $?
            ;;
        --uninstall)
            uninstall
            exit 0
            ;;
        install|"")
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            print_help
            exit 1
            ;;
    esac
    
    # 설치 순서
    log_step "1/5 OS 감지..."
    local os_info
    os_info=$(detect_os)
    log_info "OS: $os_info"
    
    log_step "2/5 권한 확인..."
    check_privileges "$@" || exit 1
    
    log_step "3/5 데이터 디렉토리 설정..."
    setup_data_dir
    
    log_step "4/5 기본 설정 생성..."
    create_default_config
    
    log_step "5/5 바이너리 빌드/설치..."
    install_binary || {
        log_warn "바이너리 설치 건너뜀 (수동 설치 필요)"
    }
    
    echo ""
    echo "========================================"
    log_info "설치 완료!"
    echo ""
    echo "  시작: eastsea --demo"
    echo "  상태: $0 --check"
    echo "  제거: $0 --uninstall"
    echo ""
}

main "$@"
