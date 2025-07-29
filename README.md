# 🌊 Eastsea - Zig 블록체인 클론

> **Solana 스타일의 고성능 블록체인을 Zig 언어로 구현한 프로젝트**

Eastsea는 Proof of History 합의 메커니즘과 완전한 P2P 네트워킹을 갖춘 실용적인 블록체인 구현체입니다. 시스템 프로그래밍에 최적화된 Zig 언어로 개발되어 높은 성능과 메모리 안전성을 제공합니다.

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]() 
[![Zig Version](https://img.shields.io/badge/zig-0.14-blue)]() 
[![License](https://img.shields.io/badge/license-MIT-green)]()

---

## ✨ 주요 특징

### 🚀 **고성능 블록체인**
- **Proof of History 합의**: Solana 스타일의 빠른 합의 메커니즘
- **Zig 언어**: 메모리 안전성과 최적화된 성능
- **스마트 컨트랙트**: Program 기반 실행 환경
- **Eastsea Attestation Service**: 오프체인 데이터 검증 시스템 (프라이버시 기능 포함)

### 🌐 **완전한 P2P 네트워킹**
- **실제 TCP/QUIC 통신**: 메시지 직렬화/역직렬화 및 체크섬 검증
- **자동 피어 발견**: DHT, mDNS, UPnP, Bootstrap 시스템
- **NAT 통과**: STUN 클라이언트 및 자동 포트 포워딩
- **Eastsea Attestation Service**: 오프체인 데이터 검증 및 프라이버시 기능

### 🛠️ **개발자 친화적**
- **포괄적 문서화**: API, 가이드, 예제 완비
- **모듈형 설계**: 독립적 테스트 가능한 컴포넌트
- **상세한 테스트**: 단위/통합/성능/보안 테스트 프레임워크
- **실제 사용 사례**: 신원, 자산, 평판 증명 구현

---

## 🚀 빠른 시작

### 필수 요구사항
- **Zig 0.14+** ([설치 가이드](https://ziglang.org/download/))
- **Git**
- **네트워크 권한** (P2P 테스트용)

### 1분 빌드 & 실행
```bash
# 저장소 클론
git clone <repository-url>
cd forge-test-007-zig

# 빌드 & 실행
zig build run
```

### 핵심 기능 체험
```bash
# P2P 네트워크 테스트 (2개 터미널)
zig build run-p2p -- 8000        # 터미널 1
zig build run-p2p -- 8001 8000   # 터미널 2

# DHT 네트워크 테스트
zig build run-dht -- 8000        # 터미널 1  
zig build run-dht -- 8001 8000   # 터미널 2

# 스마트 컨트랙트 테스트
zig build run-custom-programs -- all
```

---

## 📖 문서

| 문서 | 대상 | 내용 |
|------|------|------|
| **[사용자 가이드](docs/USER_GUIDE.md)** | 👤 일반 사용자 | 설치, 기본 사용법, 지갑 관리 |
| **[개발자 가이드](docs/DEVELOPER_GUIDE.md)** | 👨‍💻 개발자 | 아키텍처, 개발 워크플로우, 기여 방법 |
| **[API 문서](docs/API.md)** | 🔌 통합 개발자 | JSON-RPC API, P2P 프로토콜 |
| **[코드 예제](docs/EXAMPLES.md)** | 💡 학습자 | 실용적인 사용 패턴 및 고급 기능 |

---

## 🛠️ 개발 워크플로우

### 코드 변경 후 필수 체크
```bash
zig build           # 컴파일 확인
zig build test      # 단위 테스트
zig build run       # 통합 테스트
```

### 주요 빌드 타겟
| 명령어 | 기능 | 용도 |
|--------|------|------|
| `zig build run` | 통합 데모 | 전체 기능 체험 |
| `zig build run-prod` | 프로덕션 노드 | 실제 네트워크 참여 |
| `zig build run-p2p -- <port> [peer]` | P2P 테스트 | 네트워크 연결 테스트 |
| `zig build run-dht -- <port> [peer]` | DHT 테스트 | 분산 해시 테이블 |
| `zig build run-custom-programs -- <type>` | 스마트 컨트랙트 | Program 실행 |
| `zig build test` | 테스트 실행 | 모든 단위 테스트 |

### 고급 네트워킹 테스트
```bash
# 자동 피어 발견
zig build run-auto-discovery -- 8000

# UPnP 포트 포워딩
zig build run-upnp -- 8000

# mDNS 로컬 발견
zig build run-mdns -- 8000

# Tracker 서버/클라이언트
zig build run-tracker -- server 7000
zig build run-tracker -- client 8001 7000
```

---

## 🏗️ 프로젝트 구조

```
eastsea/
├── src/
│   ├── blockchain/          # 블록체인 핵심 로직
│   ├── network/            # P2P 네트워킹 (DHT, mDNS, UPnP)
│   ├── consensus/          # Proof of History 합의
│   ├── crypto/             # 암호화 및 해시 함수
│   ├── programs/           # 스마트 컨트랙트 시스템
│   ├── rpc/               # JSON-RPC API 서버
│   ├── cli/               # 명령줄 도구
│   ├── eas/               # Eastsea Attestation Service
│   └── testing/           # 테스트 프레임워크
├── docs/                  # 문서화
├── build.zig             # 빌드 설정
└── TODO.md               # 개발 로드맵 (22개 Phase)
```

---

### 🧪 테스트 및 품질 보증

### 테스트 커버리지
- ✅ **단위 테스트**: 핵심 로직 검증
- ✅ **통합 테스트**: P2P 네트워크, DHT, 합의
- ✅ **성능 테스트**: 벤치마킹 프레임워크
- ✅ **보안 테스트**: 암호화 및 네트워크 보안
- ✅ **복원력 테스트**: 네트워크 장애 시나리오
- ✅ **EAS 테스트**: 오프체인 증명 시스템
- ✅ **Bootstrap 테스트 종료**: 테스트가 정상적으로 종료되도록 수정

### 개발자를 위한 테스트 가이드
```bash
# 기본 개발 워크플로우
zig build && zig build test && zig build run

# 네트워킹 기능 검증 (멀티 터미널)
zig build run-p2p -- 8000 &
zig build run-p2p -- 8001 8000

# EAS 기능 검증
zig build run-eas -- all

# EAS 실제 사용 사례 검증
zig build run-eas-use-cases -- all

# 성능 벤치마크
zig build -Doptimize=ReleaseFast
zig build run-custom-programs -- benchmark
```

---

### 🎯 사용 사례

### 🎓 **교육 및 학습**
- 블록체인 기술 학습용 참고 구현
- P2P 네트워킹 및 분산 시스템 연구
- Zig 언어 고급 프로젝트 사례
- 오프체인 증명 시스템 학습
- **실제 사용 사례 구현 예제** (신원, 자산, 평판 증명)

### 🔬 **연구 및 개발**
- 합의 알고리즘 실험 플랫폼
- 네트워크 프로토콜 프로토타이핑
- 성능 최적화 연구
- EAS 기반 신뢰 시스템 연구
- **프라이버시 보호 기술 연구**

### 🚀 **상용 개발**
- 커스텀 블록체인 개발 기반
- P2P 애플리케이션 네트워킹 라이브러리
- 분산 시스템 컴포넌트
- 신뢰 기반 애플리케이션
- **신원 및 자산 검증 시스템**

---

## 🤝 기여하기

이 프로젝트는 오픈소스 기여를 환영합니다!

### 기여 방법
1. **이슈 리포트**: 버그 발견 시 GitHub Issues 활용
2. **기능 제안**: TODO.md의 Phase별 계획 참고
3. **코드 기여**: Pull Request 제출 전 테스트 필수
4. **문서 개선**: 사용자 경험 향상을 위한 문서 기여

### 개발 프로세스
```bash
# 1. Fork & Clone
git clone <your-fork>

# 2. 개발 & 테스트
zig build test
zig build run

# 3. Pull Request
# 모든 테스트 통과 후 PR 제출
```

**더 자세한 정보**: [개발자 가이드](docs/DEVELOPER_GUIDE.md)를 참고하세요.

---

## 📋 로드맵

현재 **22개 Phase**로 구성된 상세한 개발 계획이 [TODO.md](TODO.md)에 있습니다.

### 🎯 **현재 상태 (90% 완료)**
- ✅ P2P 네트워킹 및 자동 피어 발견
- ✅ Proof of History 합의 메커니즘  
- ✅ 스마트 컨트랙트 시스템
- ✅ 포괄적 테스트 프레임워크
- ✅ Eastsea Attestation Service (EAS)

### 🚀 **다음 계획**
- **Phase 17**: CI/CD 자동화
- **Phase 18**: 성능 모니터링
- **Phase 19**: 크로스 플랫폼 지원

---

## 📄 라이선스

이 프로젝트는 [MIT 라이선스](LICENSE) 하에 배포됩니다.

---

## 🌟 특별감사

- **Zig 커뮤니티**: 뛰어난 시스템 프로그래밍 언어 제공
- **Solana Labs**: Proof of History 합의 메커니즘 영감
- **블록체인 오픈소스 생태계**: 지속적인 혁신과 협력

---

<div align="center">

**⭐ 이 프로젝트가 유용하다면 Star를 눌러주세요! ⭐**

[🐛 버그 리포트](../../issues) | [💡 기능 제안](../../issues) | [🤝 기여하기](docs/DEVELOPER_GUIDE.md)

</div>