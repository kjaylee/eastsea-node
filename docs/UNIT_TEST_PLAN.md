# Unit Test Plan (Install-and-Run Productization)

작성일: 2026-02-25  
버전: v1.1.0  
범위: `REQ-100 ~ REQ-122` 기반, 전 기능 버튼 동작 보장

## 1) 목표
- 전 플랫폼(Windows / macOS / Linux / Docker) 설치 직후에도 동일한 동작을 보장한다.
- P0 요구사항이 사용자 조작(버튼/CLI 동작) 하나하나에서 실패하지 않도록 유닛 테스트 우선순위를 강제한다.
- 설치형 목표(`설치만 하면 실행`)를 무너뜨리는 회귀를 사전 차단한다.

## 2) 테스트 레이어 분해
### 2.1 단위 테스트(Unit)
- 순수 함수/클래스 레벨로 로직을 고립해 검증한다.
- `Zig test` + Mock 파일시스템/네트워크/시간을 사용한다.
- 포맷:
  - 함수 입력/출력
  - 상태 전이
  - 경고/오류 메시지 문자열(로컬라이징 제외, 키 기반 메시지 코드만 검증)

### 2.2 컴포넌트 테스트(Component)
- 설치 마법사, 업데이트 모듈, 서비스 제어 모듈을 화면/명령 라인 진입점 단위로 묶어 테스트한다.
- 버튼 이벤트가 핸들러에서 기대한 동작으로 연결되는지 확인한다.

### 2.3 통합 테스트(Integration)
- 단일 아티팩트로 install → start → status check → stop 동선을 검증한다.
- 플랫폼별 패키지 스크립트 및 런타임 진입 경로를 체크한다.

### 2.4 E2E/UX 테스트
- 운영자 또는 신규 사용자 입장에서 버튼 클릭/CLI 실행 기준으로 `TEST_CASES`의 케이스를 참조한다.

## 3) 전역 커버리지 기준
- P0 항목: 함수 커버리지 95% 이상, 분기 커버리지 85% 이상
- P1 항목: 함수 커버리지 80% 이상
- 실패 시 리스크: 실패 테스트가 5분 내 고립 원인 파악 및 담당자 지정되도록 CI 실패 메시지 정리

## 4) 공통 테스트 fixture
- 고정 포트: `8000`, `8545`
- 테스트 데이터 경로: 임시 디렉토리(실제 사용자 홈과 분리)
- 테스트 인증서/토큰: 고정 키를 아닌 생성형 난수 기반
- 타임존/날짜: UTC로 통일한 Clock stub
- OS 분기: Windows, Linux, macOS 용 시뮬레이션 플래그 주입

## 5) 기능별 Unit Test 상세 매핑

> 버튼명은 `UI/CLI`에서 동일한 동작으로 추적한다.

### 5.1 설치/온보딩 (REQ-100 ~ REQ-104, P0/P1)

| 테스트 ID | 요구사항 | 버튼/행동 | 유닛 대상 | 검증 포인트 |
|---|---|---|---|---|
| UT-100-01 | REQ-100 | `설치 시작` | `installer.validateEnvironment()` | OS별 요구 사양 검사(권한, 파일시스템, 아키텍처)가 정상 동작 |
| UT-100-02 | REQ-100 | `기본 경로 사용` | `installer.resolveInstallPath()` | 기본 경로 생성 규칙 준수, 경로 충돌 검사 |
| UT-100-03 | REQ-100 | `경로 변경` | `installer.validateDataPath()` | 쓰기 불가/공백 경로 등 예외 처리 |
| UT-101-01 | REQ-101 | `시작하기` | `onboarding.saveInitialConfig()` | 입력값 기본값 검증, schema 변환, 영속화 |
| UT-101-02 | REQ-101 | `포트 자동 제안` | `onboarding.pickHealthyPort()` | 충돌 감지 시 순차 대체 포트 제안 |
| UT-102-01 | REQ-102 | `업데이트 예약/설치` | `installer.getUpdateChannel()` | 채널 유효성 및 버전 파서 테스트 |
| UT-102-02 | REQ-102 | `설치 제거` | `uninstaller.cleanupPolicy()` | 잔여 데이터 보존/삭제 정책 분기 검증 |
| UT-103-01 | REQ-103 | `install.sh 실행` | `cliInstall.parseArgs()` | 옵션 파서, dry-run 시뮬레이션 |
| UT-104-01 | REQ-104 | `docker run` | `dockerEntry.bootstrapFromEnv()` | 볼륨 마운트 누락·권한 부재 처리 |

### 5.2 런타임 초기화/안정성 (REQ-110 ~ REQ-112)

| 테스트 ID | 요구사항 | 버튼/행동 | 유닛 대상 | 검증 포인트 |
|---|---|---|---|---|
| UT-110-01 | REQ-110 | `즉시 실행` | `bootstrap.autoInitStorage()` | 신규 설치 시 스키마 자동 생성 및 재시도 정책 |
| UT-110-02 | REQ-110 | `서비스 재시작` | `bootstrap.migrateOnce()` | 마이그레이션 중단/복구 흐름 |
| UT-111-01 | REQ-111 | `포트 검사` | `bootstrap.checkPortConflict()` | 사용 중/권한 제한 포트별 메시지 매핑 |
| UT-111-02 | REQ-111 | `권한 검사` | `bootstrap.checkPrivileges()` | 관리자 권한 필요한 동선 여부 판정 |
| UT-112-01 | REQ-112 | `진단 리포트 생성` | `diagnostic.collectSystemInfo()` | 누락 값 없는 필수 항목(버전/OS/네트워크) 생성 |

### 5.3 운영/제어 버튼 (REQ-120, REQ-121, REQ-122)

| 테스트 ID | 요구사항 | 버튼/행동 | 유닛 대상 | 검증 포인트 |
|---|---|---|---|---|
| UT-120-01 | REQ-120 | `업데이트 확인` | `update.checkForUpdate()` | manifest 파싱, 최신/이전 버전 비교 |
| UT-120-02 | REQ-120 | `업데이트 적용` | `update.applyUpdate()` | hash 검증, 트랜잭션적 파일 교체 |
| UT-120-03 | REQ-120 | `롤백 실행` | `update.rollback()` | 이전 릴리즈 바이너리 복구 |
| UT-121-01 | REQ-121 | `시작` | `service.start()` | 락 파일/이중기동 방지 |
| UT-121-02 | REQ-121 | `중지` | `service.stop()` | graceful shutdown timeout 후 강제 종료 여부 |
| UT-121-03 | REQ-121 | `재시작` | `service.restart()` | stop+start 원자성 |
| UT-122-01 | REQ-122 | `백그라운드 전환` | `runtime.enterBackground()` | 트레이 모드 진입 시 UI 상태 보존 |

### 5.4 보안 및 API (REQ-001, REQ-002, REQ-040, REQ-021)

| 테스트 ID | 요구사항 | 버튼/행동 | 유닛 대상 | 검증 포인트 |
|---|---|---|---|---|
| UT-001-01 | REQ-001 | `토큰 생성` | `auth.issueToken()` | 만료/권한 scope 적용 |
| UT-001-02 | REQ-001 | `로그인` | `auth.validateToken()` | 만료·위조·타입 불일치 응답 |
| UT-002-01 | REQ-002 | `권한 변경` | `rbac.grantRole()` | 읽기/쓰기 경계 위반 차단 |
| UT-021-01 | REQ-021 | `상태 조회` | `rpc.getNodeInfo()` | mock 값 의존 제거 확인(스텁 없이 실패 시 에러) |
| UT-040-01 | REQ-040 | `TLS 토글` | `tls.validateConfig()` | 비밀 누출 없이 config marshal |
| UT-040-02 | REQ-040 | `비밀 회전` | `secret.rotate()` | 외부 저장소 연동, 로그 마스킹 |

### 5.5 데이터 정합성/복구 (REQ-010)

| 테스트 ID | 요구사항 | 버튼/행동 | 유닛 대상 | 검증 포인트 |
|---|---|---|---|---|
| UT-010-01 | REQ-010 | `저장 경로 초기화` | `storage.initDir()` | 권한 생성, 락 정리 |
| UT-010-02 | REQ-010 | `데이터 백업` | `storage.snapshot()` | 백업 메타데이터 일관성 |
| UT-010-03 | REQ-010 | `복원` | `storage.restore()` | 타임스탬프 정합성, 손상 파일 처리 |

## 6) API/도메인 함수 단위 테스트 (버튼 없는 기능 포함)
| 테스트 ID | 함수 | 검증 대상 |
|---|---|---|
| API-001 | `rpc.getBlockHeight()` | 빈 체인/회복 상태에서 음수/오버플로우 방지 |
| API-002 | `rpc.getBalance(address)` | 잘못된 주소 길이, 존재하지 않는 계정 |
| API-003 | `rpc.sendTransaction()` | 잔액 부족/서명 실패/순환 nonce |
| API-004 | `wallet.generateKeyPair()` | 키 길이, deterministic seed 분리 |
| API-005 | `network.connect()` | peer_count 한계, 연결 실패 재시도 |

## 7) 예외/보안 공격면 테스트
- 파일 경로 Traversal 입력
- JSON-RPC 과도 요청 바디 크기
- 관리자 권한 상승 없는 종료 시도
- checksum 조작된 업데이트 패키지
- 악성 포트 충돌 시나리오(권한 낮은 프로세스 점유)

## 8) 테스트 실행 우선순위
1. 우선순위 1: P0 설치/초기화류(가장 선행)
2. 우선순위 2: 운영 제어 버튼류
3. 우선순위 3: 업데이트/롤백
4. 우선순위 4: 보안·API
5. 우선순위 5: 회귀/통합

## 9) 결과 해석 기준
- FAIL은 즉시 기능 스톱.  
- `버튼 액션 ID` 기준으로 실패를 모듈 담당자에게 1차 배분한다.
- 1일 기준 수정 후 24시간 내 재실행을 목표로 한다.
