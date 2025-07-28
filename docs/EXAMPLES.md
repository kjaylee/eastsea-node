# Eastsea Code Examples

## Table of Contents

1. [Basic Usage Examples](#basic-usage-examples)
2. [JSON-RPC API Examples](#json-rpc-api-examples)
3. [P2P Network Examples](#p2p-network-examples)
4. [Smart Contract Examples](#smart-contract-examples)
5. [Wallet Integration Examples](#wallet-integration-examples)
6. [Advanced Network Features](#advanced-network-features)
7. [Testing Examples](#testing-examples)
8. [Performance Optimization Examples](#performance-optimization-examples)

---

## Basic Usage Examples

### 1. Starting a Basic Node

```bash
#!/bin/bash
# start_node.sh - Basic node startup script

echo "🚀 Starting Eastsea Node..."

# Build the project
zig build

# Start the node
zig build run
```

### 2. Multi-Node Network Setup

```bash
#!/bin/bash
# setup_network.sh - Setup a multi-node network

echo "🌐 Setting up Eastsea Network..."

# Start first node (bootstrap node)
echo "Starting bootstrap node on port 8000..."
zig build run-p2p -- 8000 &
BOOTSTRAP_PID=$!

# Wait for bootstrap node to start
sleep 2

# Start additional nodes
echo "Starting node 2 on port 8001..."
zig build run-p2p -- 8001 8000 &
NODE2_PID=$!

echo "Starting node 3 on port 8002..."
zig build run-p2p -- 8002 8000 &
NODE3_PID=$!

echo "Network setup complete!"
echo "Bootstrap node PID: $BOOTSTRAP_PID"
echo "Node 2 PID: $NODE2_PID"
echo "Node 3 PID: $NODE3_PID"

# Wait for user input to stop
read -p "Press Enter to stop all nodes..."

# Stop all nodes
kill $BOOTSTRAP_PID $NODE2_PID $NODE3_PID
echo "All nodes stopped."
```

### 3. DHT Network Setup

```bash
#!/bin/bash
# setup_dht.sh - Setup DHT network

echo "🔗 Setting up DHT Network..."

# Start DHT bootstrap node
echo "Starting DHT bootstrap node..."
zig build run-dht -- 8000 &
DHT_BOOTSTRAP_PID=$!

sleep 2

# Start additional DHT nodes
for port in 8001 8002 8003; do
    echo "Starting DHT node on port $port..."
    zig build run-dht -- $port 8000 &
done

echo "DHT network setup complete!"
read -p "Press Enter to stop..."
kill $(jobs -p)
```

---

## JSON-RPC API Examples

### 1. Python Client Example

```python
#!/usr/bin/env python3
# eastsea_client.py - Python client for Eastsea JSON-RPC API

import json
import requests
import time

class EastseaClient:
    def __init__(self, url="http://localhost:8545"):
        self.url = url
        self.request_id = 1
    
    def _make_request(self, method, params=None):
        """Make a JSON-RPC request"""
        payload = {
            "jsonrpc": "2.0",
            "method": method,
            "params": params or [],
            "id": self.request_id
        }
        self.request_id += 1
        
        try:
            response = requests.post(self.url, json=payload, timeout=10)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Request failed: {e}")
            return None
    
    def get_block_height(self):
        """Get current blockchain height"""
        return self._make_request("getBlockHeight")
    
    def get_balance(self, address):
        """Get account balance"""
        return self._make_request("getBalance", [address])
    
    def send_transaction(self, from_addr, to_addr, amount, signature=""):
        """Send a transaction"""
        params = {
            "from": from_addr,
            "to": to_addr,
            "amount": amount,
            "signature": signature
        }
        return self._make_request("sendTransaction", params)
    
    def get_node_info(self):
        """Get node information"""
        return self._make_request("getNodeInfo")
    
    def get_peers(self):
        """Get connected peers"""
        return self._make_request("getPeers")

def main():
    """Example usage"""
    client = EastseaClient()
    
    print("🚀 Eastsea Python Client Example")
    print("=" * 40)
    
    # Get block height
    height_response = client.get_block_height()
    if height_response and height_response.get("result") is not None:
        print(f"📦 Current block height: {height_response['result']}")
    
    # Get node info
    node_info = client.get_node_info()
    if node_info and node_info.get("result"):
        info = json.loads(node_info["result"])
        print(f"🌐 Node address: {info['address']}:{info['port']}")
        print(f"👥 Connected peers: {info['peer_count']}")
        print(f"🔗 Blockchain height: {info['blockchain_height']}")
    
    # Get peers
    peers = client.get_peers()
    if peers and peers.get("result"):
        peer_list = peers["result"]
        print(f"📡 Connected peers: {len(peer_list)}")
        for i, peer in enumerate(peer_list, 1):
            print(f"  {i}. {peer['address']}:{peer['port']}")
    
    # Example balance check (using demo account)
    demo_account = "ff7580ebeca78b5468b42e182fff7e8e820c37c3"
    balance = client.get_balance(demo_account)
    if balance and balance.get("result") is not None:
        print(f"💰 Account {demo_account[:8]}... balance: {balance['result']}")

if __name__ == "__main__":
    main()
```

### 2. JavaScript/Node.js Client Example

```javascript
#!/usr/bin/env node
// eastsea_client.js - JavaScript client for Eastsea

const axios = require('axios');

class EastseaClient {
    constructor(url = 'http://localhost:8545') {
        this.url = url;
        this.requestId = 1;
    }

    async makeRequest(method, params = []) {
        const payload = {
            jsonrpc: '2.0',
            method: method,
            params: params,
            id: this.requestId++
        };

        try {
            const response = await axios.post(this.url, payload, {
                timeout: 10000,
                headers: { 'Content-Type': 'application/json' }
            });
            return response.data;
        } catch (error) {
            console.error(`Request failed: ${error.message}`);
            return null;
        }
    }

    async getBlockHeight() {
        return await this.makeRequest('getBlockHeight');
    }

    async getBalance(address) {
        return await this.makeRequest('getBalance', [address]);
    }

    async sendTransaction(fromAddr, toAddr, amount, signature = '') {
        const params = {
            from: fromAddr,
            to: toAddr,
            amount: amount,
            signature: signature
        };
        return await this.makeRequest('sendTransaction', params);
    }

    async getNodeInfo() {
        return await this.makeRequest('getNodeInfo');
    }

    async getPeers() {
        return await this.makeRequest('getPeers');
    }
}

async function main() {
    console.log('🚀 Eastsea JavaScript Client Example');
    console.log('=' .repeat(40));

    const client = new EastseaClient();

    try {
        // Get block height
        const heightResponse = await client.getBlockHeight();
        if (heightResponse?.result !== undefined) {
            console.log(`📦 Current block height: ${heightResponse.result}`);
        }

        // Get node info
        const nodeInfo = await client.getNodeInfo();
        if (nodeInfo?.result) {
            const info = JSON.parse(nodeInfo.result);
            console.log(`🌐 Node address: ${info.address}:${info.port}`);
            console.log(`👥 Connected peers: ${info.peer_count}`);
            console.log(`🔗 Blockchain height: ${info.blockchain_height}`);
        }

        // Monitor blockchain height
        console.log('\n📊 Monitoring blockchain height (press Ctrl+C to stop)...');
        setInterval(async () => {
            const height = await client.getBlockHeight();
            if (height?.result !== undefined) {
                const timestamp = new Date().toLocaleTimeString();
                console.log(`[${timestamp}] Block height: ${height.result}`);
            }
        }, 5000);

    } catch (error) {
        console.error('Error:', error.message);
    }
}

if (require.main === module) {
    main();
}

module.exports = EastseaClient;
```

### 3. Bash/cURL Examples

```bash
#!/bin/bash
# eastsea_api_examples.sh - cURL examples for Eastsea API

API_URL="http://localhost:8545"

echo "🚀 Eastsea API Examples with cURL"
echo "================================="

# Function to make JSON-RPC request
make_request() {
    local method=$1
    local params=$2
    local id=${3:-1}
    
    if [ -z "$params" ]; then
        params="[]"
    fi
    
    curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"$method\",
            \"params\": $params,
            \"id\": $id
        }" | jq '.'
}

# Get block height
echo "📦 Getting block height..."
make_request "getBlockHeight"

echo ""

# Get node info
echo "🌐 Getting node info..."
make_request "getNodeInfo"

echo ""

# Get peers
echo "👥 Getting connected peers..."
make_request "getPeers"

echo ""

# Get balance (demo account)
echo "💰 Getting account balance..."
make_request "getBalance" '["ff7580ebeca78b5468b42e182fff7e8e820c37c3"]'

echo ""

# Send transaction example
echo "💸 Sending transaction..."
make_request "sendTransaction" '{
    "from": "ff7580ebeca78b5468b42e182fff7e8e820c37c3",
    "to": "0e56ad656c29a51263df1ca8e1a2d6169e95db51",
    "amount": 10,
    "signature": "demo_signature"
}'
```

---

## P2P Network Examples

### 1. Custom P2P Message Handler

```zig
// custom_p2p_handler.zig - Custom P2P message handling example

const std = @import("std");
const network = @import("../src/network/p2p.zig");

pub const CustomMessageHandler = struct {
    const Self = @This();
    
    allocator: std.mem.Allocator,
    node: *network.P2PNode,
    
    pub fn init(allocator: std.mem.Allocator, node: *network.P2PNode) Self {
        return Self{
            .allocator = allocator,
            .node = node,
        };
    }
    
    pub fn handleCustomMessage(self: *Self, peer_id: [32]u8, message: []const u8) !void {
        std.log.info("Received custom message from peer {}: {s}", .{ 
            std.fmt.fmtSliceHexLower(peer_id[0..8]), 
            message 
        });
        
        // Process custom message
        if (std.mem.eql(u8, message, "PING")) {
            try self.sendCustomResponse(peer_id, "PONG");
        } else if (std.mem.startsWith(u8, message, "ECHO:")) {
            const echo_msg = message[5..];
            try self.sendCustomResponse(peer_id, echo_msg);
        }
    }
    
    fn sendCustomResponse(self: *Self, peer_id: [32]u8, response: []const u8) !void {
        // Create custom message
        const custom_message = try self.allocator.alloc(u8, response.len + 1);
        defer self.allocator.free(custom_message);
        
        custom_message[0] = 0xFF; // Custom message type
        @memcpy(custom_message[1..], response);
        
        // Send to peer
        try self.node.sendToPeer(peer_id, custom_message);
        
        std.log.info("Sent custom response to peer {}: {s}", .{ 
            std.fmt.fmtSliceHexLower(peer_id[0..8]), 
            response 
        });
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize P2P node
    var node = try network.P2PNode.init(allocator, "127.0.0.1", 8000);
    defer node.deinit();
    
    // Initialize custom handler
    var handler = CustomMessageHandler.init(allocator, &node);
    
    // Start node
    try node.start();
    
    std.log.info("Custom P2P node started on 127.0.0.1:8000");
    std.log.info("Send custom messages: PING, ECHO:your_message");
    
    // Keep running
    while (true) {
        std.time.sleep(1000000000); // 1 second
    }
}
```

### 2. DHT Key-Value Store Example

```zig
// dht_storage_example.zig - DHT key-value storage example

const std = @import("std");
const dht = @import("../src/network/dht.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize DHT node
    var dht_node = try dht.DHT.init(allocator, "127.0.0.1", 8000);
    defer dht_node.deinit();
    
    std.log.info("🔗 DHT Key-Value Store Example");
    std.log.info("==============================");
    
    // Store some key-value pairs
    const keys_values = [_]struct { key: []const u8, value: []const u8 }{
        .{ .key = "user:alice", .value = "Alice Smith, age 30" },
        .{ .key = "user:bob", .value = "Bob Jones, age 25" },
        .{ .key = "config:max_peers", .value = "50" },
        .{ .key = "config:timeout", .value = "30000" },
    };
    
    // Store values in DHT
    for (keys_values) |kv| {
        var key_hash: [20]u8 = undefined;
        std.crypto.hash.Sha1.hash(kv.key, &key_hash, .{});
        
        try dht_node.store(key_hash, kv.value);
        std.log.info("📝 Stored: {s} -> {s}", .{ kv.key, kv.value });
    }
    
    // Retrieve values from DHT
    std.log.info("\n🔍 Retrieving values from DHT:");
    for (keys_values) |kv| {
        var key_hash: [20]u8 = undefined;
        std.crypto.hash.Sha1.hash(kv.key, &key_hash, .{});
        
        if (try dht_node.findValue(key_hash)) |value| {
            std.log.info("✅ Found: {s} -> {s}", .{ kv.key, value });
        } else {
            std.log.info("❌ Not found: {s}", .{kv.key});
        }
    }
    
    // Find closest nodes to a target
    std.log.info("\n🎯 Finding closest nodes:");
    var target_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash("target_node", &target_hash, .{});
    
    const closest_nodes = try dht_node.findNode(target_hash);
    std.log.info("Found {} closest nodes", .{closest_nodes.len});
    
    for (closest_nodes, 0..) |node, i| {
        std.log.info("  {}. Node {} at {}:{}", .{ 
            i + 1, 
            std.fmt.fmtSliceHexLower(node.id[0..8]), 
            node.address, 
            node.port 
        });
    }
}
```

---

## Smart Contract Examples

### 1. Custom Token Contract

```zig
// custom_token.zig - Custom token smart contract example

const std = @import("std");
const program = @import("../src/programs/program.zig");

pub const TokenContract = struct {
    const Self = @This();
    
    // Token state
    name: []const u8,
    symbol: []const u8,
    total_supply: u64,
    decimals: u8,
    balances: std.HashMap([]const u8, u64),
    allowances: std.HashMap([]const u8, std.HashMap([]const u8, u64)),
    
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, name: []const u8, symbol: []const u8, total_supply: u64) !Self {
        return Self{
            .name = name,
            .symbol = symbol,
            .total_supply = total_supply,
            .decimals = 18,
            .balances = std.HashMap([]const u8, u64).init(allocator),
            .allowances = std.HashMap([]const u8, std.HashMap([]const u8, u64)).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.balances.deinit();
        self.allowances.deinit();
    }
    
    // ERC-20 like functions
    pub fn balanceOf(self: *Self, account: []const u8) u64 {
        return self.balances.get(account) orelse 0;
    }
    
    pub fn transfer(self: *Self, from: []const u8, to: []const u8, amount: u64) !bool {
        const from_balance = self.balanceOf(from);
        if (from_balance < amount) {
            return false; // Insufficient balance
        }
        
        const to_balance = self.balanceOf(to);
        
        try self.balances.put(from, from_balance - amount);
        try self.balances.put(to, to_balance + amount);
        
        std.log.info("💸 Transfer: {} {} from {} to {}", .{ amount, self.symbol, from, to });
        return true;
    }
    
    pub fn approve(self: *Self, owner: []const u8, spender: []const u8, amount: u64) !bool {
        var owner_allowances = self.allowances.get(owner) orelse std.HashMap([]const u8, u64).init(self.allocator);
        try owner_allowances.put(spender, amount);
        try self.allowances.put(owner, owner_allowances);
        
        std.log.info("✅ Approval: {} approved {} {} for {}", .{ owner, spender, amount, self.symbol });
        return true;
    }
    
    pub fn transferFrom(self: *Self, spender: []const u8, from: []const u8, to: []const u8, amount: u64) !bool {
        const allowance = self.allowance(from, spender);
        if (allowance < amount) {
            return false; // Insufficient allowance
        }
        
        if (!try self.transfer(from, to, amount)) {
            return false; // Transfer failed
        }
        
        // Reduce allowance
        var from_allowances = self.allowances.get(from).?;
        try from_allowances.put(spender, allowance - amount);
        
        return true;
    }
    
    pub fn allowance(self: *Self, owner: []const u8, spender: []const u8) u64 {
        if (self.allowances.get(owner)) |owner_allowances| {
            return owner_allowances.get(spender) orelse 0;
        }
        return 0;
    }
    
    pub fn mint(self: *Self, to: []const u8, amount: u64) !void {
        const balance = self.balanceOf(to);
        try self.balances.put(to, balance + amount);
        self.total_supply += amount;
        
        std.log.info("🪙 Minted {} {} to {}", .{ amount, self.symbol, to });
    }
    
    pub fn burn(self: *Self, from: []const u8, amount: u64) !bool {
        const balance = self.balanceOf(from);
        if (balance < amount) {
            return false; // Insufficient balance
        }
        
        try self.balances.put(from, balance - amount);
        self.total_supply -= amount;
        
        std.log.info("🔥 Burned {} {} from {}", .{ amount, self.symbol, from });
        return true;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.log.info("🪙 Custom Token Contract Example");
    std.log.info("================================");
    
    // Create a custom token
    var token = try TokenContract.init(allocator, "EastseaCoin", "EAST", 1000000);
    defer token.deinit();
    
    // Initial mint to creator
    const creator = "creator_address";
    const alice = "alice_address";
    const bob = "bob_address";
    
    try token.mint(creator, 1000000);
    
    std.log.info("📊 Initial state:");
    std.log.info("  Total supply: {}", .{token.total_supply});
    std.log.info("  Creator balance: {}", .{token.balanceOf(creator)});
    
    // Transfer tokens
    _ = try token.transfer(creator, alice, 10000);
    _ = try token.transfer(creator, bob, 5000);
    
    std.log.info("\n📊 After transfers:");
    std.log.info("  Creator balance: {}", .{token.balanceOf(creator)});
    std.log.info("  Alice balance: {}", .{token.balanceOf(alice)});
    std.log.info("  Bob balance: {}", .{token.balanceOf(bob)});
    
    // Approval and transferFrom
    _ = try token.approve(alice, bob, 1000);
    _ = try token.transferFrom(bob, alice, creator, 500);
    
    std.log.info("\n📊 After approval and transferFrom:");
    std.log.info("  Alice balance: {}", .{token.balanceOf(alice)});
    std.log.info("  Creator balance: {}", .{token.balanceOf(creator)});
    std.log.info("  Remaining allowance: {}", .{token.allowance(alice, bob)});
    
    // Burn tokens
    _ = try token.burn(creator, 100000);
    
    std.log.info("\n📊 After burning:");
    std.log.info("  Total supply: {}", .{token.total_supply});
    std.log.info("  Creator balance: {}", .{token.balanceOf(creator)});
}
```

### 2. Multi-Signature Wallet Contract

```zig
// multisig_wallet.zig - Multi-signature wallet contract example

const std = @import("std");

pub const MultiSigWallet = struct {
    const Self = @This();
    
    const Transaction = struct {
        to: []const u8,
        amount: u64,
        data: []const u8,
        executed: bool,
        confirmations: std.ArrayList([]const u8),
    };
    
    owners: std.ArrayList([]const u8),
    required_confirmations: u32,
    transactions: std.ArrayList(Transaction),
    balance: u64,
    
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, owners: []const []const u8, required: u32) !Self {
        var owner_list = std.ArrayList([]const u8).init(allocator);
        for (owners) |owner| {
            try owner_list.append(owner);
        }
        
        return Self{
            .owners = owner_list,
            .required_confirmations = required,
            .transactions = std.ArrayList(Transaction).init(allocator),
            .balance = 0,
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Self) void {
        for (self.transactions.items) |*tx| {
            tx.confirmations.deinit();
        }
        self.transactions.deinit();
        self.owners.deinit();
    }
    
    pub fn isOwner(self: *Self, address: []const u8) bool {
        for (self.owners.items) |owner| {
            if (std.mem.eql(u8, owner, address)) {
                return true;
            }
        }
        return false;
    }
    
    pub fn deposit(self: *Self, amount: u64) void {
        self.balance += amount;
        std.log.info("💰 Deposited {} to multisig wallet. New balance: {}", .{ amount, self.balance });
    }
    
    pub fn submitTransaction(self: *Self, from: []const u8, to: []const u8, amount: u64, data: []const u8) !u32 {
        if (!self.isOwner(from)) {
            return error.NotOwner;
        }
        
        var confirmations = std.ArrayList([]const u8).init(self.allocator);
        try confirmations.append(from); // Submitter automatically confirms
        
        const transaction = Transaction{
            .to = to,
            .amount = amount,
            .data = data,
            .executed = false,
            .confirmations = confirmations,
        };
        
        try self.transactions.append(transaction);
        const tx_id = @as(u32, @intCast(self.transactions.items.len - 1));
        
        std.log.info("📝 Transaction {} submitted by {}: {} to {}", .{ tx_id, from, amount, to });
        return tx_id;
    }
    
    pub fn confirmTransaction(self: *Self, tx_id: u32, from: []const u8) !void {
        if (!self.isOwner(from)) {
            return error.NotOwner;
        }
        
        if (tx_id >= self.transactions.items.len) {
            return error.InvalidTransaction;
        }
        
        var transaction = &self.transactions.items[tx_id];
        if (transaction.executed) {
            return error.AlreadyExecuted;
        }
        
        // Check if already confirmed by this owner
        for (transaction.confirmations.items) |confirmer| {
            if (std.mem.eql(u8, confirmer, from)) {
                return error.AlreadyConfirmed;
            }
        }
        
        try transaction.confirmations.append(from);
        std.log.info("✅ Transaction {} confirmed by {} ({}/{})", .{ 
            tx_id, 
            from, 
            transaction.confirmations.items.len, 
            self.required_confirmations 
        });
        
        // Execute if enough confirmations
        if (transaction.confirmations.items.len >= self.required_confirmations) {
            try self.executeTransaction(tx_id);
        }
    }
    
    pub fn executeTransaction(self: *Self, tx_id: u32) !void {
        if (tx_id >= self.transactions.items.len) {
            return error.InvalidTransaction;
        }
        
        var transaction = &self.transactions.items[tx_id];
        if (transaction.executed) {
            return error.AlreadyExecuted;
        }
        
        if (transaction.confirmations.items.len < self.required_confirmations) {
            return error.InsufficientConfirmations;
        }
        
        if (self.balance < transaction.amount) {
            return error.InsufficientBalance;
        }
        
        // Execute transaction
        self.balance -= transaction.amount;
        transaction.executed = true;
        
        std.log.info("🚀 Transaction {} executed: {} sent to {}", .{ 
            tx_id, 
            transaction.amount, 
            transaction.to 
        });
    }
    
    pub fn getTransactionCount(self: *Self) u32 {
        return @as(u32, @intCast(self.transactions.items.len));
    }
    
    pub fn getTransaction(self: *Self, tx_id: u32) ?*const Transaction {
        if (tx_id >= self.transactions.items.len) {
            return null;
        }
        return &self.transactions.items[tx_id];
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.log.info("🔐 Multi-Signature Wallet Example");
    std.log.info("=================================");
    
    // Create multisig wallet with 3 owners, requiring 2 confirmations
    const owners = [_][]const u8{ "alice", "bob", "charlie" };
    var wallet = try MultiSigWallet.init(allocator, &owners, 2);
    defer wallet.deinit();
    
    // Deposit funds
    wallet.deposit(1000);
    
    // Submit transaction
    const tx_id = try wallet.submitTransaction("alice", "recipient", 500, "");
    
    // Confirm transaction (need 2 confirmations)
    try wallet.confirmTransaction(tx_id, "bob");
    
    std.log.info("\n📊 Final wallet state:");
    std.log.info("  Balance: {}", .{wallet.balance});
    std.log.info("  Transaction count: {}", .{wallet.getTransactionCount()});
    
    if (wallet.getTransaction(tx_id)) |tx| {
        std.log.info("  Transaction {} status: {}", .{ tx_id, if (tx.executed) "Executed" else "Pending" });
    }
}
```

---

## Wallet Integration Examples

### 1. Simple Wallet CLI

```zig
// wallet_cli.zig - Simple wallet command-line interface

const std = @import("std");
const wallet = @import("../src/cli/wallet.zig");
const crypto = @import("../src/crypto/hash.zig");

pub const WalletCLI = struct {
    const Self = @This();
    
    allocator: std.mem.Allocator,
    wallet_instance: wallet.Wallet,
    
    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .wallet_instance = try wallet.Wallet.init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.wallet_instance.deinit();
    }
    
    pub fn run(self: *Self) !void {
        std.log.info("💼 Eastsea Wallet CLI");
        std.log.info("====================");
        
        while (true) {
            try self.printMenu();
            
            const input = try self.readInput();
            defer self.allocator.free(input);
            
            const choice = std.fmt.parseInt(u32, std.mem.trim(u8, input, " \n\r"), 10) catch {
                std.log.info("❌ Invalid input. Please enter a number.");
                continue;
            };
            
            switch (choice) {
                1 => try self.createAccount(),
                2 => try self.listAccounts(),
                3 => try self.checkBalance(),
                4 => try self.sendTransaction(),
                5 => try self.importAccount(),
                6 => try self.exportAccount(),
                0 => {
                    std.log.info("👋 Goodbye!");
                    break;
                },
                else => std.log.info("❌ Invalid choice. Please try again."),
            }
        }
    }
    
    fn printMenu(self: *Self) !void {
        _ = self;
        std.log.info("\n📋 Wallet Menu:");
        std.log.info("1. Create new account");
        std.log.info("2. List accounts");
        std.log.info("3. Check balance");
        std.log.info("4. Send transaction");
        std.log.info("5. Import account");
        std.log.info("6. Export account");
        std.log.info("0. Exit");
        std.log.info("Enter your choice: ");
    }
    
    fn readInput(self: *Self) ![]u8 {
        const stdin = std.io.getStdIn().reader();
        const input = try stdin.readUntilDelimiterAlloc(self.allocator, '\n', 1024);
        return input;
    }
    
    fn createAccount(self: *Self) !void {
        std.log.info("\n🔑 Creating new account...");
        
        const account = try self.wallet_instance.createAccount();
        
        std.log.info("✅ Account created successfully!");
        std.log.info("Address: {s}", .{account.address});
        std.log.info("⚠️  Keep your private key safe!");
    }
    
    fn listAccounts(self: *Self) !void {
        std.log.info("\n📋 Account List:");
        
        const accounts = self.wallet_instance.getAccounts();
        if (accounts.len == 0) {
            std.log.info("No accounts found. Create one first.");
            return;
        }
        
        for (accounts, 0..) |account, i| {
            const balance = self.wallet_instance.getBalance(account.address) catch 0;
            std.log.info("{}. {} (Balance: {})", .{ i + 1, account.address, balance });
        }
    }
    
    fn checkBalance(self: *Self) !void {
        std.log.info("\n💰 Check Balance");
        std.log.info("Enter account address: ");
        
        const address = try self.readInput();
        defer self.allocator.free(address);
        
        const trimmed_address = std.mem.trim(u8, address, " \n\r");
        const balance = self.wallet_instance.getBalance(trimmed_address) catch {
            std.log.info("❌ Error getting balance. Check the address.");
            return;
        };
        
        std.log.info("Balance: {}", .{balance});
    }
    
    fn sendTransaction(self: *Self) !void {
        std.log.info("\n💸 Send Transaction");
        
        std.log.info("From address: ");
        const from = try self.readInput();
        defer self.allocator.free(from);
        
        std.log.info("To address: ");
        const to = try self.readInput();
        defer self.allocator.free(to);
        
        std.log.info("Amount: ");
        const amount_str = try self.readInput();
        defer self.allocator.free(amount_str);
        
        const amount = std.fmt.parseInt(u64, std.mem.trim(u8, amount_str, " \n\r"), 10) catch {
            std.log.info("❌ Invalid amount.");
            return;
        };
        
        const from_trimmed = std.mem.trim(u8, from, " \n\r");
        const to_trimmed = std.mem.trim(u8, to, " \n\r");
        
        const tx_hash = self.wallet_instance.transfer(from_trimmed, to_trimmed, amount) catch |err| {
            std.log.info("❌ Transaction failed: {}", .{err});
            return;
        };
        
        std.log.info("✅ Transaction sent successfully!");
        std.log.info("Transaction hash: {s}", .{tx_hash});
    }
    
    fn importAccount(self: *Self) !void {
        std.log.info("\n📥 Import Account");
        std.log.info("Enter private key (hex): ");
        
        const private_key_hex = try self.readInput();
        defer self.allocator.free(private_key_hex);
        
        // Parse hex private key
        const trimmed_key = std.mem.trim(u8, private_key_hex, " \n\r");
        if (trimmed_key.len != 64) {
            std.log.info("❌ Invalid private key length. Expected 64 hex characters.");
            return;
        }
        
        var private_key: [32]u8 = undefined;
        _ = std.fmt.hexToBytes(&private_key, trimmed_key) catch {
            std.log.info("❌ Invalid hex format.");
            return;
        };
        
        const account = self.wallet_instance.importAccount(private_key) catch {
            std.log.info("❌ Failed to import account.");
            return;
        };
        
        std.log.info("✅ Account imported successfully!");
        std.log.info("Address: {s}", .{account.address});
    }
    
    fn exportAccount(self: *Self) !void {
        std.log.info("\n📤 Export Account");
        std.log.info("Enter account address: ");
        
        const address = try self.readInput();
        defer self.allocator.free(address);
        
        const trimmed_address = std.mem.trim(u8, address, " \n\r");
        const private_key = self.wallet_instance.exportAccount(trimmed_address) catch {
            std.log.info("❌ Account not found or export failed.");
            return;
        };
        
        std.log.info("✅ Account exported successfully!");
        std.log.info("Private key: {}", .{std.fmt.fmtSliceHexLower(&private_key)});
        std.log.info("⚠️  Keep this private key secure and never share it!");
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var cli = try WalletCLI.init(allocator);
    defer cli.deinit();
    
    try cli.run();
}
```

---

## Advanced Network Features

### 1. Custom Discovery Protocol

```zig
// custom_discovery.zig - Custom peer discovery protocol

const std = @import("std");
const network = @import("../src/network/auto_discovery.zig");

pub const CustomDiscovery = struct {
    const Self = @This();
    
    const DiscoveryMessage = struct {
        message_type: u8,
        node_id: [32]u8,
        address: [4]u8, // IPv4
        port: u16,
        timestamp: u64,
        services: u32, // Bitmask of supported services
    };
    
    allocator: std.mem.Allocator,
    node_id: [32]u8,
    local_port: u16,
    discovered_peers: std.ArrayList(DiscoveryMessage),
    
    pub fn init(allocator: std.mem.Allocator, port: u16) !Self {
        var node_id: [32]u8 = undefined;
        std.crypto.random.bytes(&node_id);
        
        return Self{
            .allocator = allocator,
            .node_id = node_id,
            .local_port = port,
            .discovered_peers = std.ArrayList(DiscoveryMessage).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.discovered_peers.deinit();
    }
    
    pub fn startDiscovery(self: *Self) !void {
        std.log.info("🔍 Starting custom peer discovery on port {}", .{self.local_port});
        
        // Start UDP listener for discovery messages
        const address = try std.net.Address.parseIp4("0.0.0.0", self.local_port);
        const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(socket);
        
        try std.posix.bind(socket, &address.any, address.getOsSockLen());
        
        // Broadcast our presence
        try self.broadcastPresence();
        
        // Listen for discovery messages
        var buffer: [1024]u8 = undefined;
        while (true) {
            var peer_addr: std.posix.sockaddr = undefined;
            var addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);
            
            const bytes_received = std.posix.recvfrom(
                socket, 
                &buffer, 
                0, 
                &peer_addr, 
                &addr_len
            ) catch |err| {
                std.log.err("Failed to receive discovery message: {}", .{err});
                continue;
            };
            
            try self.handleDiscoveryMessage(buffer[0..bytes_received]);
        }
    }
    
    fn broadcastPresence(self: *Self) !void {
        const broadcast_addr = try std.net.Address.parseIp4("255.255.255.255", 9999);
        const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(socket);
        
        // Enable broadcast
        const broadcast_enable: c_int = 1;
        try std.posix.setsockopt(
            socket, 
            std.posix.SOL.SOCKET, 
            std.posix.SO.BROADCAST, 
            std.mem.asBytes(&broadcast_enable)
        );
        
        const message = DiscoveryMessage{
            .message_type = 0x01, // ANNOUNCE
            .node_id = self.node_id,
            .address = [4]u8{ 127, 0, 0, 1 }, // localhost for demo
            .port = self.local_port,
            .timestamp = @as(u64, @intCast(std.time.milliTimestamp())),
            .services = 0x01, // Basic blockchain services
        };
        
        const message_bytes = std.mem.asBytes(&message);
        _ = try std.posix.sendto(
            socket, 
            message_bytes, 
            0, 
            &broadcast_addr.any, 
            broadcast_addr.getOsSockLen()
        );
        
        std.log.info("📡 Broadcasted presence: Node {}", .{
            std.fmt.fmtSliceHexLower(self.node_id[0..8])
        });
    }
    
    fn handleDiscoveryMessage(self: *Self, data: []const u8) !void {
        if (data.len < @sizeOf(DiscoveryMessage)) {
            return; // Invalid message size
        }
        
        const message = @as(*const DiscoveryMessage, @ptrCast(@alignCast(data.ptr))).*;
        
        // Ignore our own messages
        if (std.mem.eql(u8, &message.node_id, &self.node_id)) {
            return;
        }
        
        switch (message.message_type) {
            0x01 => { // ANNOUNCE
                try self.handleAnnouncement(message);
            },
            0x02 => { // REQUEST
                try self.handleRequest(message);
            },
            0x03 => { // RESPONSE
                try self.handleResponse(message);
            },
            else => {
                std.log.warn("Unknown discovery message type: 0x{X}", .{message.message_type});
            },
        }
    }
    
    fn handleAnnouncement(self: *Self, message: DiscoveryMessage) !void {
        // Check if we already know this peer
        for (self.discovered_peers.items) |peer| {
            if (std.mem.eql(u8, &peer.node_id, &message.node_id)) {
                return; // Already known
            }
        }
        
        try self.discovered_peers.append(message);
        
        std.log.info("🆕 Discovered new peer: {} at {}:{} via TCP", .{
            std.fmt.fmtSliceHexLower(message.node_id[0..8]),
            std.fmt.fmtSliceHexLower(&message.address),
            message.port,
        });
        
        // Send our own announcement back
        try self.sendDirectResponse(message);
    }
    
    fn handleRequest(self: *Self, message: DiscoveryMessage) !void {
        std.log.info("📥 Received discovery request from {}", .{
            std.fmt.fmtSliceHexLower(message.node_id[0..8])
        });
        
        try self.sendDirectResponse(message);
    }
    
    fn handleResponse(self: *Self, message: DiscoveryMessage) !void {
        std.log.info("📨 Received discovery response from {}", .{
            std.fmt.fmtSliceHexLower(message.node_id[0..8])
        });
        
        try self.handleAnnouncement(message);
    }
    
    fn sendDirectResponse(self: *Self, original_message: DiscoveryMessage) !void {
        const response_addr = try std.net.Address.initIp4(original_message.address, original_message.port);
        const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(socket);
        
        const response = DiscoveryMessage{
            .message_type = 0x03, // RESPONSE
            .node_id = self.node_id,
            .address = [4]u8{ 127, 0, 0, 1 },
            .port = self.local_port,
            .timestamp = @as(u64, @intCast(std.time.milliTimestamp())),
            .services = 0x01,
        };
        
        const response_bytes = std.mem.asBytes(&response);
        _ = try std.posix.sendto(
            socket, 
            response_bytes, 
            0, 
            &response_addr.any, 
            response_addr.getOsSockLen()
        );
    }
    
    pub fn getPeers(self: *Self) []const DiscoveryMessage {
        return self.discovered_peers.items;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    const port = if (args.len > 1) 
        try std.fmt.parseInt(u16, args[1], 10) 
    else 
        8000;
    
    var discovery = try CustomDiscovery.init(allocator, port);
    defer discovery.deinit();
    
    try discovery.startDiscovery();
}
```

### 2. QUIC Network Example

```zig
// quic_network_example.zig - QUIC-based network communication example

const std = @import("std");
const network = @import("../src/network/quic.zig");

pub const QuicNetworkExample = struct {
    const Self = @This();
    
    allocator: std.mem.Allocator,
    quic_node: *network.QuicNode,
    
    pub fn init(allocator: std.mem.Allocator, port: u16) !Self {
        const quic_node = try allocator.create(network.QuicNode);
        quic_node.* = try network.QuicNode.init(allocator, port);
        
        return Self{
            .allocator = allocator,
            .quic_node = quic_node,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.quic_node.deinit();
        self.allocator.destroy(self.quic_node);
    }
    
    pub fn startNode(self: *Self) !void {
        try self.quic_node.start();
        std.log.info("🚀 QUIC node started on port {}", .{self.quic_node.address.getPort()});
    }
    
    pub fn connectToPeer(self: *Self, peer_address: []const u8, peer_port: u16) !void {
        const address = try std.net.Address.parseIp4(peer_address, peer_port);
        const connection = try self.quic_node.connectToPeer(address);
        
        std.log.info("🤝 Connected to peer {}:{}", .{ peer_address, peer_port });
        
        // Create a stream for communication
        const stream = try connection.createStream(true); // Bidirectional
        
        // Send a test message
        const message = "Hello from QUIC!";
        try stream.send(message);
        
        std.log.info("📤 Sent message: \"{s}\"", .{message});
        
        // Receive response
        var buffer: [1024]u8 = undefined;
        const bytes_received = try stream.receive(&buffer);
        
        if (bytes_received > 0) {
            std.log.info("📥 Received response: \"{s}\"", .{buffer[0..bytes_received]});
        }
    }
    
    pub fn runServer(self: *Self) !void {
        try self.quic_node.start();
        
        // Register message handlers
        try self.quic_node.registerMessageHandler(0, handleTestMessage);
        try self.quic_node.registerMessageHandler(1, handleBlockMessage);
        try self.quic_node.registerMessageHandler(2, handleTransactionMessage);
        
        std.log.info("🌐 QUIC server listening on port {}", .{self.quic_node.address.getPort()});
        
        // Accept connections
        try self.quic_node.acceptConnections();
    }
    
    pub fn sendTestMessage(self: *Self, peer_address: []const u8, peer_port: u16) !void {
        const address = try std.net.Address.parseIp4(peer_address, peer_port);
        const connection = try self.quic_node.connectToPeer(address);
        
        var message = try network.QuicMessage.init(self.allocator, 0, "Test QUIC message");
        defer message.deinit();
        
        try connection.sendMessage(&message);
        
        std.log.info("📤 Test message sent to {}:{}", .{ peer_address, peer_port });
    }
};

// Message handlers
fn handleTestMessage(node: *network.QuicNode, connection: *network.QuicConnection, message: *const network.QuicMessage) !void {
    _ = node;
    std.log.info("📥 Received test message from connection: {s}", .{message.payload});
    
    // Send response
    var response = try network.QuicMessage.init(node.allocator, 0, "QUIC test response");
    defer response.deinit();
    
    try connection.sendMessage(&response);
}

fn handleBlockMessage(node: *network.QuicNode, connection: *network.QuicConnection, message: *const network.QuicMessage) !void {
    _ = node;
    _ = connection;
    std.log.info("📦 Received block message: {} bytes", .{message.payload.len});
    
    // Process block (in a real implementation)
    std.log.info("✅ Block processed successfully", .{});
}

fn handleTransactionMessage(node: *network.QuicNode, connection: *network.QuicConnection, message: *const network.QuicMessage) !void {
    _ = node;
    _ = connection;
    std.log.info("💸 Received transaction message: {} bytes", .{message.payload.len});
    
    // Process transaction (in a real implementation)
    std.log.info("✅ Transaction processed successfully", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2) {
        std.log.err("Usage: {} <mode> [port] [peer_address] [peer_port]", .{args[0]});
        std.log.err("Modes: server, client", .{});
        return;
    }
    
    const mode = args[1];
    
    if (std.mem.eql(u8, mode, "server")) {
        const port = if (args.len > 2) try std.fmt.parseInt(u16, args[2], 10) else 8000;
        
        var example = try QuicNetworkExample.init(allocator, port);
        defer example.deinit();
        
        try example.runServer();
    } else if (std.mem.eql(u8, mode, "client")) {
        const port = if (args.len > 2) try std.fmt.parseInt(u16, args[2], 10) else 8001;
        const peer_address = if (args.len > 3) args[3] else "127.0.0.1";
        const peer_port = if (args.len > 4) try std.fmt.parseInt(u16, args[4], 10) else 8000;
        
        var example = try QuicNetworkExample.init(allocator, port);
        defer example.deinit();
        
        try example.startNode();
        try example.sendTestMessage(peer_address, peer_port);
    } else {
        std.log.err("Invalid mode. Use 'server' or 'client'", .{});
        return;
    }
}
```

---

## Testing Examples

### 1. Comprehensive Test Suite

```zig
// comprehensive_tests.zig - Comprehensive test suite example

const std = @import("std");
const testing = std.testing;

// Import modules to test
const blockchain = @import("../src/blockchain/blockchain.zig");
const p2p = @import("../src/network/p2p.zig");
const wallet = @import("../src/cli/wallet.zig");

// Test configuration
const TestConfig = struct {
    timeout_ms: u64 = 5000,
    max_retries: u32 = 3,
    test_data_size: usize = 1000,
};

const config = TestConfig{};

// Test utilities
fn createTestAllocator() std.testing.Allocator {
    return std.testing.allocator;
}

fn generateTestData(allocator: std.mem.Allocator, size: usize) ![]u8 {
    const data = try allocator.alloc(u8, size);
    for (data, 0..) |*byte, i| {
        byte.* = @as(u8, @intCast(i % 256));
    }
    return data;
}

// Blockchain tests
test "blockchain creation and validation" {
    const allocator = createTestAllocator();
    
    var chain = try blockchain.Blockchain.init(allocator);
    defer chain.deinit();
    
    // Test genesis block
    try testing.expect(chain.getHeight() == 1);
    try testing.expect(chain.isValid());
    
    // Create test transaction
    const tx = blockchain.Transaction{
        .from = [_]u8{0x01} ** 20,
        .to = [_]u8{0x02} ** 20,
        .amount = 100,
        .timestamp = @as(u64, @intCast(std.time.milliTimestamp())),
        .signature = [_]u8{0} ** 64,
        .hash = [_]u8{0} ** 32,
    };
    
    // Add transaction and mine block
    try chain.addTransaction(tx);
    try chain.mineBlock();
    
    try testing.expect(chain.getHeight() == 2);
    try testing.expect(chain.isValid());
}

test "transaction validation" {
    const allocator = createTestAllocator();
    
    var chain = try blockchain.Blockchain.init(allocator);
    defer chain.deinit();
    
    // Test valid transaction
    var valid_tx = blockchain.Transaction{
        .from = [_]u8{0x01} ** 20,
        .to = [_]u8{0x02} ** 20,
        .amount = 50,
        .timestamp = @as(u64, @intCast(std.time.milliTimestamp())),
        .signature = [_]u8{0} ** 64,
        .hash = [_]u8{0} ** 32,
    };
    
    // Calculate proper hash
    valid_tx.hash = valid_tx.calculateHash();
    
    try testing.expect(valid_tx.isValid());
    
    // Test invalid transaction (zero amount)
    var invalid_tx = valid_tx;
    invalid_tx.amount = 0;
    
    try testing.expect(!invalid_tx.isValid());
}

test "wallet operations" {
    const allocator = createTestAllocator();
    
    var test_wallet = try wallet.Wallet.init(allocator);
    defer test_wallet.deinit();
    
    // Create accounts
    const account1 = try test_wallet.createAccount();
    const account2 = try test_wallet.createAccount();
    
    try testing.expect(account1.address.len > 0);
    try testing.expect(account2.address.len > 0);
    try testing.expect(!std.mem.eql(u8, account1.address, account2.address));
    
    // Test balance operations
    const initial_balance = test_wallet.getBalance(account1.address) catch 0;
    try testing.expect(initial_balance >= 0);
    
    // Test transaction creation
    const tx_hash = test_wallet.transfer(account1.address, account2.address, 10) catch |err| {
        // Transfer might fail due to insufficient balance, which is expected
        try testing.expect(err == error.InsufficientBalance);
        return;
    };
    
    try testing.expect(tx_hash.len > 0);
}

// Network tests
test "p2p node creation and basic operations" {
    const allocator = createTestAllocator();
    
    var node = try p2p.P2PNode.init(allocator, "127.0.0.1", 0); // Use port 0 for auto-assignment
    defer node.deinit();
    
    try testing.expect(node.getPeerCount() == 0);
    
    // Test message creation
    const test_message = try allocator.alloc(u8, 100);
    defer allocator.free(test_message);
    
    for (test_message, 0..) |*byte, i| {
        byte.* = @as(u8, @intCast(i % 256));
    }
    
    // Node should be able to handle message serialization
    // (Actual network testing would require multiple processes)
}

// Performance tests
test "blockchain performance" {
    const allocator = createTestAllocator();
    
    var chain = try blockchain.Blockchain.init(allocator);
    defer chain.deinit();
    
    const start_time = std.time.milliTimestamp();
    const num_transactions = 1000;
    
    // Add many transactions
    for (0..num_transactions) |i| {
        const tx = blockchain.Transaction{
            .from = [_]u8{@as(u8, @intCast(i % 256))} ** 20,
            .to = [_]u8{@as(u8, @intCast((i + 1) % 256))} ** 20,
            .amount = @as(u64, @intCast(i + 1)),
            .timestamp = @as(u64, @intCast(std.time.milliTimestamp())),
            .signature = [_]u8{0} ** 64,
            .hash = [_]u8{0} ** 32,
        };
        
        try chain.addTransaction(tx);
        
        // Mine block every 100 transactions
        if ((i + 1) % 100 == 0) {
            try chain.mineBlock();
        }
    }
    
    const end_time = std.time.milliTimestamp();
    const duration = end_time - start_time;
    
    std.log.info("Processed {} transactions in {}ms", .{ num_transactions, duration });
    std.log.info("Average: {d:.2}ms per transaction", .{ 
        @as(f64, @floatFromInt(duration)) / @as(f64, @floatFromInt(num_transactions)) 
    });
    
    // Performance should be reasonable (less than 10ms per transaction)
    try testing.expect(duration < num_transactions * 10);
}

// Memory tests
test "memory usage and leaks" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.log.err("Memory leak detected!");
        }
    }
    const allocator = gpa.allocator();
    
    // Test blockchain memory management
    {
        var chain = try blockchain.Blockchain.init(allocator);
        defer chain.deinit();
        
        // Add and remove many transactions
        for (0..100) |i| {
            const tx = blockchain.Transaction{
                .from = [_]u8{@as(u8, @intCast(i % 256))} ** 20,
                .to = [_]u8{@as(u8, @intCast((i + 1) % 256))} ** 20,
                .amount = @as(u64, @intCast(i + 1)),
                .timestamp = @as(u64, @intCast(std.time.milliTimestamp())),
                .signature = [_]u8{0} ** 64,
                .hash = [_]u8{0} ** 32,
            };
            
            try chain.addTransaction(tx);
        }
        
        try chain.mineBlock();
    }
    
    // Test wallet memory management
    {
        var test_wallet = try wallet.Wallet.init(allocator);
        defer test_wallet.deinit();
        
        // Create and destroy many accounts
        for (0..50) |_| {
            _ = try test_wallet.createAccount();
        }
    }
}

// Integration tests
test "full system integration" {
    const allocator = createTestAllocator();
    
    // Initialize components
    var chain = try blockchain.Blockchain.init(allocator);
    defer chain.deinit();
    
    var test_wallet = try wallet.Wallet.init(allocator);
    defer test_wallet.deinit();
    
    // Create test accounts
    const account1 = try test_wallet.createAccount();
    const account2 = try test_wallet.createAccount();
    
    // Simulate account funding (in real system, this would come from mining or transfers)
    try test_wallet.setBalance(account1.address, 1000);
    
    // Perform transfer
    const tx_hash = try test_wallet.transfer(account1.address, account2.address, 100);
    try testing.expect(tx_hash.len > 0);
    
    // Verify balances
    const balance1 = try test_wallet.getBalance(account1.address);
    const balance2 = try test_wallet.getBalance(account2.address);
    
    try testing.expect(balance1 == 900);
    try testing.expect(balance2 == 100);
    
    // Add transaction to blockchain
    const tx = try test_wallet.getTransaction(tx_hash);
    try chain.addTransaction(tx);
    try chain.mineBlock();
    
    // Verify blockchain state
    try testing.expect(chain.getHeight() == 2);
    try testing.expect(chain.isValid());
}

// Stress tests
test "concurrent operations stress test" {
    const allocator = createTestAllocator();
    
    var chain = try blockchain.Blockchain.init(allocator);
    defer chain.deinit();
    
    // Simulate concurrent transaction processing
    const num_threads = 4;
    const transactions_per_thread = 250;
    
    var threads: [num_threads]std.Thread = undefined;
    
    for (&threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{}, addTransactionsWorker, .{ &chain, i, transactions_per_thread });
    }
    
    for (threads) |thread| {
        thread.join();
    }
    
    // Verify final state
    try testing.expect(chain.isValid());
    std.log.info("Stress test completed. Final blockchain height: {}", .{chain.getHeight()});
}

fn addTransactionsWorker(chain: *blockchain.Blockchain, worker_id: usize, count: usize) void {
    for (0..count) |i| {
        const tx = blockchain.Transaction{
            .from = [_]u8{@as(u8, @intCast(worker_id))} ** 20,
            .to = [_]u8{@as(u8, @intCast((worker_id + 1) % 4))} ** 20,
            .amount = @as(u64, @intCast(i + 1)),
            .timestamp = @as(u64, @intCast(std.time.milliTimestamp())),
            .signature = [_]u8{0} ** 64,
            .hash = [_]u8{0} ** 32,
        };
        
        chain.addTransaction(tx) catch |err| {
            std.log.err("Worker {} failed to add transaction {}: {}", .{ worker_id, i, err });
        };
        
        // Occasionally mine blocks
        if (i % 50 == 0) {
            chain.mineBlock() catch |err| {
                std.log.err("Worker {} failed to mine block: {}", .{ worker_id, err });
            };
        }
    }
}

// Test runner
pub fn main() !void {
    std.log.info("🧪 Running Comprehensive Test Suite");
    std.log.info("===================================");
    
    const test_functions = [_]fn () anyerror!void{
        @import("std").testing.refAllDecls(@This()),
    };
    
    var passed: u32 = 0;
    var failed: u32 = 0;
    
    for (test_functions) |test_fn| {
        const test_name = @typeName(@TypeOf(test_fn));
        std.log.info("Running test: {s}", .{test_name});
        
        test_fn() catch |err| {
            std.log.err("❌ Test failed: {s} - {}", .{ test_name, err });
            failed += 1;
            continue;
        };
        
        std.log.info("✅ Test passed: {s}", .{test_name});
        passed += 1;
    }
    
    std.log.info("\n📊 Test Results:");
    std.log.info("  Passed: {}", .{passed});
    std.log.info("  Failed: {}", .{failed});
    std.log.info("  Total: {}", .{passed + failed});
    
    if (failed > 0) {
        std.process.exit(1);
    }
}
```

---

## Performance Optimization Examples

### 1. Memory Pool Implementation

```zig
// memory_pool_example.zig - Memory pool for performance optimization

const std = @import("std");

pub fn MemoryPool(comptime T: type) type {
    return struct {
        const Self = @This();
        
        const PoolNode = struct {
            data: T,
            next: ?*PoolNode,
        };
        
        allocator: std.mem.Allocator,
        free_list: ?*PoolNode,
        allocated_nodes: std.ArrayList(*PoolNode),
        pool_size: usize,
        
        pub fn init(allocator: std.mem.Allocator, initial_size: usize) !Self {
            var pool = Self{
                .allocator = allocator,
                .free_list = null,
                .allocated_nodes = std.ArrayList(*PoolNode).init(allocator),
                .pool_size = 0,
            };
            
            try pool.expand(initial_size);
            return pool;
        }
        
        pub fn deinit(self: *Self) void {
            for (self.allocated_nodes.items) |node| {
                self.allocator.destroy(node);
            }
            self.allocated_nodes.deinit();
        }
        
        pub fn acquire(self: *Self) !*T {
            if (self.free_list == null) {
                try self.expand(self.pool_size);
            }
            
            const node = self.free_list.?;
            self.free_list = node.next;
            
            return &node.data;
        }
        
        pub fn release(self: *Self, item: *T) void {
            const node = @fieldParentPtr(PoolNode, "data", item);
            node.next = self.free_list;
            self.free_list = node;
        }
        
        fn expand(self: *Self, count: usize) !void {
            for (0..count) |_| {
                const node = try self.allocator.create(PoolNode);
                try self.allocated_nodes.append(node);
                
                node.next = self.free_list;
                self.free_list = node;
                self.pool_size += 1;
            }
        }
        
        pub fn getStats(self: *Self) struct { total: usize, free: usize, used: usize } {
            var free_count: usize = 0;
            var current = self.free_list;
            while (current) |node| {
                free_count += 1;
                current = node.next;
            }
            
            return .{
                .total = self.pool_size,
                .free = free_count,
                .used = self.pool_size - free_count,
            };
        }
    };
}

// Example usage with transactions
const Transaction = struct {
    from: [20]u8,
    to: [20]u8,
    amount: u64,
    timestamp: u64,
    signature: [64]u8,
    hash: [32]u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.log.info("🚀 Memory Pool Performance Example");
    std.log.info("==================================");
    
    // Create memory pool for transactions
    var tx_pool = try MemoryPool(Transaction).init(allocator, 1000);
    defer tx_pool.deinit();
    
    const num_operations = 10000;
    
    // Benchmark with memory pool
    const start_time = std.time.nanoTimestamp();
    
    var transactions: [100]*Transaction = undefined;
    
    for (0..num_operations) |i| {
        // Acquire transactions
        for (&transactions) |*tx_ptr| {
            tx_ptr.* = try tx_pool.acquire();
            
            // Initialize transaction
            tx_ptr.*.from = [_]u8{@as(u8, @intCast(i % 256))} ** 20;
            tx_ptr.*.to = [_]u8{@as(u8, @intCast((i + 1) % 256))} ** 20;
            tx_ptr.*.amount = @as(u64, @intCast(i + 1));
            tx_ptr.*.timestamp = @as(u64, @intCast(std.time.milliTimestamp()));
        }
        
        // Use transactions (simulate processing)
        for (transactions) |tx| {
            _ = tx; // Simulate work
        }
        
        // Release transactions
        for (transactions) |tx| {
            tx_pool.release(tx);
        }
        
        // Print stats every 1000 operations
        if ((i + 1) % 1000 == 0) {
            const stats = tx_pool.getStats();
            std.log.info("Pool stats: {}/{} used/total", .{ stats.used, stats.total });
        }
    }
    
    const end_time = std.time.nanoTimestamp();
    const duration_ns = end_time - start_time;
    const duration_ms = @as(f64, @floatFromInt(duration_ns)) / 1_000_000.0;
    
    std.log.info("✅ Completed {} operations in {d:.2}ms", .{ num_operations, duration_ms });
    std.log.info("Average: {d:.4}ms per operation", .{ duration_ms / @as(f64, @floatFromInt(num_operations)) });
    
    const final_stats = tx_pool.getStats();
    std.log.info("Final pool stats: {}/{} used/total", .{ final_stats.used, final_stats.total });
}
```

---

This comprehensive collection of examples demonstrates various aspects of the Eastsea blockchain system, from basic usage to advanced features and optimizations. Each example is designed to be educational and practical, showing real-world usage patterns and best practices.

With the addition of QUIC support, Eastsea now provides both TCP and QUIC networking options, giving developers flexibility in choosing the most appropriate protocol for their use case. The QUIC implementation provides enhanced performance, security, and connection management features that complement the existing TCP-based networking stack.