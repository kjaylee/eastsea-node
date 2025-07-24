zig로 eastsea 클론 만들기. todo 리스트 만들어서, context가 모자라도 계속 이어 갈 수 있게해줘.

## 🚀 최신 업데이트: 실제 P2P 네트워크 구현 완료!

이 프로젝트는 Zig 언어로 구현된 Eastsea 블록체인 클론입니다. 최근 **실제 TCP 소켓 통신을 지원하는 P2P 네트워크**가 구현되어 더욱 현실적인 블록체인 시스템이 되었습니다.

### 🌟 새로 구현된 P2P 기능들:
- ✅ 실제 TCP 소켓 기반 피어 간 통신
- ✅ 메시지 직렬화/역직렬화 (바이너리 프로토콜)
- ✅ 체크섬 기반 메시지 무결성 검증
- ✅ 핸드셰이크 및 연결 관리
- ✅ 블록 및 트랜잭션 브로드캐스팅
- ✅ 피어 상태 모니터링 (ping/pong)
- ✅ DHT (Distributed Hash Table) 기반 자동 피어 발견

### 🛠️ 사용법:
```bash
# 기본 데모 실행
zig build run

# P2P 네트워크 테스트
zig build run-p2p -- 8000

# 다른 터미널에서 피어 연결
zig build run-p2p -- 8001 8000

# DHT 기능 테스트
zig build run-dht -- 8000

# 다른 터미널에서 DHT 노드 연결
zig build run-dht -- 8001 8000

# 테스트 실행
zig build test
```
# eastsea-node
