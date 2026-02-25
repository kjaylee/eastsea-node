# Implementation Plan (Install-and-Run)

작성일: 2026-02-25

## 1) 실행 철학
- 목표는 “설치 후 즉시 실행”.
- 모든 구현은 사용자가 문서 1페이지만 읽고도 제품을 켤 수 있다는 가정에서 설계한다.

## 2) 팀 운영 방식
- 역할
  - Product Owner: 목표/범위/Go-NoGo 결정
  - Packaging 엔지니어: 패키징/업데이트/자동설치
  - Backend 엔지니어: 서버 런타임·API·영속성
  - Infra/DevOps: CI/CD, 배포, 모니터링
  - QA: 플랫폼별 스모크 자동화

## 3) 주차별 실행

### Week 1
- [ ] REQ-100~102 범위 확정 및 담당자 매핑
- [ ] 설치 패키지 버전/네이밍/체크섬 규칙 확정
- [ ] 기본 설치 실패 패턴 분석(포트/권한/방화벽)

### Week 2
- [ ] 기본 설치 배포 파이프라인 설계(윈도우/맥/리눅스)
- [ ] 리포지토리에 패키지 템플릿 초안 추가
- [ ] 첫 실행 Onboarding 플로우 설계(Mock-free)

### Week 3
- [ ] REQ-110 영속성 초기화 및 마이그레이션 자동 적용
- [ ] 서버 시작 진단 로직(권한/포트/저장소) 구현
- [ ] 설치 후 서비스 자동 시작 smoke(로컬) 완료

### Week 4
- [ ] `src/rpc/server.zig` mock 경로 제거 계획 반영 및 검증
- [ ] 인증/에러 표준 스키마 연동
- [ ] 플랫폼별 기본 실행 테스트 1차 완료

### Week 5
- [ ] Docker run path를 install path와 동일 동작으로 정렬
- [ ] CLI installer 완성
- [ ] 업데이트 체크/다운로드 시퀀스(수동/자동) 구현

### Week 6
- [ ] 자동 업데이트 + 롤백 스크립트 구현
- [ ] 제거(언인스톨) 동작에서 잔여 데이터 정책 적용
- [ ] 스테이징에서 update+rollback 리허설 2회 수행

### Week 7
- [ ] 운영 명령(start/stop/restart)의 CLI/GUI 연동
- [ ] 장애 진단 메시지 개선 및 사용자 가이드 연결
- [ ] 로그/메트릭 기본 파이프라인 정렬

### Week 8
- [ ] 플랫폼별 스모크 테스트 자동화 (CI에서 최소 4개 아티팩트)
- [ ] 사용자 관점 1회 사용성 점검(신규 사용자 시나리오)
- [ ] 실패 시 자동 리포트 템플릿 생성

### Week 9
- [ ] API 문서 자동 배포 + 릴리즈 노트 자동화
- [ ] 설치 가이드(일반 사용자용, 터미널 없음) 작성/심사
- [ ] 지원 포인트: 네트워크 제한 환경 대응 가이드

### Week 10
- [ ] 릴리즈 후보 패키지 생성 및 검증 자동화 파이프라인 오픈
- [ ] 운영자 교육용 runbook(복구, 로그 위치, 설정 초기화) 정비
- [ ] 패치 정책(보안 패치/긴급 패치) 문서화

### Week 11
- [ ] 전 플랫폼 회귀 테스트: install-start-stop-update-rollback
- [ ] P0 누락 항목 제거(필수 수정)
- [ ] 출시 전 최종 통합 점검표 실행

### Week 12
- [ ] 릴리즈 후보(Install-and-Run) 패키지 배포
- [ ] Go/No-Go 회의 및 공개 조건 정리
- [ ] 2차 개선 백로그 생성

## 4) 통합 체크리스트(필수)
- 설치(윈도우, 맥, 리눅스, docker) 1회 실행 성공
- 첫 실행에서 기본 설정 생성 완료
- 자동 업데이트 또는 수동 업데이트 경로 확인
- 기본 API 5개 호출 성공
- 롤백 경로 1회 검증

## 4-1) 실행계획 산출물 매핑
- 요구사항 추적표: `/Volumes/workspace/eastsea-node/docs/REQ_TO_TEST_UC_MAP.md`
- 단위 테스트 전략: `/Volumes/workspace/eastsea-node/docs/UNIT_TEST_PLAN.md`
- 버튼 단위 테스트케이스: `/Volumes/workspace/eastsea-node/docs/TEST_CASES.md`
- 유즈케이스: `/Volumes/workspace/eastsea-node/docs/USE_CASES.md`
- 전체 사용자 경험지도: `/Volumes/workspace/eastsea-node/docs/TOTAL_USER_EXPERIENCE_MAP.md`
- 스펙/요구/로드맵 기반 동기화: `/Volumes/workspace/eastsea-node/docs/PRODUCT_SPEC.md`, `/Volumes/workspace/eastsea-node/docs/REQ_MATRIX.md`, `/Volumes/workspace/eastsea-node/docs/ROADMAP.md`

## 5) 리스크와 대응
- 패키징 도구/서명 이슈: 사전 PoC와 동일 포맷 유지
- 운영체제 API 변경: 주차 1~2에 호환성 matrix 고정
- 설치 실패 문의 폭증: 문구/로그 개선 + 자동 진단 강화
- 릴리즈 지연: 기능 동결 + 설치성만 최우선 진행

## 6) 즉시 수행 항목(다음 24h)
1. `REQ_MATRIX`에 플랫폼별 담당자 할당(Windows/macOS/Linux/Docker).
2. 패키징 결과물을 저장하는 CI 산출물 경로 정의.
3. 스모크 테스트 스크립트 기준: `install -> run -> /api/v1/status -> stop`.
4. 설치 실패 원인별 메시지 표준안 작성(포트/권한/권한승인/방화벽).
5. 첫 실행 온보딩 기본값(포트/데이터 경로/보안 키) 결정.
