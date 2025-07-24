const std = @import("std");
const crypto = @import("../crypto/hash.zig");
const p2p = @import("p2p.zig");
const dht = @import("dht.zig");

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
    peers: std.ArrayList(PeerInfo),
    allocator: std.mem.Allocator,
    is_running: bool,
    p2p_node: ?*p2p.P2PNode,
    dht: ?*dht.DHT,

    pub fn init(allocator: std.mem.Allocator, address: []const u8, port: u16) Node {
        var id: NodeId = undefined;
        std.crypto.random.bytes(&id);

        return Node{
            .id = id,
            .address = address,
            .port = port,
            .peers = std.ArrayList(PeerInfo).init(allocator),
            .allocator = allocator,
            .is_running = false,
            .p2p_node = null,
            .dht = null,
        };
    }

    pub fn deinit(self: *Node) void {
        if (self.dht) |dht_instance| {
            dht_instance.deinit();
            self.allocator.destroy(dht_instance);
        }
        if (self.p2p_node) |p2p_node| {
            p2p_node.deinit();
            self.allocator.destroy(p2p_node);
        }
        self.peers.deinit();
    }

    pub fn start(self: *Node) !void {
        // Initialize P2P node
        const p2p_node = try self.allocator.create(p2p.P2PNode);
        p2p_node.* = try p2p.P2PNode.init(self.allocator, self.port);
        self.p2p_node = p2p_node;
        
        // Initialize DHT
        const dht_instance = try self.allocator.create(dht.DHT);
        dht_instance.* = try dht.DHT.init(self.allocator, self.address, self.port);
        self.dht = dht_instance;
        
        // Attach DHT to P2P node
        try dht_instance.attachP2PNode(p2p_node);
        
        try p2p_node.start();
        
        self.is_running = true;
        std.debug.print("🌐 Node started on {s}:{}\n", .{ self.address, self.port });
        std.debug.print("🆔 Node ID: {}\n", .{std.fmt.fmtSliceHexLower(&self.id)});
        std.debug.print("🔗 DHT initialized\n", .{});
    }

    pub fn stop(self: *Node) void {
        if (self.p2p_node) |p2p_node| {
            p2p_node.stop();
        }
        self.is_running = false;
        std.debug.print("🛑 Node stopped\n", .{});
    }

    pub fn connectToPeer(self: *Node, peer_address: []const u8, peer_port: u16) !void {
        if (self.p2p_node == null) return error.NodeNotStarted;
        
        const address = try std.net.Address.parseIp4(peer_address, peer_port);
        _ = try self.p2p_node.?.connectToPeer(address);
        
        // Add to legacy peer list for compatibility
        const peer = PeerInfo.init(peer_address, peer_port);
        try self.addPeer(peer);
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
                std.debug.print("❌ Removed peer: {}\n", .{std.fmt.fmtSliceHexLower(&peer_id)});
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
        std.time.sleep(1000000); // 1ms
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
                // TODO: Validate and add block to blockchain
            },
            .transaction => {
                std.debug.print("💸 New transaction received\n", .{});
                // TODO: Validate and add to transaction pool
            },
            .peer_list => {
                std.debug.print("👥 Peer list received\n", .{});
                // TODO: Update peer list
            },
            .handshake => {
                std.debug.print("🤝 Handshake received\n", .{});
                // TODO: Complete handshake process
            },
        }
    }

    pub fn discoverPeers(self: *Node) !void {
        std.debug.print("🔍 Discovering peers using DHT...\n", .{});
        
        if (self.dht) |dht_instance| {
            // Bootstrap with some known nodes (in real implementation, these would be from config)
            var bootstrap_nodes = std.ArrayList(dht.DHTNode).init(self.allocator);
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