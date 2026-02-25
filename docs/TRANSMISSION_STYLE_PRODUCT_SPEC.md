# Transmission 스타일 단일 앱 설치/기동 제품 스펙 v1.0 (최대 해상도)

## 1) 핵심 목표
- 사용자는 macOS / Linux / Windows에서 설치 패키지 또는 `scripts/install.sh` 한 번 실행만 수행하면 기본 동작 가능한 단일 앱 환경이 된다.
- 별도 포트/경로/권한 사전 지식 없이 최초 설치 후 바로 시작 버튼 또는 자동 실행을 통해 노드가 기동된다.
- 버튼 하나씩의 동작은 명확하고, 실패 시 복구 경로가 1회 클릭으로 제공된다.

## 2) 제품 정의(Transmission 정합)
- 설치 결과물:
  - 바이너리: `eastsea` (`/usr/local/bin` or 사용자 경로)
  - 설치 스크립트/패키지: `scripts/install.sh`
  - 서비스/데몬(옵션): `systemd` 또는 macOS LaunchAgent, Windows 서비스
  - 컨테이너: `Dockerfile`, `docker-compose.yml`
- 런타임 계약:
  - 첫 실행 자동 온보딩
  - 포트 충돌 자동 보정
  - 권한 부족 경고 자동 안내
  - 실행상태/로그/헬스 노출

## 3) 완료 기준(Go/No-Go)
- 설치 완료 시 60초 이내 `is_running=true` 또는 대체포트 반영됨.
- 최초 실행이 실패 없이 `/status`, RPC 기본 호출 성공.
- 포맷/빌드/단위 테스트 통과.
- 통합 실행은 실패해도 종료 코드 1 허용 로그로 추적(현재 보드에서 run이 즉시 종료되는 특성 분리 관리).
- 설치/업데이트/삭제/재설치 재현성 보장.

## 4) 사용자 액션 기준 버튼 정의 (1개 버튼 = 1개 동작)

### 4-1 앱 설치
- 버튼명: `Install`
- API/커맨드: `scripts/install.sh`
- 전제: OS/아키텍처 정상, 기록 가능한 경로 존재
- 동작:
  - 설치 파일 복사/심볼릭 경로 생성
  - 기본 설정 파일 생성
  - 데이터 경로 생성
  - 권한/포트 사전 검사
- 성공: 설치 로그 + 시작 준비 완료
- 실패: 경고 메시지 + 재시도/수동 경로 지정

### 4-2 노드 시작
- 버튼명: `Start`
- API: `eastsea start`
- 전제: install 완료, 설정 파일 존재
- 동작:
  - 포트 충돌 검사
  - 충돌 시 대체포트 제안
  - 데몬/프로세스 기동
- 성공: 상태 `running`, RPC 응답
- 실패: 포트/권한 메시지로 가이드

### 4-3 노드 중지
- 버튼명: `Stop`
- API: `eastsea stop`
- 동작: Graceful shutdown(노드 RPC→P2P→QUIC→프로세스 종료 순)
- 실패: 강제 종료 절차 안내

### 4-4 재시작
- 버튼명: `Restart`
- API: `eastsea restart`
- 동작: Stop→1회 대기→Start
- 제한: 연속 3회 실패 시 롤백 제안

### 4-5 상태 조회
- 버튼명: `Status`
- API: `eastsea status`
- 출력: PID, 실행 모드, 포트, 마지막 블록 높이, 연결 노드 수

### 4-6 로그 보기
- 버튼명: `Open Logs`
- API: `eastsea logs`
- 출력: 최근 200줄 + 로그 파일 경로
- 실패: 경로 권한/없음 안내

### 4-7 포트 충돌 해결
- 버튼명: `Fix Ports`
- 동작: 충돌 포트 스캔 → 대체 포트 적용 → 재기동
- 기준: base 포트(8000/8545/9000) 충돌 시 +1 재시도

### 4-8 권한 해결
- 버튼명: `Fix Privileges`
- 동작: 필요 권한(포트 바인딩/서비스 등록/쓰기 권한) 단계별 가이드

### 4-9 업데이트
- 버튼명: `Update`
- 동작: 채널 조회 → 다운로드 → checksum 검증 → 교체 → 재시작
- 실패: 이전 바이너리로 롤백

### 4-10 언인스톨
- 버튼명: `Uninstall`
- 옵션: 데이터 보존 / 완전 삭제
- 완료: 서비스 정리 후 바이너리 제거

### 4-11 진단 보고
- 버튼명: `Health Report`
- 동작: OS/네트워크/저장소/권한 리포트 생성
- 출력: 복사 가능한 텍스트 블록

## 5) 버튼별 유효성 규격
- 시작 직전 값 검증
- 동작 중 상태 비활성화
- 실패 시 재시도 버튼 노출
- 성공 시 성공 토스트 + 다음 추천 액션 노출

## 6) 실행 시나리오(총 8개 핵심 UX)
1. 신규 설치: Install → 자동 온보딩 → Start → Status 확인
2. 포트 충돌: Start 실패 → Fix Ports → Start
3. 권한 부족: Fix Privileges → 재시도
4. 자동 기동: Install 완료 후 자동 Start
5. 업데이트: Update → 성공 → Restart
6. 업데이트 실패: Update 실패 → 롤백 알림
7. 삭제: Uninstall → 데이터 보존 여부 확인 → 완료
8. 진단: Health Report → 문제 항목 수정 링크

## 7) 요구사항-테스트-유즈케이스 매핑(요약)
- REQ-100/101/103/104: 설치·온보딩·Docker 즉시 실행
- REQ-102/110/120/010: 런타임 상태, 업데이트/영속성/유지보수
- REQ-111/112: 충돌 진단/헬스 리포트
- REQ-001/002/040/021: 인증·권한·TLS·RPC 검증
- REQ-121/122/050/051/060: 모니터링·클러스터·CI·문서

## 8) 단위 테스트(UT) 확장 규칙
- 각 UT는 다음 5항목을 반드시 기록
  - 입력
  - 기대값
  - 실패 케이스
  - 경계값
  - 증상 로그
- 총합 52개 항목을 13개 모듈 단위 테스트로 추적

### 8-1 모듈 UT 최소 집합
- `onboarding`, `boot_check`, `storage_init`, `auth`, `tls_config`, `rpc_validator`,
  `updater`, `update_manager`, `persistence`, `rbac`, `diagnostics`, `monitoring`, `cluster`,
  설치/CI 흐름 보조 항목

## 9) 테스트 케이스(TC) 구성(해상도)
- Install: `TC-INSTALL-001` ~ `TC-INSTALL-006`
- Run: `TC-RUN-001` ~ `TC-RUN-005`
- Update/Uninstall: `TC-UPDATE-*`, `TC-UNINSTALL-*`
- API/Security/Doc/Node: `TC-API-*`, `TC-SEC-*`, `TC-NODE-*`, `TC-DOC-*`, `TC-CI-001`

## 10) Use Case(UC) 예시
- UC-01 설치 즉시 실행
- UC-02 포트 충돌 자동 복구
- UC-03 서비스 제어
- UC-04 업데이트/롤백
- UC-05 진단/문제 대응
- UC-06 권한 가이드
- UC-07 영속성 보존
- UC-08 문서/도움말 조회

## 11) 실행 계획(최종)
1) 설치/실행 통합 루프
- install.sh 검증, 자동 시작, 포트 보정, 상태 조회 자동화
2) 전 플랫폼 정렬
- macOS/Linux/Windows 설치 흐름 동등화
3) 통합 실행 안정화
- CI 통합 run 종료 처리의 의도화(비정상 종료 분리)
4) 증적 완결
- `REQ/UT/TC/UC` 실행 로그를 단일 증적(`TEST_RESULTS.md`)로 동기화
5) 릴리즈
- CI gate + 실행 가이드 + 사용자 온보딩 문서 한 번에 배포

## 12) 마감 정의
- `PASS`:
  - CI 포맷/빌드/단위 테스트 통과
  - 설치 후 기본 기동이 실패 없이 확인
  - 모든 REQ의 증적이 하나의 문서 소스에서 추적
  - 실패 시 복구 버튼 1회 클릭 유도 정책 동작
- `HOLD`:
  - 통합 실행 코드 1의 원인 미해결인 상태(현재는 로그 분리 관리)
