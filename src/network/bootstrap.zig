const std = @import("std");
const net = std.net;
const crypto = @import("../crypto/hash.zig");
const p2p = @import("p2p.zig");
const dht = @import("dht.zig");

pub const BootstrapError = error{
    InvalidBootstrapNode,
    ConnectionFailed,
    NoBootstrapNodes,
    NetworkError,
    SerializationError,
};

// Bootstrap node configuration
pub const BootstrapNodeConfig = struct {
    address: []const u8,
    port: u16,
    node_id: ?dht.NodeId = null, // Optional, will be determined during connection
    is_trusted: bool = true,
    last_seen: i64 = 0,

    pub fn init(allocator: std.mem.Allocator, address: []const u8, port: u16) !BootstrapNodeConfig {
    const duped_address = try allocator.dupe(u8, address);
    errdefer allocator.free(duped_address);
    
    return BootstrapNodeConfig{
        .address = duped_address,
        .port = port,
        .last_seen = std.time.timestamp(),
    };
}

    pub fn deinit(self: *BootstrapNodeConfig, allocator: std.mem.Allocator) void {
        allocator.free(self.address);
    }

    pub fn toDHTNode(self: *const BootstrapNodeConfig, allocator: std.mem.Allocator) !dht.DHTNode {
        var dht_node = try dht.DHTNode.init(allocator, self.address, self.port);
        errdefer dht_node.deinit(allocator);
        return dht_node;
    }

    pub fn toNetAddress(self: *const BootstrapNodeConfig) !net.Address {
        return try net.Address.parseIp4(self.address, self.port);
    }
};

// Bootstrap message types
pub const BootstrapMessageType = enum(u8) {
    bootstrap_request = 20,
    bootstrap_response = 21,
    peer_list_request = 22,
    peer_list_response = 23,
    node_announcement = 24,
};

pub const BootstrapMessage = struct {
    type: BootstrapMessageType,
    request_id: [16]u8,
    sender_address: []const u8,
    sender_port: u16,
    payload: []const u8,

    pub fn init(allocator: std.mem.Allocator, msg_type: BootstrapMessageType, sender_address: []const u8, sender_port: u16, payload: []const u8) !BootstrapMessage {
        var request_id: [16]u8 = undefined;
        std.crypto.random.bytes(&request_id);

        return BootstrapMessage{
            .type = msg_type,
            .request_id = request_id,
            .sender_address = try allocator.dupe(u8, sender_address),
            .sender_port = sender_port,
            .payload = try allocator.dupe(u8, payload),
        };
    }

    pub fn deinit(self: *BootstrapMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.sender_address);
        allocator.free(self.payload);
    }

    pub fn serialize(self: *const BootstrapMessage, allocator: std.mem.Allocator) ![]u8 {
        const addr_len = self.sender_address.len;
        const payload_len = self.payload.len;
        const total_size = 1 + 16 + 2 + addr_len + 2 + 4 + payload_len; // type + request_id + addr_len + address + port + payload_len + payload

        var buffer = try allocator.alloc(u8, total_size);
        var offset: usize = 0;

        // Message type
        buffer[offset] = @intFromEnum(self.type);
        offset += 1;

        // Request ID
        @memcpy(buffer[offset..offset + 16], &self.request_id);
        offset += 16;

        // Sender address length
        std.mem.writeInt(u16, buffer[offset..][0..2], @intCast(addr_len), .little);
        offset += 2;

        // Sender address
        @memcpy(buffer[offset..offset + addr_len], self.sender_address);
        offset += addr_len;

        // Sender port
        std.mem.writeInt(u16, buffer[offset..][0..2], self.sender_port, .little);
        offset += 2;

        // Payload length
        std.mem.writeInt(u32, buffer[offset..][0..4], @intCast(payload_len), .little);
        offset += 4;

        // Payload
        @memcpy(buffer[offset..offset + payload_len], self.payload);

        return buffer;
    }

    pub fn deserialize(allocator: std.mem.Allocator, buffer: []const u8) !BootstrapMessage {
        if (buffer.len < 25) return BootstrapError.SerializationError; // Minimum size

        var offset: usize = 0;

        // Message type
        const msg_type = @as(BootstrapMessageType, @enumFromInt(buffer[offset]));
        offset += 1;

        // Request ID
        var request_id: [16]u8 = undefined;
        @memcpy(&request_id, buffer[offset..offset + 16]);
        offset += 16;

        // Sender address length
        const addr_len = std.mem.readInt(u16, buffer[offset..][0..2], .little);
        offset += 2;

        if (buffer.len < offset + addr_len + 6) return BootstrapError.SerializationError;

        // Sender address
        const sender_address = try allocator.dupe(u8, buffer[offset..offset + addr_len]);
        offset += addr_len;

        // Sender port
        const sender_port = std.mem.readInt(u16, buffer[offset..][0..2], .little);
        offset += 2;

        // Payload length
        const payload_len = std.mem.readInt(u32, buffer[offset..][0..4], .little);
        offset += 4;

        if (buffer.len < offset + payload_len) return BootstrapError.SerializationError;

        // Payload
        const payload = try allocator.dupe(u8, buffer[offset..offset + payload_len]);

        return BootstrapMessage{
            .type = msg_type,
            .request_id = request_id,
            .sender_address = sender_address,
            .sender_port = sender_port,
            .payload = payload,
        };
    }
};

// Bootstrap client for connecting to bootstrap nodes
pub const BootstrapClient = struct {
    allocator: std.mem.Allocator,
    bootstrap_nodes: std.ArrayList(BootstrapNodeConfig),
    p2p_node: ?*p2p.P2PNode,
    dht_node: ?*dht.DHT,
    local_address: []const u8,
    local_port: u16,

    pub fn init(allocator: std.mem.Allocator, local_address: []const u8, local_port: u16) !BootstrapClient {
        return BootstrapClient{
            .allocator = allocator,
            .bootstrap_nodes = std.ArrayList(BootstrapNodeConfig).init(allocator),
            .p2p_node = null,
            .dht_node = null,
            .local_address = try allocator.dupe(u8, local_address),
            .local_port = local_port,
        };
    }

    pub fn deinit(self: *BootstrapClient) void {
        for (self.bootstrap_nodes.items) |*node| {
            node.deinit(self.allocator);
        }
        self.bootstrap_nodes.deinit();
        if (self.local_address.len > 0) {
            self.allocator.free(self.local_address);
        }
    }

    pub fn attachP2PNode(self: *BootstrapClient, p2p_node: *p2p.P2PNode) !void {
        self.p2p_node = p2p_node;

        // Register bootstrap message handlers
        try p2p_node.registerMessageHandler(@intFromEnum(BootstrapMessageType.bootstrap_request), handleBootstrapRequest);
        try p2p_node.registerMessageHandler(@intFromEnum(BootstrapMessageType.bootstrap_response), handleBootstrapResponse);
        try p2p_node.registerMessageHandler(@intFromEnum(BootstrapMessageType.peer_list_request), handlePeerListRequest);
        try p2p_node.registerMessageHandler(@intFromEnum(BootstrapMessageType.peer_list_response), handlePeerListResponse);
        try p2p_node.registerMessageHandler(@intFromEnum(BootstrapMessageType.node_announcement), handleNodeAnnouncement);
    }

    pub fn attachDHTNode(self: *BootstrapClient, dht_node: *dht.DHT) void {
        self.dht_node = dht_node;
    }

    pub fn addBootstrapNode(self: *BootstrapClient, address: []const u8, port: u16) !void {
        const node_config = try BootstrapNodeConfig.init(self.allocator, address, port);
        try self.bootstrap_nodes.append(node_config);
        std.debug.print("➕ Added bootstrap node: {s}:{}\n", .{ address, port });
    }

    pub fn addDefaultBootstrapNodes(self: *BootstrapClient) !void {
        // Add some default bootstrap nodes (these would be well-known nodes in a real network)
        try self.addBootstrapNode("127.0.0.1", 8000);
        try self.addBootstrapNode("127.0.0.1", 8001);
        try self.addBootstrapNode("127.0.0.1", 8002);
        
        std.debug.print("✅ Added {} default bootstrap nodes\n", .{self.bootstrap_nodes.items.len});
    }

    pub fn bootstrap(self: *BootstrapClient) !void {
        if (self.bootstrap_nodes.items.len == 0) {
            return BootstrapError.NoBootstrapNodes;
        }

        std.debug.print("🚀 Starting bootstrap process with {} nodes\n", .{self.bootstrap_nodes.items.len});

        var successful_connections: usize = 0;

        for (self.bootstrap_nodes.items) |*bootstrap_node| {
            // Skip if this is our own node
            if (std.mem.eql(u8, bootstrap_node.address, self.local_address) and bootstrap_node.port == self.local_port) {
                continue;
            }
            
            self.connectToBootstrapNode(bootstrap_node) catch |err| {
                std.debug.print("❌ Failed to connect to bootstrap node {s}:{}: {}\n", .{ bootstrap_node.address, bootstrap_node.port, err });
                continue;
            };
            
            successful_connections += 1;
            std.debug.print("✅ Successfully connected to bootstrap node: {s}:{}\n", .{ bootstrap_node.address, bootstrap_node.port });
            
            // Request peer list from this bootstrap node
            self.requestPeerList(bootstrap_node) catch |err| {
                std.debug.print("⚠️  Failed to request peer list: {}\n", .{err});
            };
        }

        if (successful_connections == 0) {
            return BootstrapError.ConnectionFailed;
        }

        std.debug.print("🎉 Bootstrap complete! Connected to {} nodes\n", .{successful_connections});
    }

    fn connectToBootstrapNode(self: *BootstrapClient, bootstrap_node: *BootstrapNodeConfig) !void {
    if (self.p2p_node == null) return BootstrapError.NetworkError;

    // Skip if this is our own node
    if (std.mem.eql(u8, bootstrap_node.address, self.local_address) and bootstrap_node.port == self.local_port) {
        return;
    }

    const peer_address = try bootstrap_node.toNetAddress();
    
    // Try to connect via P2P
    _ = try self.p2p_node.?.connectToPeer(peer_address);

    // Send bootstrap request
    try self.sendBootstrapRequest(bootstrap_node);

    // If DHT is available, add to DHT routing table
    if (self.dht_node) |dht_node| {
        var dht_node_entry = try dht.DHTNode.init(self.allocator, bootstrap_node.address, bootstrap_node.port);
        errdefer dht_node_entry.deinit(self.allocator); // Clean up if anything fails after this point
        
        const added = try dht_node.routing_table.addNode(dht_node_entry);
        // If the node wasn't added (e.g., bucket full), we need to clean it up
        if (!added) {
            dht_node_entry.deinit(self.allocator);
        }
    }

    bootstrap_node.last_seen = std.time.timestamp();
}

    fn sendBootstrapRequest(self: *BootstrapClient, bootstrap_node: *const BootstrapNodeConfig) !void {
        if (self.p2p_node == null) return BootstrapError.NetworkError;

        const request_payload = try std.fmt.allocPrint(self.allocator, "BOOTSTRAP_REQUEST", .{});
        defer self.allocator.free(request_payload);

        var bootstrap_msg = try BootstrapMessage.init(
            self.allocator,
            .bootstrap_request,
            self.local_address,
            self.local_port,
            request_payload
        );
        defer bootstrap_msg.deinit(self.allocator);

        const serialized = try bootstrap_msg.serialize(self.allocator);
        defer self.allocator.free(serialized);

        var p2p_msg = try p2p.P2PMessage.init(self.allocator, @intFromEnum(BootstrapMessageType.bootstrap_request), serialized);
        defer p2p_msg.deinit();

        try self.p2p_node.?.broadcastMessage(&p2p_msg);
        std.debug.print("📤 Sent bootstrap request to {s}:{}\n", .{ bootstrap_node.address, bootstrap_node.port });
    }

    fn requestPeerList(self: *BootstrapClient, bootstrap_node: *const BootstrapNodeConfig) !void {
        if (self.p2p_node == null) return BootstrapError.NetworkError;

        const request_payload = try std.fmt.allocPrint(self.allocator, "PEER_LIST_REQUEST", .{});
        defer self.allocator.free(request_payload);

        var peer_list_msg = try BootstrapMessage.init(
            self.allocator,
            .peer_list_request,
            self.local_address,
            self.local_port,
            request_payload
        );
        defer peer_list_msg.deinit(self.allocator);

        const serialized = try peer_list_msg.serialize(self.allocator);
        defer self.allocator.free(serialized);

        var p2p_msg = try p2p.P2PMessage.init(self.allocator, @intFromEnum(BootstrapMessageType.peer_list_request), serialized);
        defer p2p_msg.deinit();

        try self.p2p_node.?.broadcastMessage(&p2p_msg);
        std.debug.print("📤 Requested peer list from {s}:{}\n", .{ bootstrap_node.address, bootstrap_node.port });
    }

    pub fn announceNode(self: *BootstrapClient) !void {
        if (self.p2p_node == null) return BootstrapError.NetworkError;

        const announcement_payload = try std.fmt.allocPrint(
            self.allocator,
            "NODE_ANNOUNCEMENT:{s}:{}",
            .{ self.local_address, self.local_port }
        );
        defer self.allocator.free(announcement_payload);

        var announcement_msg = try BootstrapMessage.init(
            self.allocator,
            .node_announcement,
            self.local_address,
            self.local_port,
            announcement_payload
        );
        defer announcement_msg.deinit(self.allocator);

        const serialized = try announcement_msg.serialize(self.allocator);
        defer self.allocator.free(serialized);

        var p2p_msg = try p2p.P2PMessage.init(self.allocator, @intFromEnum(BootstrapMessageType.node_announcement), serialized);
        defer p2p_msg.deinit();

        try self.p2p_node.?.broadcastMessage(&p2p_msg);
        std.debug.print("📢 Announced node to network: {s}:{}\n", .{ self.local_address, self.local_port });
    }

    pub fn getBootstrapNodeCount(self: *const BootstrapClient) usize {
        return self.bootstrap_nodes.items.len;
    }

    pub fn getActiveBootstrapNodes(self: *const BootstrapClient) usize {
        var active: usize = 0;
        const current_time = std.time.timestamp();
        
        for (self.bootstrap_nodes.items) |node| {
            if ((current_time - node.last_seen) < 300) { // 5 minutes
                active += 1;
            }
        }
        
        return active;
    }
};

// Bootstrap server for acting as a bootstrap node
pub const BootstrapServer = struct {
    allocator: std.mem.Allocator,
    known_peers: std.ArrayList(BootstrapNodeConfig),
    p2p_node: ?*p2p.P2PNode,
    local_address: []const u8,
    local_port: u16,
    max_peers: usize,

    pub fn init(allocator: std.mem.Allocator, local_address: []const u8, local_port: u16, max_peers: usize) !BootstrapServer {
        return BootstrapServer{
            .allocator = allocator,
            .known_peers = std.ArrayList(BootstrapNodeConfig).init(allocator),
            .p2p_node = null,
            .local_address = try allocator.dupe(u8, local_address),
            .local_port = local_port,
            .max_peers = max_peers,
        };
    }

    pub fn deinit(self: *BootstrapServer) void {
        for (self.known_peers.items) |*peer| {
            peer.deinit(self.allocator);
        }
        self.known_peers.deinit();
        if (self.local_address.len > 0) {
            self.allocator.free(self.local_address);
        }
    }

    pub fn attachP2PNode(self: *BootstrapServer, p2p_node: *p2p.P2PNode) !void {
        self.p2p_node = p2p_node;

        // Register bootstrap message handlers
        try p2p_node.registerMessageHandler(@intFromEnum(BootstrapMessageType.bootstrap_request), handleBootstrapRequest);
        try p2p_node.registerMessageHandler(@intFromEnum(BootstrapMessageType.peer_list_request), handlePeerListRequest);
        try p2p_node.registerMessageHandler(@intFromEnum(BootstrapMessageType.node_announcement), handleNodeAnnouncement);
    }

    pub fn addKnownPeer(self: *BootstrapServer, address: []const u8, port: u16) !void {
        // Don't add ourselves
        if (std.mem.eql(u8, address, self.local_address) and port == self.local_port) {
            return;
        }

        // Check if peer already exists
        for (self.known_peers.items) |peer| {
            if (std.mem.eql(u8, peer.address, address) and peer.port == port) {
                return; // Already exists
            }
        }

        // Remove oldest peer if at capacity
        if (self.known_peers.items.len >= self.max_peers) {
            var oldest_index: usize = 0;
            var oldest_time = self.known_peers.items[0].last_seen;
            
            for (self.known_peers.items, 0..) |peer, i| {
                if (peer.last_seen < oldest_time) {
                    oldest_time = peer.last_seen;
                    oldest_index = i;
                }
            }
            
            self.known_peers.items[oldest_index].deinit(self.allocator);
            _ = self.known_peers.swapRemove(oldest_index);
        }

        const peer_config = try BootstrapNodeConfig.init(self.allocator, address, port);
        try self.known_peers.append(peer_config);
        
        std.debug.print("📝 Added known peer: {s}:{}\n", .{ address, port });
    }

    pub fn getPeerList(self: *const BootstrapServer, allocator: std.mem.Allocator, max_peers: usize) ![]u8 {
        var peer_list = std.ArrayList(u8).init(allocator);
        defer peer_list.deinit();

        const count = @min(max_peers, self.known_peers.items.len);
        
        // Write peer count
        try peer_list.writer().writeInt(u32, @intCast(count), .little);
        
        // Write peer information
        for (self.known_peers.items[0..count]) |peer| {
            // Address length
            try peer_list.writer().writeInt(u16, @intCast(peer.address.len), .little);
            // Address
            try peer_list.writer().writeAll(peer.address);
            // Port
            try peer_list.writer().writeInt(u16, peer.port, .little);
        }
        
        return try allocator.dupe(u8, peer_list.items);
    }

    pub fn getKnownPeerCount(self: *const BootstrapServer) usize {
        return self.known_peers.items.len;
    }
};

// Message handlers
// Helper function for connecting to peer with retry mechanism
fn connectToPeerWithRetry(p2p_node: *p2p.P2PNode, peer_info_str: []const u8) !u32 {
    // 피어 정보가 "address:port" 형태라고 가정
    if (std.mem.indexOf(u8, peer_info_str, ":")) |colon_pos| {
        const address = peer_info_str[0..colon_pos];
        const port_str = peer_info_str[colon_pos + 1..];
        
        if (std.fmt.parseInt(u16, port_str, 10)) |peer_port| {
            std.debug.print("🌐 Attempting to connect to peer: {s}:{}\n", .{ address, peer_port });
            
            // 피어에 연결 시도 (재시도 메커니즘 포함)
            const peer_address = std.net.Address.parseIp4(address, peer_port) catch {
                std.debug.print("❌ Invalid peer address: {s}:{}\n", .{ address, peer_port });
                return 0;
            };
            
            // 이미 연결된 피어인지 확인
            var already_connected = false;
            for (p2p_node.peers.items) |existing_peer| {
                if (std.net.Address.eql(existing_peer.address, peer_address)) {
                    already_connected = true;
                    std.debug.print("ℹ️  Already connected to peer: {s}:{}\n", .{ address, peer_port });
                    break;
                }
            }
            
            if (!already_connected) {
                // 연결 재시도 (최대 3회)
                var connect_success = false;
                var retry_count: u8 = 0;
                const max_retries: u8 = 3;
                
                while (retry_count < max_retries and !connect_success) {
                    if (retry_count > 0) {
                        std.debug.print("🔄 Retrying connection to {s}:{} (attempt {})\n", .{ address, peer_port, retry_count + 1 });
                        std.time.sleep(1000000000); // 1 second delay
                    }
                    
                    _ = p2p_node.connectToPeer(peer_address) catch |err| {
                        retry_count += 1;
                        if (retry_count >= max_retries) {
                            std.debug.print("❌ Failed to connect to peer {s}:{} after {} attempts: {}\n", .{ address, peer_port, max_retries, err });
                        }
                        continue;
                    };
                    
                    connect_success = true;
                    std.debug.print("✅ Connected to peer: {s}:{}\n", .{ address, peer_port });
                    return 1; // Successfully connected
                }
            }
        } else |_| {
            std.debug.print("❌ Invalid port number: {s}\n", .{port_str});
        }
    } else {
        std.debug.print("❌ Invalid peer format: {s}\n", .{peer_info_str});
    }
    
    return 0; // Failed to connect
}

fn handleBootstrapRequest(p2p_node: *p2p.P2PNode, peer: *p2p.PeerConnection, message: *const p2p.P2PMessage) !void {
    _ = peer;
    std.debug.print("🔗 Bootstrap: Received bootstrap request\n", .{});
    
    var bootstrap_msg = try BootstrapMessage.deserialize(p2p_node.allocator, message.payload);
    defer bootstrap_msg.deinit(p2p_node.allocator);
    
    // Send bootstrap response with actual node information
    const response_payload = try std.fmt.allocPrint(p2p_node.allocator, "BOOTSTRAP_RESPONSE:WELCOME", .{});
    defer p2p_node.allocator.free(response_payload);
    
    // Get actual local address and port
    const local_address_str = try std.fmt.allocPrint(p2p_node.allocator, "127.0.0.1", .{});
    defer p2p_node.allocator.free(local_address_str);
    
    var response_msg = try BootstrapMessage.init(
        p2p_node.allocator,
        .bootstrap_response,
        local_address_str,
        p2p_node.address.getPort(),
        response_payload
    );
    defer response_msg.deinit(p2p_node.allocator);
    
    const serialized = try response_msg.serialize(p2p_node.allocator);
    defer p2p_node.allocator.free(serialized);
    
    var p2p_response = try p2p.P2PMessage.init(p2p_node.allocator, @intFromEnum(BootstrapMessageType.bootstrap_response), serialized);
    defer p2p_response.deinit();
    
    try p2p_node.broadcastMessage(&p2p_response);
}

fn handleBootstrapResponse(p2p_node: *p2p.P2PNode, peer: *p2p.PeerConnection, message: *const p2p.P2PMessage) !void {
    _ = peer;
    std.debug.print("✅ Bootstrap: Received bootstrap response\n", .{});
    
    var bootstrap_msg = try BootstrapMessage.deserialize(p2p_node.allocator, message.payload);
    defer bootstrap_msg.deinit(p2p_node.allocator);
    
    std.debug.print("📩 Bootstrap response from {s}:{}: {s}\n", .{ bootstrap_msg.sender_address, bootstrap_msg.sender_port, bootstrap_msg.payload });
}

fn handlePeerListRequest(p2p_node: *p2p.P2PNode, peer: *p2p.PeerConnection, message: *const p2p.P2PMessage) !void {
    _ = peer;
    std.debug.print("📋 Bootstrap: Received peer list request\n", .{});
    
    var bootstrap_msg = try BootstrapMessage.deserialize(p2p_node.allocator, message.payload);
    defer bootstrap_msg.deinit(p2p_node.allocator);
    
    // Create a mock peer list (in a real implementation, this would come from the bootstrap server)
    const peer_list_payload = try std.fmt.allocPrint(p2p_node.allocator, "PEER_LIST:127.0.0.1:8001,127.0.0.1:8002", .{});
    defer p2p_node.allocator.free(peer_list_payload);
    
    // Get actual local address and port
    const local_address_str = try std.fmt.allocPrint(p2p_node.allocator, "127.0.0.1", .{});
    defer p2p_node.allocator.free(local_address_str);
    
    var response_msg = try BootstrapMessage.init(
        p2p_node.allocator,
        .peer_list_response,
        local_address_str,
        p2p_node.address.getPort(),
        peer_list_payload
    );
    defer response_msg.deinit(p2p_node.allocator);
    
    const serialized = try response_msg.serialize(p2p_node.allocator);
    defer p2p_node.allocator.free(serialized);
    
    var p2p_response = try p2p.P2PMessage.init(p2p_node.allocator, @intFromEnum(BootstrapMessageType.peer_list_response), serialized);
    defer p2p_response.deinit();
    
    try p2p_node.broadcastMessage(&p2p_response);
}

fn handlePeerListResponse(p2p_node: *p2p.P2PNode, peer: *p2p.PeerConnection, message: *const p2p.P2PMessage) !void {
    _ = peer;
    std.debug.print("📋 Bootstrap: Received peer list response\n", .{});
    
    var bootstrap_msg = try BootstrapMessage.deserialize(p2p_node.allocator, message.payload);
    defer bootstrap_msg.deinit(p2p_node.allocator);
    
    std.debug.print("📋 Peer list from {s}:{}: {s}\n", .{ bootstrap_msg.sender_address, bootstrap_msg.sender_port, bootstrap_msg.payload });
    
    // 피어 목록 파싱 및 새로운 피어에 연결
    if (bootstrap_msg.payload.len > 0) {
        std.debug.print("🔍 Parsing peer list: {s}\n", .{bootstrap_msg.payload});
        
        var peer_count: u32 = 0;
        
        // JSON 형식 지원 (간단한 형태)
        if (std.mem.startsWith(u8, bootstrap_msg.payload, "[") and std.mem.endsWith(u8, bootstrap_msg.payload, "]")) {
            // JSON 배열 형태: ["127.0.0.1:8001", "127.0.0.1:8002"]
            const payload_content = bootstrap_msg.payload[1..bootstrap_msg.payload.len-1]; // [ ] 제거
            var peer_iterator = std.mem.splitAny(u8, payload_content, ",");
            
            while (peer_iterator.next()) |peer_entry| {
                const trimmed_entry = std.mem.trim(u8, peer_entry, " \t\n\r\""); // 따옴표도 제거
                if (trimmed_entry.len > 0) {
                    peer_count += connectToPeerWithRetry(p2p_node, trimmed_entry) catch |err| {
                        std.debug.print("⚠️  Failed to connect to peer {s}: {}\n", .{trimmed_entry, err});
                        0;
                    };
                }
            }
        } else {
            // 쉼표로 구분된 단순 형태: 127.0.0.1:8001,127.0.0.1:8002
            var peer_iterator = std.mem.splitAny(u8, bootstrap_msg.payload, ",");
            
            while (peer_iterator.next()) |peer_info| {
                const trimmed_peer = std.mem.trim(u8, peer_info, " \t\n\r");
                if (trimmed_peer.len > 0) {
                    peer_count += connectToPeerWithRetry(p2p_node, trimmed_peer) catch |err| {
                        std.debug.print("⚠️  Failed to connect to peer {s}: {}\n", .{trimmed_peer, err});
                        0;
                    };
                }
            }
        }
        
        std.debug.print("✅ Bootstrap complete: {} new peers connected\n", .{peer_count});
    } else {
        std.debug.print("⚠️  Empty peer list received\n", .{});
    }
}

fn handleNodeAnnouncement(p2p_node: *p2p.P2PNode, peer: *p2p.PeerConnection, message: *const p2p.P2PMessage) !void {
    _ = peer;
    std.debug.print("📢 Bootstrap: Received node announcement\n", .{});
    
    var bootstrap_msg = try BootstrapMessage.deserialize(p2p_node.allocator, message.payload);
    defer bootstrap_msg.deinit(p2p_node.allocator);
    
    std.debug.print("📢 Node announcement from {s}:{}: {s}\n", .{ bootstrap_msg.sender_address, bootstrap_msg.sender_port, bootstrap_msg.payload });
    
    // 공지된 노드를 알려진 피어 목록에 추가
    const announced_address = std.net.Address.parseIp4(bootstrap_msg.sender_address, bootstrap_msg.sender_port) catch {
        std.debug.print("❌ Invalid announced address: {s}:{}\n", .{ bootstrap_msg.sender_address, bootstrap_msg.sender_port });
        return;
    };
    
    // 이미 연결된 피어인지 확인
    var already_connected = false;
    for (p2p_node.peers.items) |existing_peer| {
        if (std.net.Address.eql(existing_peer.address, announced_address)) {
            already_connected = true;
            break;
        }
    }
    
    if (!already_connected) {
        std.debug.print("🌐 Connecting to announced node: {s}:{}\n", .{ bootstrap_msg.sender_address, bootstrap_msg.sender_port });
        
        // 연결 재시도 메커니즘 (최대 2회)
        var connect_success = false;
        var retry_count: u8 = 0;
        const max_retries: u8 = 2;
        
        while (retry_count < max_retries and !connect_success) {
            if (retry_count > 0) {
                std.debug.print("🔄 Retrying connection to announced node (attempt {})\n", .{retry_count + 1});
                std.time.sleep(500000000); // 0.5 second delay
            }
            
            _ = p2p_node.connectToPeer(announced_address) catch |err| {
                retry_count += 1;
                if (retry_count >= max_retries) {
                    std.debug.print("❌ Failed to connect to announced node after {} attempts: {}\n", .{ max_retries, err });
                }
                continue;
            };
            
            connect_success = true;
            std.debug.print("✅ Successfully connected to announced node\n", .{});
        }
    } else {
        std.debug.print("ℹ️  Already connected to announced node\n", .{});
    }
}

test "Bootstrap node config" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var config = try BootstrapNodeConfig.init(allocator, "127.0.0.1", 8000);
    defer config.deinit(allocator);
    
    try testing.expect(std.mem.eql(u8, config.address, "127.0.0.1"));
    try testing.expect(config.port == 8000);
}

test "Bootstrap message serialization" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var original_msg = try BootstrapMessage.init(allocator, .bootstrap_request, "127.0.0.1", 8000, "test payload");
    defer original_msg.deinit(allocator);
    
    const serialized = try original_msg.serialize(allocator);
    defer allocator.free(serialized);
    
    var deserialized_msg = try BootstrapMessage.deserialize(allocator, serialized);
    defer deserialized_msg.deinit(allocator);
    
    try testing.expect(deserialized_msg.type == .bootstrap_request);
    try testing.expect(std.mem.eql(u8, deserialized_msg.sender_address, "127.0.0.1"));
    try testing.expect(deserialized_msg.sender_port == 8000);
    try testing.expect(std.mem.eql(u8, deserialized_msg.payload, "test payload"));
}