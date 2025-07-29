# Eastsea User Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Basic Operations](#basic-operations)
5. [Network Participation](#network-participation)
6. [Wallet Management](#wallet-management)
7. [Smart Contracts](#smart-contracts)
8. [Advanced Features](#advanced-features)
9. [Troubleshooting](#troubleshooting)
10. [FAQ](#faq)

---

## Introduction

Eastsea는 Zig 언어로 구현된 현대적인 블록체인 플랫폼입니다. 다음과 같은 특징을 제공합니다:

### 🌟 주요 특징

- **⚡ 빠른 처리 속도**: Proof of History 합의 메커니즘으로 높은 처리량 달성
- **🌐 자동 네트워크 발견**: DHT, mDNS, UPnP를 통한 자동 피어 연결
- **🔒 강력한 보안**: ECDSA 디지털 서명 및 SHA-256 해싱
- **💡 스마트 컨트랙트**: 사용자 정의 프로그램 실행 지원
- **🔧 개발자 친화적**: 완전한 JSON-RPC API 제공
- **🚀 고성능 네트워킹**: TCP/QUIC 하이브리드 프로토콜 지원
- **✅ 신뢰 기반 시스템**: Eastsea Attestation Service (EAS) 지원

### 🎯 사용 사례

- **개발자**: 블록체인 애플리케이션 개발 및 테스트
- **연구자**: 분산 시스템 및 합의 알고리즘 연구
- **교육**: 블록체인 기술 학습 및 실습
- **기업**: 프라이빗 블록체인 네트워크 구축

---

## Installation

### System Requirements

- **Operating System**: macOS, Linux, Windows
- **Memory**: 최소 4GB RAM (8GB 권장)
- **Storage**: 최소 1GB 여유 공간
- **Network**: 인터넷 연결 (P2P 네트워크 참여용)
- **QUIC Support**: 최신 네트워크 스택 (QUIC/HTTP3 지원)
- **EAS Support**: 증명 생성 및 검증을 위한 암호화 기능

### Prerequisites

1. **Zig 0.14+ 설치**

   **macOS (Homebrew)**:
   ```bash
   brew install zig
   ```

   **Linux**:
   ```bash
   # Download and extract Zig
   wget https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz
   tar -xf zig-linux-x86_64-0.14.0.tar.xz
   
   # Add to PATH
   export PATH=$PATH:$(pwd)/zig-linux-x86_64-0.14.0
   ```

   **Windows**:
   1. [Zig 공식 사이트](https://ziglang.org/download/)에서 Windows 버전 다운로드
   2. 압축 해제 후 PATH에 추가

2. **Git 설치** (소스 코드 다운로드용)

### Building from Source

```bash
# 1. 소스 코드 다운로드
git clone <repository-url>
cd eastsea-zig

# 2. 프로젝트 빌드
zig build

# 3. 설치 확인
zig build test
```

### Pre-built Binaries (향후 제공 예정)

```bash
# 바이너리 다운로드 및 설치
curl -L https://github.com/eastsea/releases/latest/download/eastsea-linux.tar.gz | tar xz
sudo mv eastsea /usr/local/bin/
```

---

## Quick Start

### 1. 첫 번째 노드 실행

```bash
# 기본 데모 실행 (모든 기능 체험)
zig build run
```

실행하면 다음과 같은 과정이 자동으로 진행됩니다:

1. ✅ 블록체인 초기화
2. 📦 제네시스 블록 생성
3. 🌐 P2P 노드 시작 (포트 8000)
4. 🔗 DHT 네트워크 초기화
5. ⚡ Proof of History 합의 시작
6. 🚀 RPC 서버 시작 (포트 8545)
7. 🎯 데모 시퀀스 실행

### 2. 프로덕션 노드 실행

```bash
# 프로덕션 환경용 노드
zig build run-prod
```

### 3. 네트워크 참여

```bash
# 터미널 1: 첫 번째 노드
zig build run-p2p -- 8000

# 터미널 2: 두 번째 노드 (첫 번째 노드에 연결)
zig build run-p2p -- 8001 8000

# 터미널 3: 세 번째 노드 (네트워크에 참여)
zig build run-p2p -- 8002 8000
```

---

## Basic Operations

### 1. 블록체인 상태 조회

#### JSON-RPC API 사용

```bash
# 현재 블록 높이 조회
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "getBlockHeight",
    "params": [],
    "id": 1
  }'

# 응답 예시
{
  "jsonrpc": "2.0",
  "result": 42,
  "error": null,
  "id": 1
}
```

#### 노드 정보 조회

```bash
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "getNodeInfo",
    "params": [],
    "id": 2
  }'

# 응답 예시
{
  "jsonrpc": "2.0",
  "result": {
    "address": "127.0.0.1",
    "port": 8000,
    "peer_count": 3,
    "is_running": true,
    "blockchain_height": 42
  },
  "error": null,
  "id": 2
}
```

### 2. 계정 및 잔액 관리

#### 계정 잔액 조회

```bash
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "getBalance",
    "params": ["ff7580ebeca78b5468b42e182fff7e8e820c37c3"],
    "id": 3
  }'

# 응답 예시
{
  "jsonrpc": "2.0",
  "result": 1000,
  "error": null,
  "id": 3
}
```

### 3. 트랜잭션 처리

#### 트랜잭션 전송

```bash
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "sendTransaction",
    "params": {
      "from": "ff7580ebeca78b5468b42e182fff7e8e820c37c3",
      "to": "0e56ad656c29a51263df1ca8e1a2d6169e95db51",
      "amount": 100,
      "signature": "abcd1234..."
    },
    "id": 4
  }'

# 응답 예시
{
  "jsonrpc": "2.0",
  "result": "0x1234567890abcdef",
  "error": null,
  "id": 4
}
```

---

## Network Participation

### 1. P2P 네트워크 참여

#### 단일 노드 시작

```bash
# 포트 8000에서 노드 시작
zig build run-p2p -- 8000
```

출력 예시:
```
🌐 P2P Node started on 127.0.0.1:8000
🆔 Node ID: a1b2c3d4e5f6...
📡 Listening for connections...
```

#### 기존 노드에 연결

```bash
# 포트 8001에서 시작하고 8000 노드에 연결
zig build run-p2p -- 8001 8000
```

출력 예시:
```
🌐 P2P Node started on 127.0.0.1:8001
🆔 Node ID: f6e5d4c3b2a1...
🔗 Connecting to peer 127.0.0.1:8000...
✅ Connected to peer a1b2c3d4e5f6...
```

### 2. DHT 네트워크 참여

#### DHT 노드 시작

```bash
# DHT 네트워크 시작
zig build run-dht -- 8000
```

#### DHT 네트워크 참여

```bash
# 기존 DHT 네트워크에 참여
zig build run-dht -- 8001 8000
```

출력 예시:
```
🔗 DHT initialized
🔍 Bootstrapping DHT with 127.0.0.1:8000
✅ DHT bootstrap complete. Routing table has 1 nodes
📊 DHT Node Info:
   Node ID: 03f6d7ba09b0531a...
   Address: 127.0.0.1:8001
   Total nodes in routing table: 1
```

### 3. 자동 피어 발견

#### mDNS 로컬 발견

```bash
# mDNS를 통한 로컬 네트워크 피어 발견
zig build run-mdns -- 8000
```

#### 통합 자동 발견

```bash
# 모든 발견 방법을 사용한 자동 피어 연결
zig build run-auto-discovery -- 8000
```

이 명령은 다음 방법들을 자동으로 시도합니다:
- mDNS 로컬 발견
- DHT 네트워크 참여
- Bootstrap 노드 연결
- UPnP 포트 포워딩
- 포트 스캔을 통한 로컬 피어 발견

---

## Wallet Management

### 1. 지갑 기본 사용법

Eastsea는 내장된 지갑 시스템을 제공합니다. 데모 실행 시 자동으로 테스트 계정이 생성됩니다.

#### 계정 생성 과정 (내부적으로 수행)

```
🔑 New account created: ff7580ebeca78b5468b42e182fff7e8e820c37c3
🔑 New account created: 0e56ad656c29a51263df1ca8e1a2d6169e95db51
```

#### 지갑 상태 확인

```
📋 Wallet Accounts:
  1. ff7580ebeca78b5468b42e182fff7e8e820c37c3 (Balance: 1000)
  2. 0e56ad656c29a51263df1ca8e1a2d6169e95db51 (Balance: 500)
```

### 2. 토큰 전송

#### 지갑 간 전송 (데모에서 자동 실행)

```
💸 Transfer: ff7580ebeca78b5468b42e182fff7e8e820c37c3 -> 0e56ad656c29a51263df1ca8e1a2d6169e95db51 (50 units)
💰 Wallet transfer completed
✍️  Transaction signed: 00f246cc83033a6f
```

#### API를 통한 전송

```bash
# 트랜잭션 생성 및 전송
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "sendTransaction",
    "params": {
      "from": "ff7580ebeca78b5468b42e182fff7e8e820c37c3",
      "to": "0e56ad656c29a51263df1ca8e1a2d6169e95db51",
      "amount": 100
    },
    "id": 1
  }'
```

### 3. 보안 고려사항

- **개인키 보안**: 개인키는 안전한 곳에 보관하세요
- **서명 검증**: 모든 트랜잭션은 디지털 서명으로 보호됩니다
- **네트워크 보안**: P2P 통신은 체크섬으로 무결성을 검증합니다

---

## Smart Contracts

### 1. 기본 프로그램 사용

#### 시스템 프로그램 테스트

```bash
# 기본 프로그램 기능 테스트
zig build run-programs
```

#### 사용자 정의 프로그램 테스트

```bash
# 모든 사용자 정의 프로그램 테스트
zig build run-custom-programs -- all
```

### 2. 개별 프로그램 실행

#### 카운터 프로그램

```bash
# 카운터 프로그램 실행
zig build run-custom-programs -- counter
```

출력 예시:
```
🧮 Counter Program Demo
=======================
Initial count: 0
After increment: 1
After increment: 2
After decrement: 1
Final count: 1
```

#### 계산기 프로그램

```bash
# 계산기 프로그램 실행
zig build run-custom-programs -- calculator
```

출력 예시:
```
🧮 Calculator Program Demo
===========================
10 + 5 = 15
10 - 5 = 5
10 * 5 = 50
10 / 5 = 2
```

#### 투표 프로그램

```bash
# 투표 프로그램 실행
zig build run-custom-programs -- voting
```

출력 예시:
```
🗳️ Voting Program Demo
=======================
Created proposal: "Increase block size"
Vote from Alice: Yes
Vote from Bob: No
Vote from Charlie: Yes
Final results: Yes: 2, No: 1
```

#### 토큰 스왑 프로그램

```bash
# 토큰 스왑 프로그램 실행
zig build run-custom-programs -- token-swap
```

출력 예시:
```
💱 Token Swap Program Demo
===========================
Created liquidity pool: TokenA/TokenB
Added liquidity: 1000 TokenA, 1000 TokenB
Swapped 100 TokenA for 90 TokenB
Pool balance: 1100 TokenA, 910 TokenB
```

### 3. 성능 벤치마크

```bash
# 프로그램 성능 테스트
zig build run-custom-programs -- benchmark
```

출력 예시:
```
⚡ Custom Programs Performance Benchmark
========================================
Counter Program: 1000 operations in 1.23ms (avg: 0.001ms)
Calculator Program: 1000 operations in 2.45ms (avg: 0.002ms)
Voting Program: 1000 operations in 3.67ms (avg: 0.004ms)
Token Swap Program: 1000 operations in 4.89ms (avg: 0.005ms)
```

---

## Advanced Features

### 1. UPnP 자동 포트 포워딩

```bash
# UPnP를 통한 자동 포트 포워딩 테스트
zig build run-upnp -- 8000
```

이 기능은 NAT 뒤에 있는 노드가 외부에서 접근 가능하도록 자동으로 포트를 포워딩합니다.

### 2. STUN을 통한 NAT 통과

```bash
# STUN 클라이언트 테스트
zig build run-stun
```

STUN 서버를 통해 공인 IP 주소를 발견하고 NAT 타입을 분석합니다.

### 3. Tracker 서버/클라이언트

#### Tracker 서버 시작

```bash
# 중앙 피어 목록 관리 서버 시작
zig build run-tracker -- server 7000
```

#### Tracker 클라이언트 연결

```bash
# Tracker 서버에 연결하여 피어 목록 가져오기
zig build run-tracker -- client 8001 7000
```

### 4. 포트 스캔을 통한 피어 발견

```bash
# 로컬 네트워크에서 활성 노드 스캔
zig build run-port-scan -- 8000
```

### 5. 브로드캐스트/멀티캐스트 공지

```bash
# 네트워크에 노드 존재 공지
zig build run-broadcast -- 8000
```

### 6. QUIC 네트워크 테스트

Eastsea는 TCP와 QUIC 프로토콜을 모두 지원하는 하이브리드 네트워킹을 사용합니다. 
QUIC는 다음과 같은 고급 기능을 제공합니다:

- **Multiplexed Streams**: 여러 스트림을 동시에 사용하여 블록과 트랜잭션을 병렬로 전송
- **0-RTT Connection Resumption**: 연결 재개 시 지연 시간 최소화
- **Connection Migration**: IP 주소 변경 시 연결 유지
- **Enhanced Security**: 연결 ID 암호화 및 패킷 인증

#### QUIC 기본 연결 테스트

```bash
# QUIC 기본 연결 테스트
zig-out/bin/quic-test basic
```

#### QUIC 멀티 스트림 테스트

```bash
# QUIC 멀티 스트림 기능 테스트
zig-out/bin/quic-test streams
```

#### QUIC 보안 기능 테스트

```bash
# QUIC 보안 기능 테스트
zig-out/bin/quic-test security
```

#### QUIC 성능 벤치마크

```bash
# QUIC 성능 벤치마크 테스트
zig-out/bin/quic-test performance
```

#### 전체 QUIC 테스트

```bash
# QUIC 모든 기능 테스트
zig-out/bin/quic-test all
```

### 7. Eastsea Attestation Service (EAS) 테스트

Eastsea Attestation Service는 오프체인 데이터 검증을 위한 시스템입니다.

#### EAS 기본 기능 테스트

```bash
# EAS 기본 기능 테스트
zig build run-eas -- basic
```

#### EAS 스키마 관리 테스트

```bash
# EAS 스키마 등록 및 관리 테스트
zig build run-eas -- schema
```

#### EAS 증명자 관리 테스트

```bash
# EAS 증명자 등록 및 관리 테스트
zig build run-eas -- attester
```

#### EAS 증명 생성 및 관리 테스트

```bash
# EAS 증명 생성 및 관리 테스트
zig build run-eas -- attestation
```

#### EAS 증명 검증 테스트

```bash
# EAS 증명 검증 테스트
zig build run-eas -- verification
```

#### EAS 평판 시스템 테스트

```bash
# EAS 증명자 평판 시스템 테스트
zig build run-eas -- reputation
```

#### 전체 EAS 테스트

```bash
# EAS 모든 기능 테스트
zig build run-eas -- all
```

---

## FAQ

## Troubleshooting

### 일반적인 문제 해결

#### 1. 빌드 오류

```bash
# 캐시 정리 후 재빌드
rm -rf .zig-cache zig-out
zig build
```

#### 2. 포트 충돌

```bash
# 사용 중인 포트 확인
lsof -i :8000

# 다른 포트 사용
zig build run-p2p -- 8001
```

#### 3. 네트워크 연결 문제

```bash
# 방화벽 설정 확인 (macOS)
sudo pfctl -sr | grep 8000

# 네트워크 연결 테스트
nc -zv 127.0.0.1 8000
```

#### 4. 메모리 문제

```bash
# 디버그 모드로 실행하여 메모리 사용량 확인
zig build run -Doptimize=Debug
```

### 성능 최적화

#### 1. 릴리즈 모드 빌드

```bash
# 최적화된 빌드
zig build -Doptimize=ReleaseFast
zig build run
```

#### 2. 메모리 사용량 모니터링

```bash
# 시스템 리소스 모니터링 (macOS)
top -pid $(pgrep eastsea)

# 메모리 프로파일링 (Linux)
valgrind --tool=massif zig build run
```

### 로그 및 디버깅

#### 1. 상세 로그 출력

```bash
# 디버그 정보와 함께 실행
ZIG_LOG_LEVEL=debug zig build run
```

#### 2. 네트워크 트래픽 모니터링

```bash
# 네트워크 패킷 캡처 (tcpdump)
sudo tcpdump -i lo0 port 8000

# Wireshark를 사용한 패킷 분석
wireshark -i lo0 -f "port 8000"
```

---

## FAQ

### Q1: Eastsea는 실제 암호화폐인가요?

A: 아니요, Eastsea는 교육 및 연구 목적의 블록체인 클론입니다. 실제 가치를 가진 암호화폐가 아닙니다.

### Q2: 다른 블록체인과 호환되나요?

A: Eastsea는 독립적인 블록체인으로, 다른 블록체인과 직접 호환되지 않습니다. 하지만 JSON-RPC API는 표준을 따릅니다.

### Q3: 프로덕션 환경에서 사용할 수 있나요?

A: 현재 버전은 개발 및 테스트 목적으로 설계되었습니다. 프로덕션 사용을 위해서는 추가적인 보안 검토와 최적화가 필요합니다.

### Q4: Windows에서 실행할 수 있나요?

A: 네, Zig는 크로스 플랫폼을 지원하므로 Windows에서도 실행 가능합니다. 다만 일부 네트워크 기능은 플랫폼별 차이가 있을 수 있습니다.

### Q5: 사용자 정의 프로그램을 어떻게 만드나요?

A: `src/programs/custom_program.zig` 파일을 참조하여 새로운 프로그램을 작성할 수 있습니다. 자세한 내용은 개발자 가이드를 참조하세요.

### Q6: 네트워크에 참여하는 노드 수에 제한이 있나요?

A: 기술적으로는 제한이 없지만, 현재 구현은 소규모 네트워크에 최적화되어 있습니다. 대규모 네트워크를 위해서는 추가 최적화가 필요합니다.

### Q7: 데이터는 어디에 저장되나요?

A: 현재 버전은 메모리 내 저장을 사용합니다. 영구 저장을 위해서는 추가 구현이 필요합니다.

### Q8: 합의 메커니즘은 어떻게 작동하나요?

A: Eastsea는 Proof of History (PoH) 합의 메커니즘을 사용합니다. 이는 시간 순서를 암호학적으로 증명하여 높은 처리량을 달성합니다.

### Q9: API 문서는 어디에서 찾을 수 있나요?

A: `docs/API.md` 파일에서 완전한 API 문서를 확인할 수 있습니다.

### Q10: 기여하고 싶은데 어떻게 시작하나요?

A: `docs/DEVELOPER_GUIDE.md` 파일의 기여 가이드라인을 참조하세요. 이슈 리포트나 풀 리퀘스트를 통해 기여할 수 있습니다.

---

## Support

### 도움이 필요하신가요?

- **GitHub Issues**: 버그 리포트 및 기능 요청
- **Documentation**: `docs/` 디렉토리의 상세 문서
- **Community**: Zig 커뮤니티 포럼 및 Discord

### 추가 리소스

- [Zig 공식 문서](https://ziglang.org/documentation/)
- [블록체인 기술 개요](https://en.wikipedia.org/wiki/Blockchain)
- [Proof of History 설명](https://medium.com/solana-labs/proof-of-history-a-clock-for-blockchain-cf47a61a9274)

---

## License

Eastsea는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 LICENSE 파일을 참조하세요.