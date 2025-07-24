# Eastsea Clone in Zig - TODO List

## Phase 1: 프로젝트 기초 설정
- [x] Zig 프로젝트 초기화
- [x] build.zig 설정
- [x] 기본 디렉토리 구조 생성
- [x] 개발 환경 설정

## Phase 2: 핵심 데이터 구조
- [x] Account 구조체 정의
- [x] Transaction 구조체 정의
- [x] Block 구조체 정의
- [x] Hash 및 암호화 유틸리티
- [x] Merkle Tree 구현

## Phase 3: 블록체인 기본 기능
- [x] Genesis Block 생성
- [x] Block 검증 로직
- [x] Transaction 검증 로직
- [x] 블록체인 상태 관리
- [x] 계정 잔액 추적

## Phase 4: 네트워킹
- [x] P2P 네트워크 기본 구조
- [x] 노드 간 통신 프로토콜
- [x] 블록 전파 메커니즘
- [x] 트랜잭션 풀 관리
- [x] 실제 TCP 소켓 통신 구현
- [x] 메시지 직렬화/역직렬화
- [x] 피어 연결 관리
- [x] 핸드셰이크 프로토콜

## Phase 4.5: 고급 P2P 네트워킹 (자동 피어 발견)
- [x] DHT (Distributed Hash Table) 구현
- [x] Bootstrap 노드 시스템
- [x] mDNS 로컬 피어 발견
- [x] UPnP 자동 포트 포워딩
- [🚧] NAT 통과 (STUN/TURN) - STUN 클라이언트 구현 완료, 테스트 중
- [x] 자동 피어 발견 및 연결
- [x] 포트 스캔을 통한 로컬 네트워크 탐색
- [x] 브로드캐스트/멀티캐스트 피어 공지
- [ ] Tracker 서버 (선택적 중앙 피어 목록)

## Phase 5: 합의 메커니즘 (Proof of History 기반)
- [x] SHA-256 기반 시퀀스 생성
- [x] Proof of History 검증
- [x] Leader 선출 메커니즘
- [x] Fork 해결 로직

## Phase 6: 스마트 컨트랙트 (Programs)
- [🚧] 기본 프로그램 인터페이스 - 구현 완료, 테스트 중
- [🚧] 프로그램 실행 환경 - 구현 완료, 테스트 중
- [🚧] 시스템 프로그램들 - 기본 구현 완료
- [ ] 사용자 정의 프로그램 지원

## Phase 7: RPC API
- [x] JSON-RPC 서버
- [x] 기본 API 엔드포인트
- [x] 트랜잭션 제출
- [x] 계정 정보 조회

## Phase 8: CLI 도구
- [x] 지갑 기능
- [x] 키 생성 및 관리
- [x] 트랜잭션 생성 도구
- [x] 네트워크 상태 조회

## Phase 9: 테스트 및 최적화
- [x] 단위 테스트 작성
- [x] 통합 테스트 (P2P, DHT, mDNS, Bootstrap)
- [ ] 성능 최적화
- [x] 메모리 관리 최적화
- [ ] 부하 테스트
- [ ] 네트워크 장애 시나리오 테스트
- [ ] 보안 테스트

### 🧪 개발 중 테스트 체크리스트

#### 코드 변경 후 필수 테스트 (매번 실행)
- [ ] `zig build` - 컴파일 오류 확인
- [ ] `zig build test` - 단위 테스트 통과
- [ ] `zig build run` - 기본 기능 동작 확인

#### 네트워킹 기능 변경 시
- [ ] `zig build run-p2p -- 8000` - P2P 단일 노드 테스트
- [ ] 멀티 노드 P2P 테스트 (2개 터미널)
  - [ ] 터미널 1: `zig build run-p2p -- 8000`
  - [ ] 터미널 2: `zig build run-p2p -- 8001 8000`
- [ ] DHT 네트워크 테스트
  - [ ] 터미널 1: `zig build run-dht -- 8000`
  - [ ] 터미널 2: `zig build run-dht -- 8001 8000`

#### 피어 발견 기능 변경 시
- [ ] `zig build run-mdns -- 8000` - mDNS 테스트
- [ ] `zig build run-bootstrap -- 8000` - Bootstrap 테스트
- [ ] `zig build run-upnp -- 8000` - UPnP 포트 포워딩 테스트
- [ ] `zig build run-port-scan -- 8000` - 포트 스캔 테스트
- [ ] `zig build run-broadcast -- 8000` - 브로드캐스트 공지 테스트
- [ ] `zig build run-auto-discovery -- 8000` - 통합 자동 발견 테스트

#### 블록체인 코어 기능 변경 시
- [ ] 블록 생성 및 검증 테스트
- [ ] 트랜잭션 처리 테스트
- [ ] 합의 메커니즘 테스트
- [ ] 지갑 기능 테스트

#### 성능 관련 변경 시
- [ ] `zig build -Doptimize=ReleaseFast` - 최적화 빌드
- [ ] 메모리 누수 검사 (`zig build run -Doptimize=Debug`)
- [ ] 네트워크 처리량 테스트

#### 릴리즈 전 최종 테스트
- [ ] 모든 빌드 타겟 테스트
  - [ ] `zig build run`
  - [ ] `zig build run-prod`
  - [ ] `zig build run-p2p`
  - [ ] `zig build run-dht`
  - [ ] `zig build run-bootstrap`
  - [ ] `zig build run-mdns`
  - [ ] `zig build run-auto-discovery`
  - [ ] `zig build run-port-scan`
  - [ ] `zig build run-broadcast`
- [ ] 단위 테스트 통과: `zig build test`
- [ ] 메모리 안전성 확인
- [ ] 다양한 시나리오에서 안정성 테스트

### 📝 테스트 실행 예시

#### 기본 워크플로우
```bash
# 1. 코드 변경 후
zig build                    # 컴파일 확인
zig build test              # 단위 테스트
zig build run               # 통합 테스트

# 2. P2P 기능 테스트 (멀티 터미널)
# 터미널 1:
zig build run-p2p -- 8000

# 터미널 2:
zig build run-p2p -- 8001 8000

# 3. DHT 기능 테스트 (멀티 터미널)  
# 터미널 1:
zig build run-dht -- 8000

# 터미널 2:
zig build run-dht -- 8001 8000
```

#### 성능 및 메모리 테스트
```bash
# 릴리즈 빌드 테스트
zig build -Doptimize=ReleaseFast
zig build run

# 메모리 안전성 테스트
zig build -Doptimize=Debug
zig build run
```
### 🔄 Git 워크플로우 및 자동화

#### 테스트 후 Git 작업 자동화
- [ ] `test-and-push.sh` 스크립트 생성
- [ ] Git hooks 설정 (pre-commit 테스트)
- [ ] `.gitignore` 최적화 (.zig-cache, zig-out 제외)
- [ ] 커밋 메시지 템플릿 작성
- [ ] GitHub Actions CI/CD 설정

#### 개발 워크플로우 표준화
- [ ] 코드 변경 후 필수 테스트 시퀀스 정의
- [ ] 브랜치 전략 수립 (main, develop, feature branches)
- [ ] Pull Request 템플릿 작성
- [ ] 코드 리뷰 가이드라인 작성
- [ ] 릴리즈 프로세스 정의

#### Git 작업 체크리스트 (매 커밋 시)
- [ ] `zig build` - 컴파일 확인 ✅
- [ ] `zig build test` - 단위 테스트 통과 ✅
- [ ] `zig build run` - 통합 테스트 실행 ✅
- [ ] 소스 파일만 스테이징 (빌드 캐시 제외) ✅
- [ ] 의미있는 커밋 메시지 작성 ✅
- [ ] `git push origin main` - 원격 저장소 푸시 ✅

## Phase 10: 문서화
- [ ] API 문서
- [ ] 사용자 가이드
- [ ] 개발자 문서
- [ ] 예제 코드

## 현재 진행 상황
- ✅ Phase 1-5, 7-8 완료!
- ✅ Phase 4: 기본 P2P 네트워킹 완료!
- ✅ Phase 4.5: 고급 P2P 네트워킹 (자동 피어 발견) - DHT, Bootstrap, mDNS, UPnP 구현 완료!
- 🚧 Phase 4.5: NAT 통과 (STUN/TURN) - STUN 클라이언트 구현 완료, 테스트 중
- 🚧 Phase 6: 스마트 컨트랙트 (Programs) - 기본 인터페이스 및 실행 환경 구현 완료
- 🚀 기본적인 Eastsea 클론이 성공적으로 구현됨
- 다음 단계: Phase 9 성능 최적화 또는 Phase 10 문서화

## 구현된 주요 기능
✅ **블록체인 코어**
- Genesis 블록 생성 및 블록 체인 관리
- 트랜잭션 처리 및 검증
- 블록 마이닝 (PoW 기반)
- 머클 트리를 통한 트랜잭션 무결성

✅ **Proof of History 합의**
- SHA-256 기반 시퀀스 생성
- PoH 검증 메커니즘
- 리더 스케줄링 및 슬롯 처리
- 트랜잭션과 PoH 시퀀스 통합

✅ **P2P 네트워킹**
- 노드 관리 및 피어 디스커버리
- 메시지 브로드캐스팅
- 핸드셰이크 및 핑/퐁 프로토콜
- 실제 TCP 소켓 통신
- 메시지 직렬화/역직렬화
- 체크섬 기반 메시지 무결성 검증
- 피어 연결 상태 관리
- DHT (Distributed Hash Table) 기반 자동 피어 발견
- Bootstrap 노드 시스템
- mDNS 로컬 피어 발견
- UPnP 자동 포트 포워딩

🚧 **NAT 통과 및 고급 네트워킹**
- STUN 클라이언트 구현 (공인 IP 발견)
- NAT 타입 감지 및 분석
- 다중 STUN 서버 지원

🚧 **스마트 컨트랙트 (Programs)**
- 기본 프로그램 인터페이스 및 실행 환경
- 시스템 프로그램 (계정 생성, 전송)
- 토큰 프로그램 (민트, 계정, 전송)
- Hello World 예제 프로그램
- 프로그램 결과 로깅 및 오류 처리

✅ **JSON-RPC API**
- 블록 높이 조회
- 계정 잔액 조회
- 트랜잭션 제출
- 노드 정보 조회
- 피어 목록 조회

✅ **CLI 지갑**
- 키 페어 생성
- 계정 관리
- 트랜잭션 생성 및 서명
- 잔액 조회 및 전송

## 참고사항
- 각 Phase는 독립적으로 테스트 가능해야 함
- 코드는 모듈화하여 재사용성 높이기
- 메모리 안전성과 성능 고려
- Zig의 comptime 기능 적극 활용

## 성능 통계 (데모 실행 결과)
- 블록체인 높이: 2 블록
- PoH 틱 처리: 129회
- 네트워크 피어: 3개
- 지갑 계정: 2개
- 모든 테스트 통과 ✅