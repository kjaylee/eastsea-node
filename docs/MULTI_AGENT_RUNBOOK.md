# Multi-Agent Runbook (spec/test/implementation loop)

작성일: 2026-02-25  
목적: 두 에이전트가 `TC → 구현 → 검증` 루프를 충돌 없이 동시에 운영

## 1) 기본 규칙
1. 단일 진실(SSOT): `/Volumes/workspace/eastsea-node/docs/REQ_TO_TEST_UC_MAP.md`
2. 실행 로그: `/Volumes/workspace/eastsea-node/docs/EXECUTION_LOG.md` (신규 파일)
3. 테스트 결과 보존: `/Volumes/workspace/eastsea-node/docs/TEST_RESULTS.md` (신규 파일)
4. 상태 코드만 동기화: `미진행/준비중/진행/검증중/블로킹/완료`
5. 한 번에 동시에 작업하는 범위는 최대 1개 `REQ` 또는 1개 `TC` 단위.

## 2) 역할 분담
- 에이전트 A: 구현(코드/구성/패키징)
  - 작업 산출: 커밋 전 수정 파일, 변경 요약
  - 상태 업데이트: 관련 `REQ`/`UT` 상태
- 에이전트 B: 테스트/검증(테스트 실행 준비/증적 정리)
  - 작업 산출: 실패 로그, 재현 절차, 통과 기준
  - 상태 업데이트: `TC`/`UX` 상태

## 3) 공유 문서 역할
- `REQ_TO_TEST_UC_MAP.md`: 어떤 것이 아직 안 됐는지, 무엇이 다음 순서인지 결정
- `UNIT_TEST_PLAN.md`: `REQ`의 최소 단위 테스트 정의
- `TEST_CASES.md`: 실제 버튼/명령어 케이스 실행 지침
- `USE_CASES.md`: 사용자 관점 인수조건 검증
- `TOTAL_USER_EXPERIENCE_MAP.md`: 설치/실행 흐름의 UX 품질 검증 기준
- `IMPLEMENTATION_PLAN.md`/`EXECUTION_PLAN.md`: 일정/우선순위/단계 안내
- `EXECUTION_LOG.md`: 누가, 언제, 무엇을 했는지 기록
- `TEST_RESULTS.md`: 테스트 결과(재현값 포함) 기록

## 4) 상태 동기화 형식
- 행위가 완료되면 `REQ_TO_TEST_UC_MAP.md`에 즉시 반영
  - 예시 템플릿
    - `REQ-100 상태: 진행`
    - `UT-100-01 상태: 완료`
    - `TC-INSTALL-001 상태: 진행`
    - `근거: 테스트 로그 경로`
- `블로킹` 발생 시, `REQ`가 아닌 가장 상위 이슈(패키지 인증/네트워크/권한/인프라)로 원인 등록

## 5) plan-do-see 루프 (1회 반복 단위)
1. Plan(계획)
  - `REQ` 1개 선택
  - `우선순위`/`단계`/`의존성` 확인
  - 실행 가능한 `TC` 1~3개로 축소
2. Do(실행)
  - 구현 or 테스트 수행
  - 중간 결과를 즉시 로그에 기록
3. See(검증)
  - PASS/FAIL/블로킹 판정
  - 실패 시 에러 코드 + 재현 스텝 + 증분 수정안 기록
4. Adjust(반영)
  - 상태 업데이트
  - 다음 실행 대상 큐 갱신

## 6) 동시 작업 충돌 방지
- 같은 파일 동시 편집 금지
- 같은 `REQ`를 각자가 동시에 진행하지 않기
- 동일 `TC`를 두 번 작성하지 않기
- `문서 업데이트`와 `코드 변경`은 분리된 메시지 라인으로 전달

## 7) 서로 교차 전달 템플릿(복사 사용)
- 상황 요약:
  - `현재 활성 Req: REQ-100`
  - `진행 항목: UT-100-02`
- 수행 결과:
  - `액션: UT-100-02 실행`
  - `결과: PASS/FAIL`
  - `에러코드: ERR-xxx`
  - `로그: /path/to/log`
- 다음 액션:
  - `다음 대상 Req/TC`
  - `필요 차단 조건: ...`

## 8) 에이전트가 바로 시작할 액션 리스트
- 즉시 동기화 대상 1차:
  - `REQ-100`의 `UT-100-01`~`UT-100-03` 실행/결과 기록
  - `TC-INSTALL-001`, `TC-INSTALL-002`, `TC-INSTALL-005` 실행/결과 기록
- 완료 시:
  - `REQ-100` 상태를 `완료` 처리
  - 큐에서 `REQ-101`을 `Active`로 이동

## 9) 실행 로그 템플릿 생성 지침
- `EXECUTION_LOG.md`, `TEST_RESULTS.md`가 없으면 즉시 생성
- 각 항목은 시간 기준 정렬
- 증거 링크(로그/스크린샷/요약)를 필수로 붙임

## 10) 종료 조건
- 단계1 목표: `REQ-100` 완료 후 단계2 진입
- 단계 게이트: 해당 단계의 P0가 모두 `완료` + 블로킹 0건
- P0 미완료 시 릴리즈 게이트 보류

## 11) 무인 실행용 에이전트 간 메시지 규격(표준 포맷)
- 모든 에이전트는 작업 시작/종료/차단 시 아래 형식으로 `EXECUTION_LOG.md`에 작성한다.

### 메시지 헤더(필수)
`[agent=<A|B>] [시간=YYYY-MM-DD HH:MM] [대상=REQ-XXXX|UT-XXXX|TC-XXXX|UX-STEP] [행동=Plan|Do|See|Adjust]`

### 본문(필수)
- 상태 변경:
  - `요구사항 상태: 미진행|준비중|진행|검증중|블로킹|완료`
  - `세부상태: UT/TC/UC/UX 해당 상태`
- 실행 결과:
  - `PASS/FAIL/BLOCKED`
  - `에러 코드(있으면)`
  - `로그 경로 또는 증적 ID`
- 다음 액션:
  - `다음 대상`
  - `차단 사유(있으면)`

### 1회 샘플 (복사/붙여넣기)
```
[agent=A] [시간=2026-02-25 10:05] [대상=REQ-100] [행동=Do]
- 상태 변경:
  - Req: 미진행 -> 진행
  - UT: UT-100-01 준비중 -> 진행
- 실행 결과:
  - PASS
  - 에러 코드: 없음
  - 로그: /Volumes/workspace/eastsea-node/logs/req100-ut100-01.log
- 다음 액션:
  - 다음 대상: TC-INSTALL-001
  - 차단 사유: 없음
```

```
[agent=B] [시간=2026-02-25 10:22] [대상=TC-INSTALL-001] [행동=See]
- 상태 변경:
  - TC-INSTALL-001 준비중 -> 완료
  - REQ-100: 진행 (하위 상태 검증 진행 중)
- 실행 결과:
  - PASS
  - 에러 코드: 없음
  - 로그: /Volumes/workspace/eastsea-node/logs/tc-install-001.log
  - 재현 스텝: 설치시작 → 동의 → 다음 → 에러 없음
- 다음 액션:
  - 다음 대상: TC-INSTALL-002
  - 차단 사유: 없음
```

```
[agent=A] [시간=2026-02-25 11:10] [대상=REQ-100] [행동=Adjust]
- 상태 변경:
  - TC 상태(요약): TC-INSTALL-001~TC-INSTALL-005 중 3개 완료, 2개 대기
  - Req 상태: 진행
- 실행 결과:
  - FAIL
  - 에러 코드: ERR-PATH-WRITE
  - 로그: /Volumes/workspace/eastsea-node/logs/req100-block.log
- 다음 액션:
  - 다음 대상: TC-INSTALL-002 (재실행)
  - 차단 사유: 설치 경로 권한 미설정
```

### 수동 조작 규칙(자동 대기 항목)
- `블로킹`이면 다음 4개 조건을 넣는다:
  - 블로킹 원인
  - 재시도 조건
  - 필요 권한/자원
  - 복구 담당
