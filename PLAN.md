# Eastsea Node 제품화 계획 (PLAN.md)

## 현재 상태: ✅ 전체 구현 완료

| 항목 | 수치 |
|------|------|
| 완료 REQ | **18/19** (REQ-104 Docker만 수동 검증 대기) |
| 신규 모듈 | **13개** Zig 파일 |
| 유닛 테스트 | **52개 전부 통과** |
| CI 통과율 | **13/13 모듈** |
| 산출물 파일 | **17개** |

## 산출물 요약

### Zig 모듈 (src/)
| 모듈 | REQ | 테스트 |
|------|-----|--------|
| `onboarding.zig` | REQ-101 | 6 |
| `boot_check.zig` | REQ-111 | 6 |
| `storage_init.zig` | REQ-110 | 4 |
| `auth.zig` | REQ-001 | 4 |
| `tls_config.zig` | REQ-040 | 5 |
| `rpc_validator.zig` | REQ-021 | 5 |
| `updater.zig` | REQ-102 | 4 |
| `update_manager.zig` | REQ-120 | 4 |
| `persistence.zig` | REQ-010 | 3 |
| `rbac.zig` | REQ-002 | 4 |
| `diagnostics.zig` | REQ-112 | 1 |
| `monitoring.zig` | REQ-121 | 5 |
| `cluster.zig` | REQ-122 | 1 |

### 인프라
- `scripts/install.sh` — REQ-103 CLI 설치 (290줄)
- `scripts/ci.sh` — REQ-050/051 CI 파이프라인
- `Dockerfile` + `docker-compose.yml` — REQ-104 Docker
- `README.md` — REQ-060 문서화

## 남은 작업
- [ ] REQ-104: Docker CLI 설치 후 `docker build` 수동 검증
- [x] `.gitignore` 보강 (`dist/`, `.eastsea/` 추가)
- [x] `build.zig`에 신규 모듈 빌드 타겟 추가 (13개 모듈 → `zig build test` 통합)
