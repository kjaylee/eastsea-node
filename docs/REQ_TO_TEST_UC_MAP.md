# 요구사항 → 테스트 → 유스케이스 추적표 (SSOT)

> 이 문서는 모든 REQ의 유일한 상태 소스다.

## 1) 실행 큐 현황

### Plan-Do-See 사이클
- 현재 사이클: **전체 완료**
- 총 테스트: **13개 모듈 단위 테스트 통과** (요구사항 트래킹 기준 **52개 테스트 항목**)
- CI: `bash scripts/ci.sh 0.1.0 test` → **13/13 모듈 통과**

### 단계별 현황
- **단계 1**: REQ-100 ✅, REQ-101 ✅, REQ-103 ✅, REQ-104 ✅, REQ-111 ✅
- **단계 2**: REQ-110 ✅, REQ-021 ✅, REQ-040 ✅, REQ-001 ✅
- **단계 3**: REQ-102 ✅, REQ-120 ✅, REQ-010 ✅, REQ-002 ✅, REQ-121 ✅
- **단계 4**: REQ-112 ✅, REQ-122 ✅
- **단계 5**: REQ-060 ✅
- **단계 6**: REQ-050 ✅, REQ-051 ✅

| Req ID | 우선순위 | 단계 | 상태 | UT 매핑 | UT 상태 | TC 매핑 | TC 상태 | UC 매핑 | UC 상태 | UX/여정 매핑 | UX 상태 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| REQ-100 | P0 | 단계 1 | 완료 | UT-100-01, UT-100-02, UT-100-03 | 완료 | TC-INSTALL-001, TC-INSTALL-002, TC-INSTALL-005, TC-INSTALL-006, TC-DOCKER-001 | 완료 | UC-01, UC-02 | 완료 | Phase 1, Phase 2 | 완료 |
| REQ-101 | P0 | 단계 1 | 완료 | UT-101-01, UT-101-02 | 완료 | TC-INSTALL-004, TC-INSTALL-003, TC-INSTALL-005 | 완료 | UC-01, UC-06 | 완료 | Phase 1 | 완료 |
| REQ-102 | P0 | 단계 3 | 완료 | UT-102-01, UT-102-02 | 완료 | TC-INSTALL-001, TC-UPDATE-001, TC-UPDATE-002, TC-UNINSTALL-001 | 완료 | UC-04, UC-05, UC-10 | 완료 | Phase 1, Phase 5 | 완료 |
| REQ-103 | P1 | 단계 1 | 완료 | UT-103-01 | 완료 | TC-INSTALL-006 | 완료 | UC-01, UC-02 | 완료 | Phase 1 | 완료 |
| REQ-104 | P1 | 단계 1 | 완료 | UT-104-01 | 완료 | TC-DOCKER-001 | 완료 | UC-02 | 완료 | Phase 2 | 완료 |
| REQ-110 | P0 | 단계 2 | 완료 | UT-110-01, UT-110-02 | 완료 | TC-RUN-001, TC-RUN-005, TC-ONEFLOW-001 | 완료 | UC-01, UC-02 | 완료 | Phase 2, Phase 3 | 완료 |
| REQ-111 | P1 | 단계 1 | 완료 | UT-111-01, UT-111-02 | 완료 | TC-INSTALL-003, TC-RUN-001, TC-RUN-004 | 완료 | UC-06 | 완료 | Phase 1, Phase 4 | 완료 |
| REQ-112 | P2 | 단계 4 | 완료 | UT-112-01 | 완료 | TC-SEC-003, TC-ONEFLOW-002 | 완료 | UC-08, UC-01 | 완료 | Phase 2, Phase 4 | 완료 |
| REQ-120 | P0 | 단계 3 | 완료 | UT-120-01, UT-120-02, UT-120-03 | 완료 | TC-UPDATE-001, TC-UPDATE-002, TC-UPDATE-003, TC-UPDATE-005 | 완료 | UC-04, UC-05 | 완료 | Phase 3, Phase 4, Phase 5 | 완료 |
| REQ-121 | P1 | 단계 3 | 완료 | UT-121-01, UT-121-02, UT-121-03 | 완료 | TC-RUN-001, TC-RUN-002, TC-RUN-003, TC-RUN-004, TC-RUN-005 | 완료 | UC-03, UC-08 | 완료 | Phase 3 | 완료 |
| REQ-122 | P2 | 단계 4 | 완료 | UT-122-01 | 완료 | TC-NODE-003 | 완료 | UC-14 | 완료 | Phase 3 | 완료 |
| REQ-001 | P0 | 단계 2 | 완료 | UT-001-01, UT-001-02 | 완료 | TC-SEC-001, TC-SEC-002, TC-API-001 | 완료 | UC-09 | 완료 | Phase 2 | 완료 |
| REQ-002 | P1 | 단계 3 | 완료 | UT-002-01 | 완료 | TC-SEC-001, TC-SEC-002, TC-API-001 | 완료 | UC-09 | 완료 | Phase 2 | 완료 |
| REQ-010 | P0 | 단계 3 | 완료 | UT-010-01, UT-010-02, UT-010-03 | 완료 | TC-UNINSTALL-002, TC-RUN-001, TC-UNINSTALL-001 | 완료 | UC-07, UC-10 | 완료 | Phase 3 | 완료 |
| REQ-021 | P0 | 단계 2 | 완료 | UT-021-01 | 완료 | TC-API-001, TC-API-002 | 완료 | UC-01, UC-02 | 완료 | Phase 2 | 완료 |
| REQ-040 | P0 | 단계 2 | 완료 | UT-040-01, UT-040-02 | 완료 | TC-SEC-003, TC-SEC-002 | 완료 | UC-09, UC-08 | 완료 | Phase 2, Phase 4 | 완료 |
| REQ-050 | P0 | 단계 6 | 완료 | TC-CI-001 | 완료 | TC-CI-001 | 완료 | UC-12 | 완료 | Phase 5 | 완료 |
| REQ-051 | P0 | 단계 6 | 완료 | UT-120-01, UT-120-03, UT-120-02 | 완료 | TC-UPDATE-002, TC-UPDATE-003, TC-UPDATE-005 | 완료 | UC-04, UC-05 | 완료 | Phase 3, Phase 4 | 완료 |
| REQ-060 | P1 | 단계 5 | 완료 | TC-DOC-001 | 완료 | TC-DOC-001 | 완료 | UC-12 | 완료 | Phase 5 | 완료 |

## 2) 사용 방법
상태값은 다음 6종으로 통일한다.

| 코드 | 의미 |
|------|------|
| 미진행 | 아직 착수 안 됨 |
| 준비중 | 선행 조건 확인 중 |
| 진행 | 현재 작업 중 |
| 검증중 | 구현 완료, 최종 검증 대기 |
| 완료 | 검증 통과 |
| 보류 | 의존성/이슈로 일시 중단 |

## 3) 산출물 매핑

| 모듈 | REQ | 파일 | 테스트 수 |
|------|-----|------|-----------|
| 온보딩 | REQ-101 | `src/onboarding.zig` | 6 |
| 부트 진단 | REQ-111 | `src/boot_check.zig` | 6 |
| 저장소 | REQ-110 | `src/storage_init.zig` | 4 |
| 인증 | REQ-001 | `src/auth.zig` | 4 |
| TLS/비밀 | REQ-040 | `src/tls_config.zig` | 5 |
| RPC 검증 | REQ-021 | `src/rpc_validator.zig` | 5 |
| 업데이터 | REQ-102 | `src/updater.zig` | 4 |
| 업데이트 | REQ-120 | `src/update_manager.zig` | 4 |
| 영속성 | REQ-010 | `src/persistence.zig` | 3 |
| RBAC | REQ-002 | `src/rbac.zig` | 4 |
| 진단 | REQ-112 | `src/diagnostics.zig` | 1 |
| 모니터링 | REQ-121 | `src/monitoring.zig` | 5 |
| 클러스터 | REQ-122 | `src/cluster.zig` | 1 |
| 설치 | REQ-103 | `scripts/install.sh` | CLI |
| CI | REQ-050/051 | `scripts/ci.sh` | CI |
| 문서 | REQ-060 | `README.md` | - |
| Docker | REQ-104 | `Dockerfile` | Docker |
| **합계** | **19 REQ** | **17 파일** | **52 tests** |
