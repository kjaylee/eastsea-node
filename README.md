# Eastsea Node

블록체인 노드 구현 — "Install-and-Run" 철학 기반

![Eastsea Node Dashboard](docs/dashboard.png)

## 빠른 시작

```bash
# macOS 원클릭 설치
bash scripts/install-macos.sh install

# 또는 소스 빌드
zig build && ./zig-out/bin/eastsea-production

# DMG 패키지 생성
bash scripts/create-dmg.sh 0.1.0

# Docker
docker compose up
```

실행 후 **http://127.0.0.1:8545** 에서 대시보드가 자동으로 열립니다.

## 프로젝트 구조

```
src/
├── main.zig            # 엔트리포인트
├── onboarding.zig      # REQ-101: 온보딩 설정
├── boot_check.zig      # REQ-111: 포트/권한 진단
├── storage_init.zig    # REQ-110: 저장소 초기화
├── auth.zig            # REQ-001: 인증 토큰
├── tls_config.zig      # REQ-040: TLS/비밀 관리
├── rpc_validator.zig   # REQ-021: RPC mock 제거
├── updater.zig         # REQ-102: 버전 관리
├── update_manager.zig  # REQ-120: 업데이트 메커니즘
├── persistence.zig     # REQ-010: 영속성 보존
├── rbac.zig            # REQ-002: 역할 기반 권한
├── diagnostics.zig     # REQ-112: 진단 리포트
├── monitoring.zig      # REQ-121: 런타임 모니터링
├── cluster.zig         # REQ-122: 클러스터 관리
├── network/            # P2P/QUIC 네트워크
├── blockchain/         # 블록체인 코어
├── consensus/          # 합의 엔진
├── rpc/                # JSON-RPC 서버
└── cli/                # 지갑 CLI
scripts/
├── install.sh          # REQ-103: 설치 스크립트
└── ci.sh               # REQ-050/051: CI 파이프라인
docs/
├── PRODUCT_SPEC.md     # 제품 스펙
├── TEST_RESULTS.md     # 테스트 결과
└── REQ_TO_TEST_UC_MAP.md # 추적표
```

## CI 파이프라인

```bash
bash scripts/ci.sh 0.1.0       # 전체 파이프라인
bash scripts/ci.sh 0.1.0 test  # 테스트만
```

## 라이선스

MIT