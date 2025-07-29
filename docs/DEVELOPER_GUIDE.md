# Eastsea Developer Guide

## Table of Contents

1. [Project Overview](#project-overview)
2. [Development Environment Setup](#development-environment-setup)
3. [Architecture Overview](#architecture-overview)
4. [Core Components](#core-components)
5. [Development Workflow](#development-workflow)
6. [Testing Strategy](#testing-strategy)
7. [Contributing Guidelines](#contributing-guidelines)
8. [Advanced Topics](#advanced-topics)

---

## Project Overview

Eastsea는 Zig 언어로 구현된 블록체인 클론으로, 다음과 같은 주요 특징을 가집니다:

- **Proof of History (PoH) 합의 메커니즘**
- **실제 TCP/QUIC 소켓 기반 P2P 네트워킹**
- **DHT를 통한 자동 피어 발견**
- **스마트 컨트랙트 (Programs) 지원**
- **JSON-RPC API**
- **Eastsea Attestation Service (EAS)**
- **통합 지갑 시스템**

### Technology Stack

- **Language**: Zig 0.14+
- **Networking**: TCP/QUIC Sockets, UDP (DHT)
- **Cryptography**: SHA-256, ECDSA
- **Serialization**: Custom binary protocol
- **Testing**: Zig built-in test framework
- **Attestation Service**: EAS (Eastsea Attestation Service)

---

## Development Environment Setup

### Prerequisites

1. **Zig 0.14+** 설치
   ```bash
   # macOS (Homebrew)
   brew install zig
   
   # Linux
   wget https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz
   tar -xf zig-linux-x86_64-0.14.0.tar.xz
   export PATH=$PATH:$(pwd)/zig-linux-x86_64-0.14.0
   ```

2. **Git** (버전 관리)
3. **Code Editor** (VS Code with Zig extension 권장)

### Project Setup

```bash
# Clone repository
git clone <repository-url>
cd eastsea-zig

# Build project
zig build

# Run tests
zig build test

# Run demo
zig build run
```

### Development Tools

#### VS Code Extensions
- **Zig Language** (by ziglang)
- **Error Lens** (실시간 에러 표시)
- **GitLens** (Git 히스토리 관리)

#### Recommended Settings
```json
{
  "zig.zls.enable": true,
  "zig.initialSetupDone": true,
  "editor.formatOnSave": true
}
```

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   JSON-RPC API  │    │   CLI Wallet    │    │   Web Interface │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
┌─────────────────────────────────────────────────────────────────┐
│                        Core Blockchain                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │ Blockchain  │  │ Consensus   │  │ Smart Contracts         │ │
│  │ Engine      │  │ (PoH)       │  │ (Programs)              │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ P2P Networking  │    │ DHT Discovery   │    │ Storage Layer   │
│ (TCP/UDP)       │    │ (Kademlia)      │    │ (In-Memory)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Directory Structure

```
src/
├── main.zig                 # Main entry point
├── lib.zig                  # Library exports
├── blockchain/              # Blockchain core
│   ├── blockchain.zig       # Main blockchain logic
│   ├── block.zig           # Block structure
│   ├── transaction.zig     # Transaction handling
│   └── account.zig         # Account management
├── consensus/               # Consensus mechanisms
│   └── poh.zig             # Proof of History
├── eas/                     # Eastsea Attestation Service
│   └── attestation.zig      # Attestation, Schema, Attester structures
├── network/                 # Networking layer
│   ├── p2p.zig             # P2P networking (TCP)
│   ├── quic.zig            # QUIC networking
│   ├── node.zig            # Network node
│   ├── dht.zig             # DHT implementation
│   ├── bootstrap.zig       # Bootstrap nodes
│   ├── mdns.zig            # mDNS discovery
│   ├── upnp.zig            # UPnP port forwarding
│   ├── stun.zig            # STUN client
│   ├── auto_discovery.zig  # Auto peer discovery
│   ├── port_scanner.zig    # Port scanning
│   ├── broadcast.zig       # Broadcast/multicast
│   └── tracker.zig         # Tracker server/client
├── programs/                # Smart contracts
│   ├── program.zig         # Program interface
│   └── custom_program.zig  # Custom program examples
├── crypto/                  # Cryptographic functions
│   └── hash.zig            # Hashing utilities
├── rpc/                     # JSON-RPC server
│   └── server.zig          # RPC server implementation
├── cli/                     # Command line interface
│   └── wallet.zig          # Wallet functionality
├── performance/             # Performance tools
│   └── benchmark.zig       # Benchmarking framework
├── security/                # Security testing
│   └── security_test.zig   # Security test framework
└── testing/                 # Testing utilities
    └── network_failure_test.zig # Network resilience tests
```

---

## Core Components

### 1. Blockchain Engine (`src/blockchain/`)

#### Block Structure
```zig
pub const Block = struct {
    height: u64,
    timestamp: u64,
    previous_hash: [32]u8,
    merkle_root: [32]u8,
    transactions: std.ArrayList(Transaction),
    nonce: u64,
    hash: [32]u8,
    
    pub fn calculateHash(self: *const Block) [32]u8 {
        // Block hash calculation
    }
    
    pub fn isValid(self: *const Block, previous_block: ?*const Block) bool {
        // Block validation logic
    }
};
```

#### Transaction Structure
```zig
pub const Transaction = struct {
    from: [20]u8,
    to: [20]u8,
    amount: u64,
    timestamp: u64,
    signature: [64]u8,
    hash: [32]u8,
    
    pub fn sign(self: *Transaction, private_key: [32]u8) !void {
        // Transaction signing
    }
    
    pub fn verify(self: *const Transaction) bool {
        // Signature verification
    }
};
```

### 2. Consensus Layer (`src/consensus/`)

#### Proof of History Implementation
```zig
pub const ProofOfHistory = struct {
    current_hash: [32]u8,
    tick_count: u64,
    sequence: std.ArrayList(PoHEntry),
    
    pub fn tick(self: *ProofOfHistory) !void {
        // Generate next PoH tick
        self.current_hash = sha256(self.current_hash);
        self.tick_count += 1;
    }
    
    pub fn recordTransaction(self: *ProofOfHistory, tx: Transaction) !void {
        // Record transaction in PoH sequence
    }
};
```

### 3. P2P Networking (`src/network/`)

#### Node Management
```zig
pub const P2PNode = struct {
    node_id: [32]u8,
    address: std.net.Address,
    peers: std.HashMap([32]u8, Peer),
    server: std.net.Server,
    
    pub fn start(self: *P2PNode) !void {
        // Start P2P server
    }
    
    pub fn connectToPeer(self: *P2PNode, address: std.net.Address) !void {
        // Connect to remote peer
    }
    
    pub fn broadcast(self: *P2PNode, message: Message) !void {
        // Broadcast message to all peers
    }
};

pub const QuicNode = struct {
    node_id: [32]u8,
    address: std.net.Address,
    connections: std.ArrayList(QuicConnection),
    server: std.net.Server,
    
    pub fn start(self: *QuicNode) !void {
        // Start QUIC server
    }
    
    pub fn connectToPeer(self: *QuicNode, address: std.net.Address) !void {
        // Connect to remote peer via QUIC
    }
    
    pub fn broadcast(self: *QuicNode, message: Message) !void {
        // Broadcast message to all QUIC connections
    }
};
```

### 4. Smart Contracts (`src/programs/`)

#### Program Interface
```zig
pub const ProgramInterface = struct {
    pub fn execute(program_id: [32]u8, instruction: Instruction) !ProgramResult {
        // Execute program instruction
    }
    
    pub fn getState(program_id: [32]u8) ![]u8 {
        // Get program state
    }
};

### 5. Attestation Service (`src/eas/`)

#### Attestation Structure
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

pub const Schema = struct {
    id: [32]u8,
    name: []const u8,
    description: []const u8,
    definition: []const u8,
    creator: [20]u8,
    timestamp: u64,
};

pub const Attester = struct {
    id: [20]u8,
    name: []const u8,
    reputation: u64,
    attestation_count: u64,
    registration_time: u64,
    is_active: bool,
};
```

#### DHT Implementation
```zig
pub const DHT = struct {
    node_id: [20]u8,
    routing_table: KBucket,
    storage: std.HashMap([20]u8, []u8),
    
    pub fn findNode(self: *DHT, target: [20]u8) ![]DHTNode {
        // Kademlia FIND_NODE operation
    }
    
    pub fn store(self: *DHT, key: [20]u8, value: []u8) !void {
        // Store key-value pair
    }
};
```

### 4. Smart Contracts (`src/programs/`)

#### Program Interface
```zig
pub const ProgramInterface = struct {
    pub fn execute(program_id: [32]u8, instruction: Instruction) !ProgramResult {
        // Execute program instruction
    }
    
    pub fn getState(program_id: [32]u8) ![]u8 {
        // Get program state
    }
};
```

---

## Development Workflow

### 1. Feature Development Process

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/new-feature
   ```

2. **Implement Feature**
   - Write code following Zig best practices
   - Add comprehensive tests
   - Update documentation

3. **Test Thoroughly**
   ```bash
   # Unit tests
   zig build test
   
   # Integration tests
   zig build run
   
   # Component-specific tests
   zig build run-p2p -- 8000
   zig build run-dht -- 8000
   ```

4. **Code Review**
   - Self-review code changes
   - Ensure all tests pass
   - Check performance implications

5. **Merge to Main**
   ```bash
   git checkout main
   git merge feature/new-feature
   git push origin main
   ```

### 2. Code Style Guidelines

#### Naming Conventions
```zig
// Types: PascalCase
pub const BlockChain = struct {};

// Functions: camelCase
pub fn calculateHash() void {}

// Variables: snake_case
const block_height: u64 = 0;

// Constants: SCREAMING_SNAKE_CASE
const MAX_BLOCK_SIZE: usize = 1024 * 1024;
```

#### Error Handling
```zig
// Use Zig's error unions
pub fn processTransaction(tx: Transaction) !void {
    if (!tx.verify()) {
        return error.InvalidSignature;
    }
    // Process transaction
}

// Handle errors explicitly
const result = processTransaction(tx) catch |err| switch (err) {
    error.InvalidSignature => {
        std.log.err("Invalid transaction signature", .{});
        return;
    },
    else => return err,
};
```

#### Memory Management
```zig
// Use arena allocators for temporary data
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();
const allocator = arena.allocator();

// Always defer cleanup
const list = std.ArrayList(u8).init(allocator);
defer list.deinit();
```

### 3. Build System

#### Build Targets
```zig
// build.zig structure
pub fn build(b: *std.Build) void {
    // Main executable
    const exe = b.addExecutable(.{
        .name = "eastsea",
        .root_source_file = .{ .path = "src/main.zig" },
    });
    
    // Test executable
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
    });
    
    // Custom build steps
    const p2p_test = b.addExecutable(.{
        .name = "p2p-test",
        .root_source_file = .{ .path = "src/p2p_test.zig" },
    });
}
```

---

## Testing Strategy

### 1. Unit Testing

```zig
// Example unit test
test "block hash calculation" {
    var block = Block{
        .height = 1,
        .timestamp = 1234567890,
        .previous_hash = [_]u8{0} ** 32,
        .merkle_root = [_]u8{0} ** 32,
        .transactions = std.ArrayList(Transaction).init(std.testing.allocator),
        .nonce = 0,
        .hash = [_]u8{0} ** 32,
    };
    defer block.transactions.deinit();
    
    const hash = block.calculateHash();
    try std.testing.expect(hash.len == 32);
}
```

### 2. Integration Testing

```bash
# P2P Network Test
zig build run-p2p -- 8000 &
zig build run-p2p -- 8001 8000 &
# Verify connection and message exchange

# DHT Network Test
zig build run-dht -- 8000 &
zig build run-dht -- 8001 8000 &
# Verify peer discovery and routing
```

### 3. Performance Testing

```zig
// Benchmark example
const BenchmarkFramework = @import("performance/benchmark.zig").BenchmarkFramework;

test "transaction processing benchmark" {
    var benchmark = BenchmarkFramework.init(std.testing.allocator);
    defer benchmark.deinit();
    
    try benchmark.benchmark("Transaction Processing", 1000, processTestTransaction, .{});
    benchmark.printSummary();
}
```

### 4. Security Testing

```zig
// Security test example
test "transaction signature validation" {
    const tx = createTestTransaction();
    
    // Test with valid signature
    try std.testing.expect(tx.verify() == true);
    
    // Test with invalid signature
    var invalid_tx = tx;
    invalid_tx.signature[0] = ~invalid_tx.signature[0];
    try std.testing.expect(invalid_tx.verify() == false);
}
```

---

## Contributing Guidelines

### 1. Code Contribution Process

1. **Fork Repository**
2. **Create Feature Branch**
3. **Implement Changes**
4. **Add Tests**
5. **Update Documentation**
6. **Submit Pull Request**

### 2. Pull Request Guidelines

#### PR Title Format
```
type(scope): description

Examples:
feat(p2p): add DHT peer discovery
fix(blockchain): resolve block validation issue
docs(api): update RPC documentation
test(network): add integration tests for P2P
```

#### PR Description Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
```

### 3. Issue Reporting

#### Bug Report Template
```markdown
## Bug Description
Clear description of the bug

## Steps to Reproduce
1. Step 1
2. Step 2
3. Step 3

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- OS: [e.g., macOS 12.0]
- Zig version: [e.g., 0.14.0]
- Build mode: [e.g., Debug/Release]
```

---

## Advanced Topics

### 1. Custom Program Development

```zig
// Custom program example
pub const CustomProgram = struct {
    state: ProgramState,
    
    pub fn execute(self: *CustomProgram, instruction: Instruction) !ProgramResult {
        switch (instruction.type) {
            .Initialize => try self.initialize(instruction.data),
            .Process => try self.process(instruction.data),
            .Query => return self.query(instruction.data),
        }
        return ProgramResult.success();
    }
    
    fn initialize(self: *CustomProgram, data: []const u8) !void {
        // Initialize program state
    }
    
    fn process(self: *CustomProgram, data: []const u8) !void {
        // Process instruction
    }
    
    fn query(self: *CustomProgram, data: []const u8) ProgramResult {
        // Query program state
    }
};
```

### 2. Network Protocol Extension

```zig
// Custom message type
pub const CustomMessage = struct {
    message_type: u8 = 0xFF, // Custom message type
    payload_size: u32,
    payload: []u8,
    checksum: u32,
    
    pub fn serialize(self: *const CustomMessage, writer: anytype) !void {
        try writer.writeInt(u8, self.message_type, .little);
        try writer.writeInt(u32, self.payload_size, .little);
        try writer.writeAll(self.payload);
        try writer.writeInt(u32, self.checksum, .little);
    }
    
    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !CustomMessage {
        const message_type = try reader.readInt(u8, .little);
        const payload_size = try reader.readInt(u32, .little);
        const payload = try allocator.alloc(u8, payload_size);
        try reader.readNoEof(payload);
        const checksum = try reader.readInt(u32, .little);
        
        return CustomMessage{
            .message_type = message_type,
            .payload_size = payload_size,
            .payload = payload,
            .checksum = checksum,
        };
    }
};
```

### 3. Performance Optimization

#### Memory Pool Usage
```zig
// Memory pool for frequent allocations
pub const TransactionPool = struct {
    pool: std.heap.MemoryPool(Transaction),
    
    pub fn init(allocator: std.mem.Allocator) TransactionPool {
        return TransactionPool{
            .pool = std.heap.MemoryPool(Transaction).init(allocator),
        };
    }
    
    pub fn create(self: *TransactionPool) !*Transaction {
        return self.pool.create();
    }
    
    pub fn destroy(self: *TransactionPool, tx: *Transaction) void {
        self.pool.destroy(tx);
    }
};
```

#### Async Operations
```zig
// Async network operations
pub fn connectToPeerAsync(self: *P2PNode, address: std.net.Address) !void {
    const frame = async self.connectToPeerInternal(address);
    // Handle async connection
}
```

### 4. Debugging and Profiling

#### Logging
```zig
const std = @import("std");
const log = std.log.scoped(.eastsea);

pub fn processBlock(block: Block) !void {
    log.info("Processing block {}", .{block.height});
    
    // Process block
    
    log.debug("Block {} processed successfully", .{block.height});
}
```

#### Memory Debugging
```zig
// Enable memory debugging in debug builds
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
        .thread_safe = true,
    }){};
    defer _ = gpa.deinit();
    
    const allocator = gpa.allocator();
    // Use allocator
}
```

---

## Troubleshooting

### Common Issues

1. **Build Errors**
   ```bash
   # Clear cache and rebuild
   rm -rf .zig-cache zig-out
   zig build
   ```

2. **Network Connection Issues**
   ```bash
   # Check port availability
   lsof -i :8000
   
   # Test network connectivity
   nc -zv 127.0.0.1 8000
   ```

3. **Memory Issues**
   ```bash
   # Run with memory debugging
   zig build run -Doptimize=Debug
   ```

### Performance Issues

1. **Slow Block Processing**
   - Check hash calculation efficiency
   - Optimize transaction validation
   - Consider parallel processing

2. **Network Latency**
   - Implement message batching
   - Optimize serialization
   - Use connection pooling

3. **Memory Usage**
   - Use arena allocators for temporary data
   - Implement object pooling
   - Monitor memory leaks

---

## Resources

### Documentation
- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [Zig Standard Library](https://ziglang.org/documentation/master/std/)

### Community
- [Zig Discord](https://discord.gg/zig)
- [Zig Forum](https://ziggit.dev/)
- [GitHub Discussions](https://github.com/ziglang/zig/discussions)

### Tools
- [ZLS (Zig Language Server)](https://github.com/zigtools/zls)
- [Zig Analyzer](https://github.com/zigtools/zig-analyzer)

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.