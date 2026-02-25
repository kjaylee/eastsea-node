# Requirement Traceability Matrix v1.1

작성일: 2026-02-25

| Req ID | 제목 | 우선순위 | 범주 | 세부 내용 | 구현 위치(예상) | 상태 | 의존성 | 검증 방법 |
|---|---|---|---|---|---|---|---|---|
| REQ-100 | 멀티 플랫폼 설치 패키지 제공 | P0 | 설치성 | Windows/macOS/Linux 설치 패키지 제공 | scripts/package/*, infra/package | Planned | REQ-110, CI 파이프라인 | 설치 스모크 테스트(각 플랫폼) |
| REQ-101 | 첫 실행 마법사(온보딩) | P0 | UX | 최초 실행에서 최소 설정 생성 | src/onboarding, installer/hooks | Planned | REQ-100 | 새로 설치 후 자동 실행 테스트 |
| REQ-102 | 설치/업데이트/제거 일관성 | P0 | 운영성 | 설치/업데이트/언인스톨 동선 일치 | scripts/package/* | Planned | REQ-100 | 자동 패키지 E2E |
| REQ-103 | Linux CLI 자동 설치 스크립트 | P1 | 설치성 | 원클릭에 준하는 쉘 설치 제공 | scripts/install.sh | Planned | REQ-100 | CI에서 설치 스크립트 실행 검사 |
| REQ-104 | Docker 즉시 실행 | P1 | 실행성 | 볼륨 마운트 기반 단일 명령 실행 | Dockerfile, docker-compose.yml | Planned | REQ-110 | `docker run` smoke test |
| REQ-110 | 첫 실행 자동 초기화 | P0 | 안정성 | 첫 실행 저장소 및 기본 스키마 자동 생성 | src/storage/init, db/migrations | Planned | REQ-100 | 신설치 후 재시작 회귀 테스트 |
| REQ-111 | 포트/권한 충돌 자동 진단 | P1 | 안정성 | 시작 시 충돌 진단과 가이드 | src/boot/checks | Planned | REQ-110 | 충돌 시나리오 테스트 |
| REQ-112 | 실행 진단 리포트 | P2 | 진단 | 설치 후 HW/OS 요약 리포트 제공 | src/boot/report | Planned | REQ-110 | 수동 확인 |
| REQ-120 | 자동 업데이트/롤백 | P0 | 운영성 | 배포체계 기반 업데이트 동작 | scripts/update, deploy/* | Planned | 패키지 배포 체인 | 업데이트/롤백 리허설 |
| REQ-121 | 서비스 제어 CLI/버튼 | P1 | 운영성 | 시작/중지/재시작 동작 | src/cli, package integration | Planned | REQ-100 | 운영자 시나리오 테스트 |
| REQ-122 | 백그라운드 실행 지원 | P2 | 운영성 | 트레이/서비스 모드 지원 | platform runtime | Planned | REQ-100 | 수동 UX 점검 |
| REQ-001 | 인증 토큰 적용 | P0 | 보안 | API 인증 기본 적용 | src/auth | Planned | none | 401/재발급 테스트 |
| REQ-002 | 역할 기반 권한 | P1 | 보안 | 역할별 접근 제어 | src/rbac | Planned | REQ-001 | 권한 행렬 테스트 |
| REQ-010 | 영속성 보존 | P0 | 데이터 | 서비스 재시작 간 상태 보존 | src/storage | Planned | REQ-110 | 재시작 일관성 테스트 |
| REQ-021 | mock 응답 제거 | P0 | API 품질 | server mock 제거/실데이터 연동 | src/rpc/server.zig | InProgress | REQ-001, REQ-010 | 회귀 API 테스트 |
| REQ-040 | TLS/비밀 관리 | P0 | 보안 | TLS 및 Secret 외부 주입 | config, infra | Planned | none | 보안 체크리스트 |
| REQ-050 | CI/CD 기본 게이트 | P0 | 운영 | 빌드/테스트/패키지 생성/스캔 통합 | .github/workflows | Planned | 패키징 산출물 | 게이트 패스 확인 |
| REQ-051 | 롤백 가능한 배포 | P0 | 배포 | blue/green/canary 중 택일 | deploy/* | Planned | REQ-120 | 스테이징 롤백 테스트 |
| REQ-060 | API 문서 동기화 | P1 | 문서 | 문서-실제 계약 동기화 | docs/* | Planned | REQ-020 | 문서 회귀 비교 |

## 갭 및 우선순위 정렬(최종목표 반영)
- 최우선 P0: REQ-100,101,102,110,120,001,010,021,040,050,051
- P1은 출시 직후 사용자 유입과 운영 편의성 확보용
- P2는 다음 릴리즈에서 확장

## 상태 규칙
- P0 미완료 시 릴리즈 보류.
- 플랫폼별 상태(윈도우/맥/리눅스/Docker)는 별도 체크리스트로 관리한다.
- 패키지 산출물은 버전별 아티팩트 해시와 함께 저장한다.

## 3) 요구사항-테스트/경험 추적
- Req ↔ Unit Test/Case/Use Case/UX 추적표: `/Volumes/workspace/eastsea-node/docs/REQ_TO_TEST_UC_MAP.md`
- 모든 P0/P1은 매주 1회 매핑 충족률 점검.
