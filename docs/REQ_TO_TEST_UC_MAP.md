# 요구사항-테스트/경험 추적표 (REQ → UT → TC → UC/UX) v1.1

작성일: 2026-02-25  
목적: Transmission 스타일의 Install-and-Run 목표에서 누락 없는 추적 체계 확보

## 1) 100% 추적 표

| Req ID | UT 매핑 | TC 매핑 | UC 매핑 | UX/여정 매핑 |
|---|---|---|---|---|
| REQ-100 | UT-100-01, UT-100-02, UT-100-03 | TC-INSTALL-001, TC-INSTALL-002, TC-INSTALL-005, TC-INSTALL-006, TC-DOCKER-001 | UC-01, UC-02 | Phase 1, Phase 2 |
| REQ-101 | UT-101-01, UT-101-02 | TC-INSTALL-004, TC-INSTALL-003, TC-INSTALL-005 | UC-01, UC-06 | Phase 1 |
| REQ-102 | UT-102-01, UT-102-02 | TC-INSTALL-001, TC-UPDATE-001, TC-UPDATE-002, TC-UNINSTALL-001 | UC-04, UC-05, UC-10 | Phase 1, Phase 5 |
| REQ-103 | UT-103-01 | TC-INSTALL-006 | UC-01, UC-02 | Phase 1 |
| REQ-104 | UT-104-01 | TC-DOCKER-001 | UC-02 | Phase 2 |
| REQ-110 | UT-110-01, UT-110-02 | TC-RUN-001, TC-RUN-005, TC-ONEFLOW-001 | UC-01, UC-02 | Phase 2, Phase 3 |
| REQ-111 | UT-111-01, UT-111-02 | TC-INSTALL-003, TC-RUN-001, TC-RUN-004 | UC-06 | Phase 1, Phase 4 |
| REQ-112 | UT-112-01 | TC-SEC-003, TC-ONEFLOW-002 | UC-08, UC-01 | Phase 2, Phase 4 |
| REQ-120 | UT-120-01, UT-120-02, UT-120-03 | TC-UPDATE-001, TC-UPDATE-002, TC-UPDATE-003, TC-UPDATE-005 | UC-04, UC-05 | Phase 3, Phase 4, Phase 5 |
| REQ-121 | UT-121-01, UT-121-02, UT-121-03 | TC-RUN-001, TC-RUN-002, TC-RUN-003, TC-RUN-004, TC-RUN-005 | UC-03, UC-08 | Phase 3 |
| REQ-122 | UT-122-01 | TC-NODE-003 | UC-14 | Phase 3 |
| REQ-001 | UT-001-01, UT-001-02 | TC-SEC-001, TC-SEC-002, TC-API-001 | UC-09 | Phase 2 |
| REQ-002 | UT-002-01 | TC-SEC-001, TC-SEC-002, TC-API-001 | UC-09 | Phase 2 |
| REQ-010 | UT-010-01, UT-010-02, UT-010-03 | TC-UNINSTALL-002, TC-RUN-001, TC-UNINSTALL-001 | UC-07, UC-10 | Phase 3 |
| REQ-021 | UT-021-01 | TC-API-001, TC-API-002 | UC-01, UC-02 | Phase 2 |
| REQ-040 | UT-040-01, UT-040-02 | TC-SEC-003, TC-SEC-002 | UC-09, UC-08 | Phase 2, Phase 4 |
| REQ-050 | TC-CI-001 | TC-CI-001 | UC-12 | Phase 5 |
| REQ-051 | UT-120-01, UT-120-03, UT-120-02 | TC-UPDATE-002, TC-UPDATE-003, TC-UPDATE-005 | UC-04, UC-05 | Phase 3, Phase 4 |
| REQ-060 | TC-DOC-001 | TC-DOC-001 | UC-12 | Phase 5 |

## 2) 사용 방법
- 구현/배포 단계에서 요구사항이 완료되면 대응 행(Row)에서 해당 UT/TC/UC 모두 `[완료]`로 마크.
- 하나라도 빈칸이면 릴리즈 게이트 전까지 보강 테스트 생성이 필수.

## 3) 요구사항 커버리지(요약)
- 현재 표기 기준 커버된 Req: 18개
- 미보완 항목은 `IMPLEMENTATION_PLAN`의 4-1 산출물 검증 항목에 자동 반영.

