const std = @import("std");
const crypto = @import("../crypto/hash.zig");
const p2p = @import("p2p.zig");
const dht = @import("dht.zig");
const quic = @import("quic.zig");
const base58 = @import("../encoding/base58.zig");
const blockchain = @import("../blockchain/blockchain.zig");

pub const NodeId = [32]u8;

pub const PeerInfo = struct {
    id: NodeId,
    address: []const u8,
    port: u16,
    last_seen: i64,

    pub fn init(address: []const u8, port: u16) PeerInfo {
        var id: NodeId = undefined;
        std.crypto.random.bytes(&id);
        
        return PeerInfo{
            .id = id,
            .address = address,
            .port = port,
            .last_seen = std.time.timestamp(),
        };
    }
};

pub const MessageType = enum(u8) {
    ping = 0,
    pong = 1,
    block = 2,
    transaction = 3,
    peer_list = 4,
    handshake = 5,
};

pub const Message = struct {
    type: MessageType,
    payload: []const u8,
    timestamp: i64,

    pub fn init(msg_type: MessageType, payload: []const u8) Message {
        return Message{
            .type = msg_type,
            .payload = payload,
            .timestamp = std.time.timestamp(),
        };
    }
};

pub const Node = struct {
    id: NodeId,
    address: []const u8,
    port: u16,
    peers: std.array_list.Managed(PeerInfo),
    allocator: std.mem.Allocator,
    is_running: bool,
    p2p_node: ?*p2p.P2PNode,
    quic_node: ?*quic.QuicNode, // Add QUIC node support
    dht: ?*dht.DHT,
    blockchain: ?*blockchain.Blockchain, // 블록체인 참조 추가

    pub fn init(allocator: std.mem.Allocator, address: []const u8, port: u16) Node {
        var id: NodeId = undefined;
        std.crypto.random.bytes(&id);

        return Node{
            .id = id,
            .address = address,
            .port = port,
            .peers = std.array_list.Managed(PeerInfo).init(allocator),
            .allocator = allocator,
            .is_running = false,
            .p2p_node = null,
            .quic_node = null, // Initialize QUIC node as null
            .dht = null,
            .blockchain = null, // 초기에는 null
        };
    }

    pub fn deinit(self: *Node) void {
        if (self.dht) |dht_instance| {
            dht_instance.deinit();
            self.allocator.destroy(dht_instance);
        }
        if (self.quic_node) |quic_node| {
            quic_node.deinit();
            self.allocator.destroy(quic_node);
        }
        if (self.p2p_node) |p2p_node| {
            p2p_node.deinit();
            self.allocator.destroy(p2p_node);
        }
        self.peers.deinit();
    }

    pub fn setBlockchain(self: *Node, blockchain_ref: *blockchain.Blockchain) void {
        self.blockchain = blockchain_ref;
    }

    pub fn start(self: *Node) !void {
        // Initialize P2P node
        const p2p_node = try self.allocator.create(p2p.P2PNode);
        p2p_node.* = try p2p.P2PNode.init(self.allocator, self.port);
        self.p2p_node = p2p_node;
        
        // Initialize QUIC node
        const quic_node = try self.allocator.create(quic.QuicNode);
        quic_node.* = try quic.QuicNode.init(self.allocator, self.port + 1000); // Use different port for QUIC
        self.quic_node = quic_node;
        
        // Initialize DHT
        const dht_instance = try self.allocator.create(dht.DHT);
        dht_instance.* = try dht.DHT.init(self.allocator, self.address, self.port);
        self.dht = dht_instance;
        
        // Attach DHT to P2P node
        try dht_instance.attachP2PNode(p2p_node);
        
        // P2P 노드에 블록체인 참조 설정
        if (self.blockchain) |blockchain_ref| {
            p2p_node.setBlockchain(blockchain_ref);
            std.debug.print("🔗 Blockchain reference set for P2P node\n", .{});
        }
        
        try p2p_node.start();
        try quic_node.start(); // Start QUIC node
        
        self.is_running = true;
        std.debug.print("🌐 Node started on {s}:{}\n", .{ self.address, self.port });
        std.debug.print("🆔 Node ID: {s}\n", .{std.fmt.bytesToHex(&self.id, .lower)});
        std.debug.print("🔗 DHT initialized\n", .{});
        std.debug.print("퀵 QUIC node initialized on port {}\n", .{self.port + 1000});
    }

    pub fn getNodeId(self: *const Node, allocator: std.mem.Allocator) ![]u8 {
        return base58.encode(allocator, self.id[0..]);
    }

    pub fn stop(self: *Node) void {
        if (self.p2p_node) |p2p_node| {
            p2p_node.stop();
        }
        if (self.quic_node) |quic_node| {
            quic_node.stop();
        }
        self.is_running = false;
        std.debug.print("🛑 Node stopped\n", .{});
    }

    pub fn connectToPeer(self: *Node, peer_address: []const u8, peer_port: u16) !void {
        if (self.p2p_node == null) return error.NodeNotStarted;
        
        const address = try std.net.Address.parseIp4(peer_address, peer_port);
        
        // Validate peer before attempting connection
        if (self.isPeerValid(peer_address, peer_port)) {
            _ = self.p2p_node.?.connectToPeer(address) catch |err| {
                std.debug.print("⚠️  Failed to connect to peer {s}:{}: {}\n", .{ peer_address, peer_port, err });
                return; // Don't fail, just continue
            };
            
            // Add to legacy peer list for compatibility only if connection succeeded
            const peer = PeerInfo.init(peer_address, peer_port);
            try self.addPeer(peer);
        } else {
            std.debug.print("⚠️  Skipping invalid peer {s}:{}\n", .{ peer_address, peer_port });
        }
    }
    
    fn isPeerValid(self: *Node, peer_address: []const u8, peer_port: u16) bool {
        // Don't connect to self
        if (std.mem.eql(u8, peer_address, self.address) and peer_port == self.port) {
            return false;
        }
        
        // Check if already connected
        for (self.peers.items) |peer| {
            if (std.mem.eql(u8, peer.address, peer_address) and peer.port == peer_port) {
                return false; // Already connected
            }
        }
        
        return true;
    }

    pub fn startAcceptingConnections(self: *Node) !void {
        if (self.p2p_node == null) return error.NodeNotStarted;
        
        // This should be run in a separate thread in a real implementation
        try self.p2p_node.?.acceptConnections();
    }

    pub fn broadcastBlock(self: *Node, block_data: []const u8) !void {
        if (self.p2p_node == null) return error.NodeNotStarted;
        
        var block_msg = try p2p.P2PMessage.init(self.allocator, 2, block_data);
        defer block_msg.deinit();
        
        try self.p2p_node.?.broadcastMessage(&block_msg);
    }

    pub fn broadcastTransaction(self: *Node, tx_data: []const u8) !void {
        if (self.p2p_node == null) return error.NodeNotStarted;
        
        var tx_msg = try p2p.P2PMessage.init(self.allocator, 3, tx_data);
        defer tx_msg.deinit();
        
        try self.p2p_node.?.broadcastMessage(&tx_msg);
    }

    pub fn pingPeers(self: *Node) !void {
        if (self.p2p_node == null) return error.NodeNotStarted;
        
        try self.p2p_node.?.pingAllPeers();
    }

    pub fn addPeer(self: *Node, peer: PeerInfo) !void {
        // Check if peer already exists
        for (self.peers.items) |existing_peer| {
            if (std.mem.eql(u8, &existing_peer.id, &peer.id)) {
                return; // Peer already exists
            }
        }
        
        try self.peers.append(peer);
        std.debug.print("👥 Added peer: {s}:{}\n", .{ peer.address, peer.port });
    }

    pub fn removePeer(self: *Node, peer_id: NodeId) void {
        for (self.peers.items, 0..) |peer, i| {
            if (std.mem.eql(u8, &peer.id, &peer_id)) {
                _ = self.peers.swapRemove(i);
                std.debug.print("❌ Removed peer: {s}\n", .{std.fmt.bytesToHex(&peer_id, .lower)});
                break;
            }
        }
    }

    pub fn broadcastMessage(self: *Node, message: Message) !void {
        std.debug.print("📡 Broadcasting message type: {} to {} peers\n", .{ message.type, self.peers.items.len });
        
        // Use new P2P broadcasting if available
        if (self.p2p_node) |p2p_node| {
            const msg_type: u8 = switch (message.type) {
                .ping => 0,
                .pong => 1,
                .block => 2,
                .transaction => 3,
                .peer_list => 4,
                .handshake => 5,
            };
            
            var p2p_msg = try p2p.P2PMessage.init(self.allocator, msg_type, message.payload);
            defer p2p_msg.deinit();
            
            try p2p_node.broadcastMessage(&p2p_msg);
        } else {
            // Fallback to legacy method
            for (self.peers.items) |peer| {
                try self.sendMessage(peer, message);
            }
        }
    }

    pub fn sendMessage(self: *Node, peer: PeerInfo, message: Message) !void {
        _ = self; // Suppress unused parameter warning
        // In a real implementation, this would send over network
        std.debug.print("📤 Sending {} message to {s}:{}\n", .{ message.type, peer.address, peer.port });
        
        // Simulate network delay
        std.Thread.sleep(1000000); // 1ms
    }

    pub fn handleMessage(self: *Node, from_peer: PeerInfo, message: Message) !void {
        std.debug.print("📥 Received {} message from {s}:{}\n", .{ message.type, from_peer.address, from_peer.port });
        
        switch (message.type) {
            .ping => {
                const pong = Message.init(.pong, "pong");
                try self.sendMessage(from_peer, pong);
            },
            .pong => {
                std.debug.print("🏓 Pong received from peer\n", .{});
            },
            .block => {
                std.debug.print("📦 New block received\n", .{});
                
                // 받은 블록을 블록체인에 추가
                if (self.blockchain) |blockchain_ref| {
                    std.debug.print("🔗 Processing received block...\n", .{});
                    std.debug.print("📊 Current blockchain height: {}\n", .{blockchain_ref.getHeight()});
                    
                    // 블록 데이터 파싱 및 검증 (P2P 메시지와 유사한 형태)
                    const block_data = std.mem.trim(u8, message.payload, " \t\n\r");
                    
                    if (std.mem.startsWith(u8, block_data, "BLOCK:")) {
                        std.debug.print("🔍 Validating block format...\n", .{});
                        
                        // 블록체인 무결성 확인
                        if (!blockchain_ref.isChainValid()) {
                            std.debug.print("❌ Current blockchain is invalid\n", .{});
                            return;
                        }
                        
                        // 실제 구현에서는 블록을 완전히 파싱하고 검증해야 함
                        // 여기서는 시뮬레이션을 위해 간단한 처리만 수행
                        std.debug.print("✅ Block format validation passed\n", .{});
                        std.debug.print("📋 Current pending transactions: {}\n", .{blockchain_ref.pending_transactions.items.len});
                        
                        // 블록에 포함된 트랜잭션들을 pending pool에 추가 (실제로는 반대 과정)
                        // 실제로는 받은 블록의 트랜잭션들이 pending pool에서 제거되어야 함
                        
                    } else {
                        std.debug.print("❌ Invalid block format\n", .{});
                    }
                    
                    std.debug.print("✅ Block processed successfully\n", .{});
                } else {
                    std.debug.print("❌ No blockchain instance available\n", .{});
                }
            },
            .transaction => {
                std.debug.print("💸 New transaction received\n", .{});
                
                // 받은 트랜잭션을 처리
                if (self.blockchain) |blockchain_ref| {
                    std.debug.print("🔍 Processing received transaction...\n", .{});
                    
                    // 트랜잭션 데이터 파싱 및 검증 (P2P 메시지와 유사한 형태)
                    const tx_data = std.mem.trim(u8, message.payload, " \t\n\r");
                    
                    if (std.mem.startsWith(u8, tx_data, "TX:")) {
                        std.debug.print("🔍 Validating transaction format...\n", .{});
                        
                        // 간단한 트랜잭션 파싱 (실제로는 더 복잡한 구조)
                        // 예시: "TX:from=alice,to=bob,amount=50,timestamp=1234567890"
                        var parts = std.mem.splitScalar(u8, tx_data[3..], ',');
                        var from: ?[]const u8 = null;
                        var to: ?[]const u8 = null;
                        var amount: ?u64 = null;
                        var timestamp: ?i64 = null;
                        
                        while (parts.next()) |part| {
                            if (std.mem.startsWith(u8, part, "from=")) {
                                from = part[5..];
                            } else if (std.mem.startsWith(u8, part, "to=")) {
                                to = part[3..];
                            } else if (std.mem.startsWith(u8, part, "amount=")) {
                                amount = std.fmt.parseUnsigned(u64, part[7..], 10) catch null;
                            } else if (std.mem.startsWith(u8, part, "timestamp=")) {
                                timestamp = std.fmt.parseInt(i64, part[10..], 10) catch null;
                            }
                        }
                        
                        // 기본 검증
                        if (from != null and to != null and amount != null and timestamp != null) {
                            const validated_tx = blockchain.Transaction{
                                .from = from.?,
                                .to = to.?,
                                .amount = amount.?,
                                .timestamp = timestamp.?,
                            };
                            
                            // 트랜잭션을 pending pool에 추가
                            blockchain_ref.addTransaction(validated_tx) catch |err| {
                                std.debug.print("❌ Failed to add transaction: {}\n", .{err});
                                return;
                            };
                            
                            std.debug.print("✅ Transaction validated and added to pending pool\n", .{});
                            std.debug.print("📊 Transaction: {s} -> {s}, amount: {}\n", .{ from.?, to.?, amount.? });
                            std.debug.print("📋 Pending transactions: {}\n", .{blockchain_ref.pending_transactions.items.len});
                            
                        } else {
                            std.debug.print("❌ Invalid transaction: missing required fields\n", .{});
                        }
                        
                    } else {
                        // 레거시 처리 (기존 방식과 호환성 유지)
                        const legacy_tx = blockchain.Transaction{
                            .from = "legacy_peer",
                            .to = "local_node",
                            .amount = 25,
                            .timestamp = std.time.timestamp(),
                        };
                        
                        blockchain_ref.addTransaction(legacy_tx) catch |err| {
                            std.debug.print("❌ Failed to add legacy transaction: {}\n", .{err});
                            return;
                        };
                        
                        std.debug.print("✅ Legacy transaction processed\n", .{});
                        std.debug.print("📋 Pending transactions: {}\n", .{blockchain_ref.pending_transactions.items.len});
                    }
                    
                } else {
                    std.debug.print("❌ No blockchain instance available\n", .{});
                }
            },
            .peer_list => {
                std.debug.print("👥 Peer list received\n", .{});
                
                // 받은 피어 목록을 처리
                // TODO: message.data에서 피어 목록을 파싱
                
                std.debug.print("🔍 Processing peer list update...\n", .{});
                
                // 피어 목록 갱신 로직
                // 실제로는 JSON이나 바이너리 형태로 피어 정보를 파싱해야 함
                if (self.p2p_node) |p2p_instance| {
                    std.debug.print("📊 Current peer count: {}\n", .{p2p_instance.getPeerCount()});
                    std.debug.print("✅ Peer list processed\n", .{});
                } else {
                    std.debug.print("❌ No P2P node available\n", .{});
                }
            },
            .handshake => {
                std.debug.print("🤝 Handshake received\n", .{});
                
                // 핸드셰이크 완료 처리
                std.debug.print("🔗 Processing handshake...\n", .{});
                
                // 핸드셰이크 응답 전송
                const handshake_response = Message.init(.handshake, "HANDSHAKE_RESPONSE");
                self.sendMessage(from_peer, handshake_response) catch |err| {
                    std.debug.print("❌ Failed to send handshake response: {}\n", .{err});
                    return;
                };
                
                std.debug.print("✅ Handshake completed with peer\n", .{});
                
                // 핸드셰이크가 완료되면 피어를 활성 상태로 설정
                if (self.p2p_node) |p2p_instance| {
                    std.debug.print("📊 Active peers: {}\n", .{p2p_instance.getPeerCount()});
                }
            },
        }
    }

    pub fn discoverPeers(self: *Node) !void {
        std.debug.print("🔍 Discovering peers using DHT...\n", .{});
        
        if (self.dht) |dht_instance| {
            // Bootstrap with some known nodes (in real implementation, these would be from config)
            var bootstrap_nodes = std.array_list.Managed(dht.DHTNode).init(self.allocator);
            defer bootstrap_nodes.deinit();
            
            // Add some bootstrap nodes (these would be well-known nodes in the network)
            const bootstrap_addresses = [_]struct { address: []const u8, port: u16 }{
                .{ .address = "127.0.0.1", .port = 8001 },
                .{ .address = "127.0.0.1", .port = 8002 },
                .{ .address = "127.0.0.1", .port = 8003 },
            };
            
            for (bootstrap_addresses) |addr| {
                if (addr.port != self.port) { // Don't add ourselves
                    const bootstrap_node = try dht.DHTNode.init(self.allocator, addr.address, addr.port);
                    try bootstrap_nodes.append(bootstrap_node);
                }
            }
            
            // Bootstrap the DHT
            if (bootstrap_nodes.items.len > 0) {
                try dht_instance.bootstrap(bootstrap_nodes.items);
                
                // Find nodes close to our ID to populate routing table
                const close_nodes = try dht_instance.findNode(dht_instance.local_node.id);
                defer {
                    // Clean up close_nodes
                    for (close_nodes.items) |*close_node| {
                        close_node.deinit(self.allocator);
                    }
                    close_nodes.deinit();
                }
                
                // Try to connect to discovered nodes
                for (close_nodes.items) |discovered_node| {
                    self.connectToPeer(discovered_node.address, discovered_node.port) catch |err| {
                        std.debug.print("⚠️  Could not connect to discovered peer {s}:{}: {}\n", .{ discovered_node.address, discovered_node.port, err });
                    };
                }
                
                // Show DHT status
                dht_instance.getNodeInfo();
            } else {
                std.debug.print("⚠️  No bootstrap nodes available for DHT\n", .{});
            }
            
            // Clean up bootstrap nodes (these are the original ones, not the ones in DHT)
            for (bootstrap_nodes.items) |*bootstrap_node| {
                bootstrap_node.deinit(self.allocator);
            }
        } else {
            // Fallback to legacy peer discovery
            std.debug.print("🔍 Using legacy peer discovery...\n", .{});
            
            // In a real implementation, this would:
            // 1. Query known seed nodes
            // 2. Use mDNS for local discovery
            // 3. Connect to bootstrap nodes
            
            // For demo, add some mock peers
            const mock_peers = [_]PeerInfo{
                PeerInfo.init("127.0.0.1", 8001),
                PeerInfo.init("127.0.0.1", 8002),
                PeerInfo.init("127.0.0.1", 8003),
            };
            
            for (mock_peers) |peer| {
                try self.addPeer(peer);
            }
            
            // Try to connect to some peers using P2P
            if (self.p2p_node != null) {
                self.connectToPeer("127.0.0.1", 8001) catch |err| {
                    std.debug.print("⚠️  Could not connect to peer 8001: {}\n", .{err});
                };
                self.connectToPeer("127.0.0.1", 8002) catch |err| {
                    std.debug.print("⚠️  Could not connect to peer 8002: {}\n", .{err});
                };
            }
        }
    }

    pub fn getPeerCount(self: *const Node) usize {
        if (self.p2p_node) |p2p_node| {
            return p2p_node.getPeerCount();
        }
        return self.peers.items.len;
    }

    pub fn isConnected(self: *const Node) bool {
        return self.is_running and self.getPeerCount() > 0;
    }
};

test "node creation" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var node = Node.init(allocator, "127.0.0.1", 8000);
    defer node.deinit();

    try testing.expect(node.port == 8000);
    try testing.expect(!node.is_running);
    try testing.expect(node.getPeerCount() == 0);
}

test "peer management" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var node = Node.init(allocator, "127.0.0.1", 8000);
    defer node.deinit();

    const peer = PeerInfo.init("127.0.0.1", 8001);
    try node.addPeer(peer);

    try testing.expect(node.getPeerCount() == 1);

    node.removePeer(peer.id);
    try testing.expect(node.getPeerCount() == 0);
}
