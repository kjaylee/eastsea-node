# Eastsea API Documentation

## Overview

Eastsea는 Zig로 구현된 블록체인 클론으로, 다음과 같은 주요 API들을 제공합니다:

- **JSON-RPC API**: 블록체인 상태 조회 및 트랜잭션 제출
- **P2P Network API**: 노드 간 통신 및 피어 관리 (TCP/QUIC 하이브리드)
- **Wallet API**: 계정 관리 및 트랜잭션 서명
- **Smart Contract API**: 프로그램 실행 및 관리
- **Attestation Service API**: 오프체인 증명 생성 및 검증

---

## JSON-RPC API

Eastsea는 표준 JSON-RPC 2.0 프로토콜을 사용하여 HTTP 기반 API를 제공합니다.

**Base URL**: `http://localhost:8545`

### Methods

#### 1. getBlockHeight

현재 블록체인의 높이를 조회합니다.

**Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "getBlockHeight",
  "params": [],
  "id": 1
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "result": 42,
  "error": null,
  "id": 1
}
```

#### 2. getBalance

특정 계정의 잔액을 조회합니다.

**Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "getBalance",
  "params": ["ff7580ebeca78b5468b42e182fff7e8e820c37c3"],
  "id": 2
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "result": 1000,
  "error": null,
  "id": 2
}
```

#### 3. sendTransaction

새로운 트랜잭션을 블록체인에 제출합니다.

**Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "sendTransaction",
  "params": {
    "from": "ff7580ebeca78b5468b42e182fff7e8e820c37c3",
    "to": "0e56ad656c29a51263df1ca8e1a2d6169e95db51",
    "amount": 100,
    "signature": "abcd1234..."
  },
  "id": 3
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "result": "0x1234567890abcdef",
  "error": null,
  "id": 3
}
```

#### 4. getBlock

특정 블록의 정보를 조회합니다.

**Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "getBlock",
  "params": [1],
  "id": 4
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "height": 1,
    "hash": "0x...",
    "previous_hash": "0x...",
    "timestamp": 1234567890,
    "transactions": [],
    "merkle_root": "0x..."
  },
  "error": null,
  "id": 4
}
```

#### 5. getTransaction

특정 트랜잭션의 정보를 조회합니다.

**Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "getTransaction",
  "params": ["0x1234567890abcdef"],
  "id": 5
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "hash": "0x1234567890abcdef",
    "from": "ff7580ebeca78b5468b42e182fff7e8e820c37c3",
    "to": "0e56ad656c29a51263df1ca8e1a2d6169e95db51",
    "amount": 100,
    "timestamp": 1234567890,
    "signature": "abcd1234..."
  },
  "error": null,
  "id": 5
}
```

#### 6. getPeers

현재 연결된 피어 목록을 조회합니다.

**Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "getPeers",
  "params": [],
  "id": 6
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "result": [
    {
      "address": "127.0.0.1",
      "port": 8001,
      "node_id": "abc123...",
      "connected": true
    }
  ],
  "error": null,
  "id": 6
}
```

#### 7. getNodeInfo

현재 노드의 정보를 조회합니다.

**Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "getNodeInfo",
  "params": [],
  "id": 7
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "address": "127.0.0.1",
    "port": 8000,
    "peer_count": 3,
    "is_running": true,
    "blockchain_height": 42,
    "node_id": "def456..."
  },
  "error": null,
  "id": 7
}
```

---

## P2P Network API

P2P 네트워크는 내부적으로 사용되는 API로, 노드 간 직접 통신에 사용됩니다. 
Eastsea는 TCP와 QUIC 프로토콜을 모두 지원하는 하이브리드 네트워킹을 사용합니다.

### Message Types

#### 1. Handshake
```zig
const HandshakeMessage = struct {
    protocol_version: u32,
    node_id: [32]u8,
    port: u16,
    timestamp: u64,
};
```

#### 2. Ping/Pong
```zig
const PingMessage = struct {
    timestamp: u64,
    nonce: u64,
};

const PongMessage = struct {
    timestamp: u64,
    nonce: u64,
};
```

#### 3. Block Broadcast
```zig
const BlockMessage = struct {
    block_data: []u8,
    block_hash: [32]u8,
    height: u64,
};
```

#### 4. Transaction Broadcast
```zig
const TransactionMessage = struct {
    transaction_data: []u8,
    transaction_hash: [32]u8,
};
```

### QUIC Specific Features

QUIC 프로토콜은 다음과 같은 고급 기능을 제공합니다:

1. **Multiplexed Streams**: 여러 스트림을 동시에 사용하여 블록과 트랜잭션을 병렬로 전송
2. **0-RTT Connection Resumption**: 연결 재개 시 지연 시간 최소화
3. **Connection Migration**: IP 주소 변경 시 연결 유지
4. **Enhanced Security**: 연결 ID 암호화 및 패킷 인증
5. **Flow Control**: 스트림 및 연결 수준의 흐름 제어
6. **Congestion Control**: BBR 알고리즘 기반 혼잡 제어
7. **Forward Secrecy**: Perfect Forward Secrecy 보장
8. **Loss Recovery**: 빠른 손실 패킷 복구 (최대 20배 빠름)

---

## Wallet API

지갑 기능을 위한 내부 API입니다.

### Key Management

#### 1. Generate Key Pair
```zig
pub fn generateKeyPair() !KeyPair {
    // ECDSA 키 페어 생성
}
```

#### 2. Sign Transaction
```zig
pub fn signTransaction(private_key: [32]u8, transaction: Transaction) ![64]u8 {
    // 트랜잭션 서명
}
```

#### 3. Verify Signature
```zig
pub fn verifySignature(public_key: [32]u8, message: []const u8, signature: [64]u8) !bool {
    // 서명 검증
}
```

### Account Management

#### 1. Create Account
```zig
pub fn createAccount() !Account {
    // 새 계정 생성
}
```

#### 2. Get Balance
```zig
pub fn getBalance(address: []const u8) !u64 {
    // 계정 잔액 조회
}
```

#### 3. Transfer
```zig
pub fn transfer(from: []const u8, to: []const u8, amount: u64) ![]const u8 {
    // 토큰 전송
}
```

---

## Smart Contract (Programs) API

Eastsea의 스마트 컨트랙트 시스템인 Programs API입니다.

### Program Interface

#### 1. Program Structure
```zig
pub const Program = struct {
    id: [32]u8,
    name: []const u8,
    code: []const u8,
    state: []u8,
    
    pub fn execute(self: *Program, instruction: Instruction) !ProgramResult {
        // 프로그램 실행
    }
};
```

#### 2. System Programs

##### Token Program
```zig
pub const TokenProgram = struct {
    pub fn mint(account: []const u8, amount: u64) !void;
    pub fn transfer(from: []const u8, to: []const u8, amount: u64) !void;
    pub fn burn(account: []const u8, amount: u64) !void;
};
```

##### System Program
```zig
pub const SystemProgram = struct {
    pub fn createAccount(address: []const u8) !void;
    pub fn transfer(from: []const u8, to: []const u8, amount: u64) !void;
};
```

#### 3. Custom Programs

사용자 정의 프로그램 예제:

##### Counter Program
```zig
pub const CounterProgram = struct {
    count: u64 = 0,
    
    pub fn increment(self: *CounterProgram) !void {
        self.count += 1;
    }
    
    pub fn decrement(self: *CounterProgram) !void {
        if (self.count > 0) self.count -= 1;
    }
    
    pub fn get(self: *CounterProgram) u64 {
        return self.count;
    }
};
```

##### Voting Program
```zig
pub const VotingProgram = struct {
    proposals: std.ArrayList(Proposal),
    votes: std.HashMap([]const u8, u32),
    
    pub fn createProposal(self: *VotingProgram, title: []const u8) !u32;
    pub fn vote(self: *VotingProgram, voter: []const u8, proposal_id: u32) !void;
    pub fn getResults(self: *VotingProgram, proposal_id: u32) !VoteResult;
};
```

## Attestation Service API

Eastsea Attestation Service (EAS) API는 오프체인 데이터 검증을 위한 인터페이스입니다.

### Attestation Interface

#### 1. Attestation Structure
```zig
pub const Attestation = struct {
    id: [32]u8,
    schema_id: [32]u8,
    attester: [20]u8,
    recipient: [20]u8,
    timestamp: u64,
    expiration: u64,
    revocation_time: u64,
    data: []const u8,
    signature: [64]u8,
    hash: [32]u8,
    
    pub fn verify(self: *const Attestation) bool {
        // Verify attestation signature and validity
    }
};
```

#### 2. Schema Structure
```zig
pub const Schema = struct {
    id: [32]u8,
    name: []const u8,
    description: []const u8,
    definition: []const u8,  // JSON schema definition
    creator: [20]u8,
    timestamp: u64,
};
```

#### 3. Attester Structure
```zig
pub const Attester = struct {
    id: [20]u8,
    name: []const u8,
    reputation: u64,
    attestation_count: u64,
    registration_time: u64,
    is_active: bool,
};
```

#### 4. Attestation Service Methods
```zig
pub const AttestationService = struct {
    pub fn createAttestation(
        self: *AttestationService,
        schema_id: [32]u8,
        attester_id: [20]u8,
        recipient: [20]u8,
        expiration: u64,
        data: []const u8,
        private_key: [32]u8
    ) !*Attestation;
    
    pub fn verifyAttestation(self: *AttestationService, attestation_id: [32]u8) bool;
    
    pub fn revokeAttestation(self: *AttestationService, attestation_id: [32]u8) !void;
    
    pub fn registerSchema(self: *AttestationService, schema: Schema) !void;
    
    pub fn registerAttester(self: *AttestationService, attester: Attester) !void;
    
    pub fn getAttestationsForRecipient(self: *AttestationService, recipient: [20]u8) ![]*Attestation;
    
    pub fn getAttestationsByAttester(self: *AttestationService, attester_id: [20]u8) ![]*Attestation;
};
```

---

## DHT (Distributed Hash Table) API

분산 해시 테이블을 통한 피어 발견 API입니다.

### DHT Operations

#### 1. Store Value
```zig
pub fn store(key: [32]u8, value: []const u8) !void {
    // DHT에 값 저장
}
```

#### 2. Find Value
```zig
pub fn findValue(key: [32]u8) !?[]const u8 {
    // DHT에서 값 조회
}
```

#### 3. Find Node
```zig
pub fn findNode(target: [32]u8) ![]DHTNode {
    // 특정 노드 ID에 가장 가까운 노드들 찾기
}
```

#### 4. Bootstrap
```zig
pub fn bootstrap(bootstrap_nodes: []const DHTNode) !void {
    // DHT 네트워크에 참여
}
```

---

## Error Codes

### JSON-RPC Error Codes

| Code | Message | Description |
|------|---------|-------------|
| -32700 | Parse error | Invalid JSON |
| -32600 | Invalid Request | Invalid JSON-RPC request |
| -32601 | Method not found | Method does not exist |
| -32602 | Invalid params | Invalid method parameters |
| -32603 | Internal error | Internal JSON-RPC error |
| -1 | Transaction failed | Transaction execution failed |
| -2 | Insufficient balance | Account has insufficient balance |
| -3 | Invalid signature | Transaction signature is invalid |
| -4 | Block not found | Requested block does not exist |
| -5 | Transaction not found | Requested transaction does not exist |
| -6 | Attestation not found | Requested attestation does not exist |
| -7 | Schema not found | Requested schema does not exist |
| -8 | Attester not found | Requested attester does not exist |

### Network Error Codes

| Code | Description |
|------|-------------|
| `ConnectionRefused` | Unable to connect to peer |
| `Timeout` | Network operation timed out |
| `InvalidMessage` | Received invalid message format |
| `HandshakeFailed` | Peer handshake failed |
| `VersionMismatch` | Protocol version mismatch |

### Attestation Error Codes

| Code | Description |
|------|-------------|
| `AttestationExpired` | Attestation has expired |
| `AttestationRevoked` | Attestation has been revoked |
| `InvalidSignature` | Attestation signature is invalid |
| `SchemaMismatch` | Attestation schema does not match |

---

## Usage Examples

### Starting a Node

```bash
# Basic node
zig build run

# Production node
zig build run-prod

# P2P test node
zig build run-p2p -- 8000

# Connect to existing node
zig build run-p2p -- 8001 8000
```

### Using JSON-RPC API

```bash
# Get block height
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBlockHeight","params":[],"id":1}'

# Get balance
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBalance","params":["ff7580ebeca78b5468b42e182fff7e8e820c37c3"],"id":2}'

# Verify attestation
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"verifyAttestation","params":["d801073b434d52a467257dafc93f971052c6d2e857fff2b4e57087b7b024b984"],"id":3}'
```

### DHT Network Testing

```bash
# Start DHT node
zig build run-dht -- 8000

# Connect to DHT network
zig build run-dht -- 8001 8000
```

### EAS Testing

```bash
# Run all EAS tests
zig build run-eas -- all

# Run specific EAS test
zig build run-eas -- verification
```

---

## Security Considerations

1. **Private Key Management**: 개인키는 안전하게 저장하고 네트워크를 통해 전송하지 마세요.

2. **Transaction Validation**: 모든 트랜잭션은 서명 검증을 거쳐야 합니다.

3. **Network Security**: P2P 통신은 체크섬을 통한 무결성 검증을 포함합니다.

4. **Rate Limiting**: RPC API 호출에 대한 적절한 제한을 설정하세요.

5. **Input Validation**: 모든 사용자 입력은 검증되어야 합니다.

---

## Performance Considerations

1. **Memory Management**: Zig의 allocator를 적절히 사용하여 메모리 누수를 방지합니다.

2. **Network Optimization**: 메시지 압축 및 배치 처리를 고려하세요.

3. **Database Optimization**: 블록체인 데이터의 효율적인 저장 및 조회를 위한 인덱싱을 구현하세요.

4. **Concurrent Processing**: 트랜잭션 처리의 병렬화를 고려하세요.

---

## Contributing

API 개선 사항이나 버그 리포트는 GitHub 이슈를 통해 제출해 주세요.

## License

MIT License - 자세한 내용은 LICENSE 파일을 참조하세요.