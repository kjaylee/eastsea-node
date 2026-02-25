# 🌊 Eastsea-node 프로젝트 계획서 (PLAN.md)

> **마지막 업데이트**: 2026-02-25 12:13
> **프로젝트 상태**: 핵심 기능(Phase 1-13) 100% 완료 | Install-and-Run 제품화 **단계 1 진행 중**

---

## 📊 현재 진행 상태

### 단계 1 실행 큐 (REQ_TO_TEST_UC_MAP 기준)

| 상태 | 요구사항 | 설명 |
|------|---------|------|
| 🟢 **Active** | REQ-100 | 멀티 플랫폼 설치 패키지 (온보딩/설치 핵심 동선) |
| 🔵 **In Progress** | REQ-101, REQ-103, REQ-104, REQ-111 | 온보딩 마법사, CLI 설치, Docker, 포트 진단 |
| ⚪ **Ready** | REQ-102, REQ-120, REQ-121 | 단계 2 진입 조건 충족 시 활성화 |

### 상태값 체계 (6종)
`미진행` → `준비중` → `진행` → `검증중` → `완료` | `블로킹` (외부 의존성)

---

## 📋 문서 체계 (docs/ 14개 파일)

| 문서 | 크기 | 역할 |
|------|------|------|
| [IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) | 5.0KB | 12단계 실행 계획 |
| [PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md) | 7.3KB | 제품 스펙 (REQ 20개, KPI) |
| [ROADMAP.md](docs/ROADMAP.md) | 2.8KB | 6단계 로드맵 |
| [EXECUTION_PLAN.md](docs/EXECUTION_PLAN.md) | 3.5KB | UT/TC/UC/UX 6단계 실행 |
| [REQ_MATRIX.md](docs/REQ_MATRIX.md) | 4.1KB | 요구사항 추적 매트릭스 |
| [REQ_TO_TEST_UC_MAP.md](docs/REQ_TO_TEST_UC_MAP.md) | 5.7KB | REQ↔UT↔TC↔UC 추적표 (**순차 운영 체계 포함**) |
| [TEST_CASES.md](docs/TEST_CASES.md) | 12.0KB | 30+ 버튼 단위 TC |
| [USE_CASES.md](docs/USE_CASES.md) | 6.0KB | 15개 UC |
| [UNIT_TEST_PLAN.md](docs/UNIT_TEST_PLAN.md) | 7.9KB | 단위 테스트 전략 (v1.1.0) |
| [TOTAL_USER_EXPERIENCE_MAP.md](docs/TOTAL_USER_EXPERIENCE_MAP.md) | 4.7KB | 사용자 여정 지도 (Mermaid 다이어그램) |
| [API.md](docs/API.md) | 11.8KB | JSON-RPC API 문서 |
| [DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md) | 21.0KB | 개발자 가이드 |
| [USER_GUIDE.md](docs/USER_GUIDE.md) | 16.5KB | 사용자 가이드 |
| [EXAMPLES.md](docs/EXAMPLES.md) | 65.4KB | 코드 예제 |

---

## 🎯 Gap Analysis

### ✅ 완료 (코드)
- 블록체인 핵심, P2P(TCP/QUIC/DHT), PoH 합의, 스마트 컨트랙트
- EAS(증명/프라이버시), 테스트 프레임워크, 문서화
- **코드 규모**: ~23,172줄 Zig 소스

### 🔴 미착수 (제품화)
**IMPLEMENTATION_PLAN 12단계 전부 `[ ]`** — 구체적으로:

| 단계 | 핵심 산출물 | 대상 REQ |
|------|-----------|---------|
| 1 | 패키징 기준, 설치 실패 패턴 분석 | REQ-100~102 |
| 2 | 배포 파이프라인, 온보딩 설계 | REQ-100~104 |
| 3 | 영속성 초기화, 진단 로직 | REQ-110 |
| 4 | mock 제거, 인증/에러 스키마 | REQ-021, REQ-001 |
| 5 | Docker/CLI 통일, 업데이트 시퀀스 | REQ-104, REQ-120 |
| 6 | 롤백, 언인스톨 데이터 정책 | REQ-120, REQ-051 |
| 7 | start/stop/restart CLI/GUI 연동 | REQ-121 |
| 8 | 플랫폼별 스모크 자동화 | REQ-050 |
| 9 | API 문서 자동 배포, 설치 가이드 | REQ-060 |
| 10 | 릴리즈 후보, runbook | REQ-050, REQ-051 |
| 11 | 전 플랫폼 회귀 테스트 | 전체 P0 |
| 12 | Go/No-Go, 출시 | 전체 |

### ⚠️ 코드 레벨 즉시 조치
1. `build.zig`: QUIC 테스트 run command 누락
2. `build.zig`: 웹서버 테스트 전체 주석
3. 루트 디렉토리: `.o`/바이너리 파일 산재 (.gitignore 보강)
4. `src/rpc/server.zig`: mock 응답 제거 필요 (REQ-021)

---

## 📅 권장 착수 순서

1. **지금**: `zig build && zig build test` — 코드 안정성 확인
2. **단기**: 단계 1-2 착수 — 패키징 기준 + CI/CD (GitHub Actions)
3. **중기**: 단계 3-4 — mock 제거 + 영속성 + 인증
4. **목표**: 단계 12 — Install-and-Run v1 출시

---

*이 문서는 `docs/IMPLEMENTATION_PLAN.md` 및 `docs/REQ_TO_TEST_UC_MAP.md`와 동기화하여 관리합니다.*
