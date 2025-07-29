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

Eastsea is a modern blockchain platform implemented in the Zig programming language. It provides the following features:

### 🌟 Key Features

- **⚡ High Performance**: Achieve high throughput with Proof of History consensus mechanism
- **🌐 Automatic Network Discovery**: Automatic peer connection via DHT, mDNS, and UPnP
- **🔒 Strong Security**: ECDSA digital signatures and SHA-256 hashing
- **💡 Smart Contracts**: Support for custom program execution
- **🔧 Developer Friendly**: Complete JSON-RPC API provided
- **🚀 High-Performance Networking**: TCP/QUIC hybrid protocol support
- **✅ Trust-Based System**: Eastsea Attestation Service (EAS) support

### 🎯 Use Cases

- **Developers**: Blockchain application development and testing
- **Researchers**: Distributed systems and consensus algorithm research
- **Education**: Learning and practicing blockchain technology
- **Enterprises**: Building private blockchain networks

---

## Installation

### System Requirements

- **Operating System**: macOS, Linux, Windows
- **Memory**: Minimum 4GB RAM (8GB recommended)
- **Storage**: Minimum 1GB free space
- **Network**: Internet connection (for P2P network participation)
- **QUIC Support**: Modern network stack (QUIC/HTTP3 support)
- **EAS Support**: Cryptographic capabilities for attestation creation and verification

### Prerequisites

1. **Install Zig 0.14+**

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
   1. Download the Windows version from the [Zig official site](https://ziglang.org/download/)
   2. Extract and add to PATH

2. **Install Git** (for downloading source code)

### Building from Source

```bash
# 1. Download source code
git clone <repository-url>
cd eastsea-zig

# 2. Build project
zig build

# 3. Verify installation
zig build test
```

### Pre-built Binaries (to be provided in the future)

```bash
# Download and install binaries
curl -L https://github.com/eastsea/releases/latest/download/eastsea-linux.tar.gz | tar xz
sudo mv eastsea /usr/local/bin/
```

---

## Quick Start

### 1. Run Your First Node

```bash
# Run basic demo (experience all features)
zig build run
```

When executed, the following process will automatically proceed:

1. ✅ Blockchain initialization
2. 📦 Genesis block creation
3. 🌐 P2P node startup (port 8000)
4. 🔗 DHT network initialization
5. ⚡ Proof of History consensus startup
6. 🚀 RPC server startup (port 8545)
7. 🎯 Demo sequence execution

### 2. Run a Production Node

```bash
# Node for production environment
zig build run-prod
```

### 3. Network Participation

```bash
# Terminal 1: First node
zig build run-p2p -- 8000

# Terminal 2: Second node (connect to first node)
zig build run-p2p -- 8001 8000

# Terminal 3: Third node (join network)
zig build run-p2p -- 8002 8000
```

---

## Basic Operations

### 1. Query Blockchain Status

#### Using JSON-RPC API

```bash
# Query current block height
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "getBlockHeight",
    "params": [],
    "id": 1
  }'

# Example response
{
  "jsonrpc": "2.0",
  "result": 42,
  "error": null,
  "id": 1
}
```

#### Query Node Information

```bash
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "getNodeInfo",
    "params": [],
    "id": 2
  }'

# Example response
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

### 2. Account and Balance Management

#### Query Account Balance

```bash
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "getBalance",
    "params": ["ff7580ebeca78b5468b42e182fff7e8e820c37c3"],
    "id": 3
  }'

# Example response
{
  "jsonrpc": "2.0",
  "result": 1000,
  "error": null,
  "id": 3
}
```

### 3. Transaction Processing

#### Send Transaction

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

# Example response
{
  "jsonrpc": "2.0",
  "result": "0x1234567890abcdef",
  "error": null,
  "id": 4
}
```

---

## Network Participation

### 1. P2P Network Participation

#### Starting a Single Node

```bash
# Start node on port 8000
zig build run-p2p -- 8000
```

Example output:
```
🌐 P2P Node started on 127.0.0.1:8000
🆔 Node ID: a1b2c3d4e5f6...
📡 Listening for connections...
```

#### Connecting to an Existing Node

```bash
# Start on port 8001 and connect to node on port 8000
zig build run-p2p -- 8001 8000
```

Example output:
```
🌐 P2P Node started on 127.0.0.1:8001
🆔 Node ID: f6e5d4c3b2a1...
🔗 Connecting to peer 127.0.0.1:8000...
✅ Connected to peer a1b2c3d4e5f6...
```

### 2. DHT Network Participation

#### Starting a DHT Node

```bash
# Start DHT network
zig build run-dht -- 8000
```

#### Joining a DHT Network

```bash
# Join an existing DHT network
zig build run-dht -- 8001 8000
```

Example output:
```
🔗 DHT initialized
🔍 Bootstrapping DHT with 127.0.0.1:8000
✅ DHT bootstrap complete. Routing table has 1 nodes
📊 DHT Node Info:
   Node ID: 03f6d7ba09b0531a...
   Address: 127.0.0.1:8001
   Total nodes in routing table: 1
```

### 3. Automatic Peer Discovery

#### mDNS Local Discovery

```bash
# Local network peer discovery via mDNS
zig build run-mdns -- 8000
```

#### Integrated Automatic Discovery

```bash
# Automatic peer connection using all discovery methods
zig build run-auto-discovery -- 8000
```

This command automatically tries the following methods:
- mDNS local discovery
- DHT network participation
- Bootstrap node connection
- UPnP port forwarding
- Peer discovery via port scanning

---

## Wallet Management

### 1. Basic Wallet Usage

Eastsea provides a built-in wallet system. Test accounts are automatically created during demo execution.

#### Account Creation Process (performed internally)

```
🔑 New account created: ff7580ebeca78b5468b42e182fff7e8e820c37c3
🔑 New account created: 0e56ad656c29a51263df1ca8e1a2d6169e95db51
```

#### Checking Wallet Status

```
📋 Wallet Accounts:
  1. ff7580ebeca78b5468b42e182fff7e8e820c37c3 (Balance: 1000)
  2. 0e56ad656c29a51263df1ca8e1a2d6169e95db51 (Balance: 500)
```

### 2. Token Transfer

#### Transfer Between Wallets (automatically executed in demo)

```
💸 Transfer: ff7580ebeca78b5468b42e182fff7e8e820c37c3 -> 0e56ad656c29a51263df1ca8e1a2d6169e95db51 (50 units)
💰 Wallet transfer completed
✍️  Transaction signed: 00f246cc83033a6f
```

#### Transfer via API

```bash
# Create and send transaction
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

### 3. Security Considerations

- **Private Key Security**: Keep private keys in a secure location
- **Signature Verification**: All transactions are protected by digital signatures
- **Network Security**: P2P communication verifies integrity with checksums


---

## Smart Contracts

### 1. Using Basic Programs

#### Testing System Programs

```bash
# Test basic program functionality
zig build run-programs
```

#### Testing Custom Programs

```bash
# Test all custom programs
zig build run-custom-programs -- all
```

### 2. Running Individual Programs

#### Counter Program

```bash
# Run counter program
zig build run-custom-programs -- counter
```

Example output:
```
🧮 Counter Program Demo
=======================
Initial count: 0
After increment: 1
After increment: 2
After decrement: 1
Final count: 1
```

#### Calculator Program

```bash
# Run calculator program
zig build run-custom-programs -- calculator
```

Example output:
```
🧮 Calculator Program Demo
===========================
10 + 5 = 15
10 - 5 = 5
10 * 5 = 50
10 / 5 = 2
```

#### Voting Program

```bash
# Run voting program
zig build run-custom-programs -- voting
```

Example output:
```
🗳️ Voting Program Demo
=======================
Created proposal: "Increase block size"
Vote from Alice: Yes
Vote from Bob: No
Vote from Charlie: Yes
Final results: Yes: 2, No: 1
```

#### Token Swap Program

```bash
# Run token swap program
zig build run-custom-programs -- token-swap
```

Example output:
```
💱 Token Swap Program Demo
===========================
Created liquidity pool: TokenA/TokenB
Added liquidity: 1000 TokenA, 1000 TokenB
Swapped 100 TokenA for 90 TokenB
Pool balance: 1100 TokenA, 910 TokenB
```

### 3. Performance Benchmark

```bash
# Test program performance
zig build run-custom-programs -- benchmark
```

Example output:
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

### 1. UPnP Automatic Port Forwarding

```bash
# Test automatic port forwarding via UPnP
zig build run-upnp -- 8000
```

This feature automatically forwards ports to make nodes behind NAT accessible from outside.

### 2. NAT Traversal via STUN

```bash
# Test STUN client
zig build run-stun
```

The STUN server discovers public IP addresses and analyzes NAT types.

### 3. Tracker Server/Client

#### Starting Tracker Server

```bash
# Start central peer list management server
zig build run-tracker -- server 7000
```

#### Connecting Tracker Client

```bash
# Connect to tracker server to get peer list
zig build run-tracker -- client 8001 7000
```

### 4. Peer Discovery via Port Scanning

```bash
# Scan local network for active nodes
zig build run-port-scan -- 8000
```

### 5. Broadcast/Multicast Announcements

```bash
# Announce node presence to network
zig build run-broadcast -- 8000
```

### 6. QUIC Network Testing

Eastsea uses hybrid networking with both TCP and QUIC protocols. 
QUIC provides the following advanced features:

- **Multiplexed Streams**: Use multiple streams simultaneously to transmit blocks and transactions in parallel
- **0-RTT Connection Resumption**: Minimize latency when resuming connections
- **Connection Migration**: Maintain connections when IP addresses change
- **Enhanced Security**: Encrypt connection IDs and authenticate packets

#### Basic QUIC Connection Test

```bash
# Basic QUIC connection test
zig-out/bin/quic-test basic
```

#### QUIC Multi-Stream Test

```bash
# Test QUIC multi-stream functionality
zig-out/bin/quic-test streams
```

#### QUIC Security Features Test

```bash
# Test QUIC security features
zig-out/bin/quic-test security
```

#### QUIC Performance Benchmark

```bash
# QUIC performance benchmark test
zig-out/bin/quic-test performance
```

#### Full QUIC Test

```bash
# Test all QUIC features
zig-out/bin/quic-test all
```

### 7. Eastsea Attestation Service (EAS) Testing

Eastsea Attestation Service is a system for off-chain data verification.

#### Basic EAS Functionality Test

```bash
# Test basic EAS functionality
zig build run-eas -- basic
```

#### EAS Schema Management Test

```bash
# Test EAS schema registration and management
zig build run-eas -- schema
```

#### EAS Attester Management Test

```bash
# Test EAS attester registration and management
zig build run-eas -- attester
```

#### EAS Attestation Creation and Management Test

```bash
# Test EAS attestation creation and management
zig build run-eas -- attestation
```

#### EAS Attestation Verification Test

```bash
# Test EAS attestation verification
zig build run-eas -- verification
```

#### EAS Reputation System Test

```bash
# Test EAS attester reputation system
zig build run-eas -- reputation
```

#### Full EAS Test

```bash
# Test all EAS features
zig build run-eas -- all
```

---

## FAQ

## Troubleshooting

### Common Problem Solving

#### 1. Build Errors

```bash
# Clean cache and rebuild
rm -rf .zig-cache zig-out
zig build
```

#### 2. Port Conflicts

```bash
# Check ports in use
lsof -i :8000

# Use different port
zig build run-p2p -- 8001
```

#### 3. Network Connection Issues

```bash
# Check firewall settings (macOS)
sudo pfctl -sr | grep 8000

# Test network connection
nc -zv 127.0.0.1 8000
```

#### 4. Memory Issues

```bash
# Run with debug mode to check memory usage
zig build run -Doptimize=Debug
```

### Performance Optimization

#### 1. Release Mode Build

```bash
# Optimized build
zig build -Doptimize=ReleaseFast
zig build run
```

#### 2. Memory Usage Monitoring

```bash
# Monitor system resources (macOS)
top -pid $(pgrep eastsea)

# Memory profiling (Linux)
valgrind --tool=massif zig build run
```

### Logs and Debugging

#### 1. Detailed Log Output

```bash
# Run with debug information
ZIG_LOG_LEVEL=debug zig build run
```

#### 2. Network Traffic Monitoring

```bash
# Capture network packets (tcpdump)
sudo tcpdump -i lo0 port 8000

# Packet analysis with Wireshark
wireshark -i lo0 -f "port 8000"
```

---

## FAQ

### Q1: Is Eastsea a real cryptocurrency?

A: No, Eastsea is a blockchain clone for educational and research purposes. It is not a cryptocurrency with real value.

### Q2: Is it compatible with other blockchains?

A: Eastsea is an independent blockchain and is not directly compatible with other blockchains. However, the JSON-RPC API follows standards.

### Q3: Can it be used in a production environment?

A: The current version is designed for development and testing purposes. Additional security review and optimization are needed for production use.

### Q4: Can it run on Windows?

A: Yes, Zig supports cross-platform, so it can run on Windows. However, some network features may have platform-specific differences.

### Q5: How do I create custom programs?

A: You can refer to the `src/programs/custom_program.zig` file to write new programs. See the developer guide for more details.

### Q6: Is there a limit to the number of nodes participating in the network?

A: Technically there is no limit, but the current implementation is optimized for small networks. Additional optimization is needed for large networks.

### Q7: Where is the data stored?

A: The current version uses in-memory storage. Additional implementation is needed for persistent storage.

### Q8: How does the consensus mechanism work?

A: Eastsea uses the Proof of History (PoH) consensus mechanism. This cryptographically proves the time sequence to achieve high throughput.

### Q9: Where can I find the API documentation?

A: You can find the complete API documentation in the `docs/API.md` file.

### Q10: How do I contribute?

A: Refer to the contribution guidelines in the `docs/DEVELOPER_GUIDE.md` file. You can contribute through issue reports or pull requests.

---

## Support

### Need Help?

- **GitHub Issues**: Bug reports and feature requests
- **Documentation**: Detailed documentation in the `docs/` directory
- **Community**: Zig community forums and Discord

### Additional Resources

- [Zig Official Documentation](https://ziglang.org/documentation/)
- [Blockchain Technology Overview](https://en.wikipedia.org/wiki/Blockchain)
- [Proof of History Explanation](https://medium.com/solana-labs/proof-of-history-a-clock-for-blockchain-cf47a61a9274)

---

## License

Eastsea is distributed under the MIT License. See the LICENSE file for details.