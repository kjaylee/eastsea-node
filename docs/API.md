# Eastsea API Documentation

## Table of Contents
- [Overview](#overview)
- [JSON-RPC API](#json-rpc-api)
  - [Endpoint](#endpoint)
  - [Method Reference](#method-reference)
- [P2P Network API](#p2p-network-api)
  - [Message Types](#message-types)
  - [QUIC Features](#quic-features)
- [Wallet API](#wallet-api)
  - [Key Management](#key-management)
  - [Account Operations](#account-operations)
- [Smart Contract API](#smart-contract-api)
  - [Program Structure](#program-structure)
  - [System Programs](#system-programs)
  - [Custom Programs](#custom-programs)
- [Attestation Service API](#attestation-service-api)
  - [Core Structures](#core-structures)
  - [Service Methods](#service-methods)
- [DHT API](#dht-api)
- [Error Codes](#error-codes)
  - [JSON-RPC](#json-rpc)
  - [Network](#network)
  - [Attestation](#attestation)
- [Usage Examples](#usage-examples)
- [Security](#security)
- [Performance](#performance)

---

## Overview

Eastsea provides a comprehensive API suite for blockchain interaction:

- **JSON-RPC API**: Blockchain state queries and transaction submission
- **P2P Network API**: Node communication with TCP/QUIC hybrid networking
- **Wallet API**: Account management and transaction signing
- **Smart Contract API**: Program execution and management
- **Attestation Service API**: Off-chain data verification

---

## JSON-RPC API

### Endpoint

**Base URL**: `http://localhost:8545`

### Method Reference

| Method | Description | Parameters | Example |
|--------|-------------|------------|---------|
| `getBlockHeight` | Current blockchain height | None | [Example](#getblockheight) |
| `getBalance` | Account balance query | `address` (hex string) | [Example](#getbalance) |
| `sendTransaction` | Submit new transaction | `from`, `to`, `amount`, `signature` | [Example](#sendtransaction) |
| `getBlock` | Block information | `height` (number) | [Example](#getblock) |
| `getTransaction` | Transaction details | `hash` (hex string) | [Example](#gettransaction) |
| `getPeers` | Connected peer list | None | [Example](#getpeers) |
| `getNodeInfo` | Node status information | None | [Example](#getnodeinfo) |

#### getBlockHeight

```json
// Request
{
  "jsonrpc": "2.0",
  "method": "getBlockHeight",
  "params": [],
  "id": 1
}

// Response
{
  "jsonrpc": "2.0",
  "result": 42,
  "id": 1
}
```

#### getBalance

```json
// Request
{
  "jsonrpc": "2.0",
  "method": "getBalance",
  "params": ["ff7580ebeca78b5468b42e182fff7e8e820c37c3"],
  "id": 2
}

// Response
{
  "jsonrpc": "2.0",
  "result": 1000,
  "id": 2
}
```

#### sendTransaction

```json
// Request
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

// Response
{
  "jsonrpc": "2.0",
  "result": "0x1234567890abcdef",
  "id": 3
}
```

#### getBlock

```json
// Request
{
  "jsonrpc": "2.0",
  "method": "getBlock",
  "params": [1],
  "id": 4
}

// Response
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
  "id": 4
}
```

#### getTransaction

```json
// Request
{
  "jsonrpc": "2.0",
  "method": "getTransaction",
  "params": ["0x1234567890abcdef"],
  "id": 5
}

// Response
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
  "id": 5
}
```

#### getPeers

```json
// Request
{
  "jsonrpc": "2.0",
  "method": "getPeers",
  "params": [],
  "id": 6
}

// Response
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
  "id": 6
}
```

#### getNodeInfo

```json
// Request
{
  "jsonrpc": "2.0",
  "method": "getNodeInfo",
  "params": [],
  "id": 7
}

// Response
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
  "id": 7
}
```

---

## P2P Network API

### Message Types

#### Handshake
```zig
const HandshakeMessage = struct {
    protocol_version: u32,
    node_id: [32]u8,
    port: u16,
    timestamp: u64,
};
```

#### Ping/Pong
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

#### Block Broadcast
```zig
const BlockMessage = struct {
    block_data: []u8,
    block_hash: [32]u8,
    height: u64,
};
```

#### Transaction Broadcast
```zig
const TransactionMessage = struct {
    transaction_data: []u8,
    transaction_hash: [32]u8,
};
```

### QUIC Features

Eastsea's QUIC implementation includes:

- **Multiplexed Streams**: Parallel block/transaction transmission
- **0-RTT Connection Resumption**: Minimized connection latency
- **Connection Migration**: IP/port change resilience
- **Enhanced Security**: Encrypted connection IDs & packet authentication
- **Advanced Flow Control**: Stream/connection level management
- **BBR Congestion Control**: Optimal bandwidth utilization
- **Perfect Forward Secrecy**: Enhanced security guarantees
- **Rapid Loss Recovery**: 20x faster than TCP

---

## Wallet API

### Key Management

```zig
// Generate new key pair
pub fn generateKeyPair() !KeyPair;

// Sign transaction
pub fn signTransaction(private_key: [32]u8, transaction: Transaction) ![64]u8;

// Verify signature
pub fn verifySignature(public_key: [32]u8, message: []const u8, signature: [64]u8) !bool;
```

### Account Operations

```zig
// Create new account
pub fn createAccount() !Account;

// Get account balance
pub fn getBalance(address: []const u8) !u64;

// Transfer tokens
pub fn transfer(from: []const u8, to: []const u8, amount: u64) ![]const u8;
```

---

## Smart Contract API

### Program Structure

```zig
pub const Program = struct {
    id: [32]u8,
    name: []const u8,
    code: []const u8,
    state: []u8,
    
    pub fn execute(self: *Program, instruction: Instruction) !ProgramResult;
};
```

### System Programs

#### Token Program
```zig
pub const TokenProgram = struct {
    pub fn mint(account: []const u8, amount: u64) !void;
    pub fn transfer(from: []const u8, to: []const u8, amount: u64) !void;
    pub fn burn(account: []const u8, amount: u64) !void;
};
```

#### System Program
```zig
pub const SystemProgram = struct {
    pub fn createAccount(address: []const u8) !void;
    pub fn transfer(from: []const u8, to: []const u8, amount: u64) !void;
};
```

### Custom Programs

#### Counter Program
```zig
pub const CounterProgram = struct {
    count: u64 = 0,
    
    pub fn increment(self: *CounterProgram) !void;
    pub fn decrement(self: *CounterProgram) !void;
    pub fn get(self: *CounterProgram) u64;
};
```

#### Voting Program
```zig
pub const VotingProgram = struct {
    proposals: std.ArrayList(Proposal),
    votes: std.HashMap([]const u8, u32),
    
    pub fn createProposal(self: *VotingProgram, title: []const u8) !u32;
    pub fn vote(self: *VotingProgram, voter: []const u8, proposal_id: u32) !void;
    pub fn getResults(self: *VotingProgram, proposal_id: u32) !VoteResult;
};
```

---

## Attestation Service API

### Core Structures

#### Attestation
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
    
    pub fn verify(self: *const Attestation) bool;
};
```

#### Schema
```zig
pub const Schema = struct {
    id: [32]u8,
    name: []const u8,
    description: []const u8,
    definition: []const u8,  // JSON schema
    creator: [20]u8,
    timestamp: u64,
};
```

#### Attester
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

### Service Methods

```zig
pub const AttestationService = struct {
    pub fn createAttestation(
        schema_id: [32]u8,
        attester_id: [20]u8,
        recipient: [20]u8,
        expiration: u64,
        data: []const u8,
        private_key: [32]u8
    ) !*Attestation;
    
    pub fn verifyAttestation(attestation_id: [32]u8) bool;
    pub fn revokeAttestation(attestation_id: [32]u8) !void;
    pub fn registerSchema(schema: Schema) !void;
    pub fn registerAttester(attester: Attester) !void;
    pub fn getAttestationsForRecipient(recipient: [20]u8) ![]*Attestation;
    pub fn getAttestationsByAttester(attester_id: [20]u8) ![]*Attestation;
};
```

---

## DHT API

```zig
// Store value in DHT
pub fn store(key: [32]u8, value: []const u8) !void;

// Retrieve value from DHT
pub fn findValue(key: [32]u8) !?[]const u8;

// Find closest nodes
pub fn findNode(target: [32]u8) ![]DHTNode;

// Join DHT network
pub fn bootstrap(bootstrap_nodes: []const DHTNode) !void;
```

---

## Error Codes

### JSON-RPC

| Code | Message | Description |
|------|---------|-------------|
| -32700 | Parse error | Invalid JSON |
| -32600 | Invalid Request | Malformed request |
| -32601 | Method not found | Unknown method |
| -32602 | Invalid params | Incorrect parameters |
| -32603 | Internal error | Server-side error |
| -1 | Transaction failed | Execution failure |
| -2 | Insufficient balance | Not enough funds |
| -3 | Invalid signature | Signature verification failed |
| -4 | Block not found | Non-existent block |
| -5 | Transaction not found | Non-existent transaction |

### Network

| Code | Description |
|------|-------------|
| `ConnectionRefused` | Peer unreachable |
| `Timeout` | Operation timed out |
| `InvalidMessage` | Malformed message |
| `HandshakeFailed` | Protocol mismatch |
| `VersionMismatch` | Incompatible protocol version |

### Attestation

| Code | Description |
|------|-------------|
| `AttestationExpired` | Validity period expired |
| `AttestationRevoked` | Explicitly revoked |
| `InvalidSignature` | Signature verification failed |
| `SchemaMismatch` | Schema validation error |

---

## Usage Examples

### Node Operations
```bash
# Start basic node
zig build run

# Connect to existing node
zig build run-p2p -- 8001 8000

# Start DHT network
zig build run-dht -- 8000
```

### API Interaction
```bash
# Get block height
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBlockHeight","params":[],"id":1}'

# Verify attestation
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"verifyAttestation","params":["d801073b..."],"id":3}'
```

### Testing
```bash
# Run EAS tests
zig build run-eas -- all

# Run DHT tests
zig build run-dht -- 8000
```

---

## Security

- 🔒 **Key Management**: Never transmit private keys over network
- ✅ **Transaction Validation**: All transactions require signature verification
- 🛡️ **Network Security**: Checksum-verified P2P communication
- ⏱️ **Rate Limiting**: Implement API call limits
- 🧪 **Input Validation**: Validate all user inputs

---

## Performance

- 💾 **Memory Management**: Use Zig allocators to prevent leaks
- 📡 **Network Optimization**: Implement message compression
- 🗃️ **Database Optimization**: Use indexing for blockchain data
- ⚡ **Concurrent Processing**: Parallelize transaction execution

---

## Documentation Status

✅ **Up-to-date with Phase 17 implementation** (Turbine, Sharding, Parallel Execution)
