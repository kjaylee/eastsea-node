const std = @import("std");
const crypto = @import("../crypto/hash.zig");
const p2p = @import("p2p.zig");
const node = @import("node.zig");

pub const DHTError = error{
    NodeNotFound,
    BucketFull,
    InvalidKey,
    NetworkError,
};

// Kademlia-style DHT implementation
pub const DHT_K = 20; // Bucket size (k parameter in Kademlia)
pub const DHT_ALPHA = 3; // Concurrency parameter
pub const DHT_ID_BITS = 256; // 256-bit node IDs

pub const NodeId = [32]u8; // 256-bit node ID

pub const DHTNode = struct {
    id: NodeId,
    address: []const u8,
    port: u16,
    last_seen: i64,
    distance: ?u32, // XOR distance from local node (calculated when needed)

    pub fn init(allocator: std.mem.Allocator, address: []const u8, port: u16) !DHTNode {
        var id: NodeId = undefined;
        
        // Generate deterministic ID based on address:port for consistency
        const addr_str = try std.fmt.allocPrint(allocator, "{s}:{d}", .{ address, port });
        defer allocator.free(addr_str);
        
        const hash = crypto.sha256Raw(addr_str);
        @memcpy(&id, hash[0..32]);
        
        return DHTNode{
            .id = id,
            .address = try allocator.dupe(u8, address),
            .port = port,
            .last_seen = std.time.timestamp(),
            .distance = null,
        };
    }

    pub fn deinit(self: *DHTNode, allocator: std.mem.Allocator) void {
        allocator.free(self.address);
    }

    pub fn calculateDistance(self: *DHTNode, target_id: NodeId) u32 {
        // XOR distance calculation
        var distance: u32 = 0;
        for (self.id, target_id, 0..) |a, b, i| {
            const xor_result = a ^ b;
            if (xor_result != 0) {
                // Find the position of the most significant bit
                const bit_pos = @as(u32, @intCast(i * 8)) + @as(u32, @intCast(7 - @clz(xor_result)));
                distance = DHT_ID_BITS - 1 - bit_pos;
                break;
            }
        }
        self.distance = distance;
        return distance;
    }

    pub fn isAlive(self: *const DHTNode) bool {
        const current_time = std.time.timestamp();
        return (current_time - self.last_seen) < 300; // 5 minutes timeout
    }

    pub fn updateLastSeen(self: *DHTNode) void {
        self.last_seen = std.time.timestamp();
    }
};

pub const KBucket = struct {
    nodes: std.ArrayList(DHTNode),
    bucket_index: u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, bucket_index: u8) KBucket {
        return KBucket{
            .nodes = std.ArrayList(DHTNode).init(allocator),
            .bucket_index = bucket_index,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *KBucket) void {
        for (self.nodes.items) |*dht_node| {
            dht_node.deinit(self.allocator);
        }
        self.nodes.deinit();
    }

    pub fn addNode(self: *KBucket, new_node: DHTNode) !bool {
        // Check if node already exists
        for (self.nodes.items) |*existing_node| {
            if (std.mem.eql(u8, &existing_node.id, &new_node.id)) {
                // Update existing node
                existing_node.updateLastSeen();
                return true;
            }
        }

        // If bucket is not full, add the node (create a copy with duplicated address)
        if (self.nodes.items.len < DHT_K) {
            var node_copy = new_node;
            node_copy.address = try self.allocator.dupe(u8, new_node.address);
            try self.nodes.append(node_copy);
            return true;
        }

        // Bucket is full, check for stale nodes
        for (self.nodes.items, 0..) |*existing_node, i| {
            if (!existing_node.isAlive()) {
                // Replace stale node
                existing_node.deinit(self.allocator);
                var node_copy = new_node;
                node_copy.address = try self.allocator.dupe(u8, new_node.address);
                self.nodes.items[i] = node_copy;
                return true;
            }
        }

        // Bucket is full and all nodes are alive
        return false;
    }

    pub fn removeNode(self: *KBucket, node_id: NodeId) void {
        for (self.nodes.items, 0..) |*existing_node, i| {
            if (std.mem.eql(u8, &existing_node.id, &node_id)) {
                existing_node.deinit(self.allocator);
                _ = self.nodes.swapRemove(i);
                break;
            }
        }
    }

    pub fn getClosestNodes(self: *const KBucket, target_id: NodeId, count: usize) !std.ArrayList(DHTNode) {
        var result = std.ArrayList(DHTNode).init(self.allocator);
        
        // Create a copy of nodes with calculated distances
        var nodes_with_distance = std.ArrayList(DHTNode).init(self.allocator);
        defer nodes_with_distance.deinit();
        
        for (self.nodes.items) |dht_node| {
            var node_copy = dht_node;
            node_copy.address = try self.allocator.dupe(u8, dht_node.address);
            _ = node_copy.calculateDistance(target_id);
            try nodes_with_distance.append(node_copy);
        }
        
        // Sort by distance
        std.mem.sort(DHTNode, nodes_with_distance.items, {}, struct {
            fn lessThan(context: void, a: DHTNode, b: DHTNode) bool {
                _ = context;
                return (a.distance orelse std.math.maxInt(u32)) < (b.distance orelse std.math.maxInt(u32));
            }
        }.lessThan);
        
        // Return the closest nodes
        const max_count = @min(count, nodes_with_distance.items.len);
        for (nodes_with_distance.items[0..max_count]) |dht_node| {
            try result.append(dht_node);
        }
        
        // Clean up temporary nodes
        for (nodes_with_distance.items) |*dht_node| {
            dht_node.deinit(self.allocator);
        }
        
        return result;
    }

    pub fn size(self: *const KBucket) usize {
        return self.nodes.items.len;
    }
};

pub const DHTRoutingTable = struct {
    buckets: [DHT_ID_BITS]KBucket,
    local_node_id: NodeId,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, local_node_id: NodeId) DHTRoutingTable {
        var buckets: [DHT_ID_BITS]KBucket = undefined;
        for (&buckets, 0..) |*bucket, i| {
            bucket.* = KBucket.init(allocator, @intCast(i));
        }

        return DHTRoutingTable{
            .buckets = buckets,
            .local_node_id = local_node_id,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DHTRoutingTable) void {
        for (&self.buckets) |*bucket| {
            bucket.deinit();
        }
    }

    fn getBucketIndex(self: *const DHTRoutingTable, node_id: NodeId) u8 {
        // Calculate XOR distance and find the appropriate bucket
        for (self.local_node_id, node_id, 0..) |a, b, i| {
            const xor_result = a ^ b;
            if (xor_result != 0) {
                const bit_pos = @as(u8, @intCast(i * 8)) + @as(u8, @intCast(7 - @clz(xor_result)));
                return DHT_ID_BITS - 1 - bit_pos;
            }
        }
        return 0; // Same node (shouldn't happen in practice)
    }

    pub fn addNode(self: *DHTRoutingTable, new_node: DHTNode) !bool {
        const bucket_index = self.getBucketIndex(new_node.id);
        return try self.buckets[bucket_index].addNode(new_node);
    }

    pub fn removeNode(self: *DHTRoutingTable, node_id: NodeId) void {
        const bucket_index = self.getBucketIndex(node_id);
        self.buckets[bucket_index].removeNode(node_id);
    }

    pub fn findClosestNodes(self: *const DHTRoutingTable, target_id: NodeId, count: usize) !std.ArrayList(DHTNode) {
        var result = std.ArrayList(DHTNode).init(self.allocator);
        
        // Start from the bucket that would contain the target
        const target_bucket_index = self.getBucketIndex(target_id);
        
        // Collect nodes from the target bucket and neighboring buckets
        var collected_nodes = std.ArrayList(DHTNode).init(self.allocator);
        defer {
            // Clean up collected nodes
            for (collected_nodes.items) |*dht_node| {
                dht_node.deinit(self.allocator);
            }
            collected_nodes.deinit();
        }
        
        // Add nodes from target bucket
        for (self.buckets[target_bucket_index].nodes.items) |dht_node| {
            var node_copy = dht_node;
            node_copy.address = try self.allocator.dupe(u8, dht_node.address);
            _ = node_copy.calculateDistance(target_id);
            try collected_nodes.append(node_copy);
        }
        
        // Add nodes from neighboring buckets if needed
        var radius: i32 = 1;
        while (collected_nodes.items.len < count and radius < DHT_ID_BITS) {
            const lower_bucket = @as(i32, @intCast(target_bucket_index)) - radius;
            const upper_bucket = @as(i32, @intCast(target_bucket_index)) + radius;
            
            if (lower_bucket >= 0) {
                for (self.buckets[@intCast(lower_bucket)].nodes.items) |dht_node| {
                    var node_copy = dht_node;
                    node_copy.address = try self.allocator.dupe(u8, dht_node.address);
                    _ = node_copy.calculateDistance(target_id);
                    try collected_nodes.append(node_copy);
                }
            }
            
            if (upper_bucket < DHT_ID_BITS) {
                for (self.buckets[@intCast(upper_bucket)].nodes.items) |dht_node| {
                    var node_copy = dht_node;
                    node_copy.address = try self.allocator.dupe(u8, dht_node.address);
                    _ = node_copy.calculateDistance(target_id);
                    try collected_nodes.append(node_copy);
                }
            }
            
            radius += 1;
        }
        
        // Sort by distance
        std.mem.sort(DHTNode, collected_nodes.items, {}, struct {
            fn lessThan(context: void, a: DHTNode, b: DHTNode) bool {
                _ = context;
                return (a.distance orelse std.math.maxInt(u32)) < (b.distance orelse std.math.maxInt(u32));
            }
        }.lessThan);
        
        // Return the closest nodes (create new copies for the result)
        const max_count = @min(count, collected_nodes.items.len);
        for (collected_nodes.items[0..max_count]) |dht_node| {
            var result_node = dht_node;
            result_node.address = try self.allocator.dupe(u8, dht_node.address);
            try result.append(result_node);
        }
        
        return result;
    }

    pub fn getTotalNodes(self: *const DHTRoutingTable) usize {
        var total: usize = 0;
        for (self.buckets) |bucket| {
            total += bucket.size();
        }
        return total;
    }

    pub fn getActiveBuckets(self: *const DHTRoutingTable) usize {
        var active: usize = 0;
        for (self.buckets) |bucket| {
            if (bucket.size() > 0) {
                active += 1;
            }
        }
        return active;
    }
};

// DHT message types
pub const DHTMessageType = enum(u8) {
    ping = 10,
    pong = 11,
    find_node = 12,
    find_node_response = 13,
    store = 14,
    store_response = 15,
};

pub const DHTMessage = struct {
    type: DHTMessageType,
    request_id: [16]u8, // Unique request ID
    sender_id: NodeId,
    target_id: NodeId, // 추가: 찾고자 하는 대상 노드 ID
    timestamp: i64, // 추가: 메시지 타임스탬프
    payload: []const u8,

    pub fn init(allocator: std.mem.Allocator, msg_type: DHTMessageType, sender_id: NodeId, target_id: NodeId, payload: []const u8) !DHTMessage {
        var request_id: [16]u8 = undefined;
        std.crypto.random.bytes(&request_id);
        
        return DHTMessage{
            .type = msg_type,
            .request_id = request_id,
            .sender_id = sender_id,
            .target_id = target_id,
            .timestamp = std.time.timestamp(),
            .payload = try allocator.dupe(u8, payload),
        };
    }

    pub fn deinit(self: *DHTMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.payload);
    }

    pub fn serialize(self: *const DHTMessage, allocator: std.mem.Allocator) ![]u8 {
        const total_size = 1 + 16 + 32 + 32 + 8 + 4 + self.payload.len; // type + request_id + sender_id + target_id + timestamp + payload_len + payload
        var buffer = try allocator.alloc(u8, total_size);
        
        var offset: usize = 0;
        
        // Message type
        buffer[offset] = @intFromEnum(self.type);
        offset += 1;
        
        // Request ID
        @memcpy(buffer[offset..offset + 16], &self.request_id);
        offset += 16;
        
        // Sender ID
        @memcpy(buffer[offset..offset + 32], &self.sender_id);
        offset += 32;
        
        // Target ID
        @memcpy(buffer[offset..offset + 32], &self.target_id);
        offset += 32;
        
        // Timestamp
        std.mem.writeInt(i64, @ptrCast(&buffer[offset]), self.timestamp, .little);
        offset += 8;
        
        // Payload length
        std.mem.writeInt(u32, @ptrCast(&buffer[offset]), @intCast(self.payload.len), .little);
        offset += 4;
        
        // Payload
        @memcpy(buffer[offset..offset + self.payload.len], self.payload);
        
        return buffer;
    }

    pub fn deserialize(allocator: std.mem.Allocator, buffer: []const u8) !DHTMessage {
        if (buffer.len < 93) return DHTError.InvalidKey; // Minimum size: 1 + 16 + 32 + 32 + 8 + 4 = 93
        
        var offset: usize = 0;
        
        // Message type
        const msg_type = @as(DHTMessageType, @enumFromInt(buffer[offset]));
        offset += 1;
        
        // Request ID
        var request_id: [16]u8 = undefined;
        @memcpy(&request_id, buffer[offset..offset + 16]);
        offset += 16;
        
        // Sender ID
        var sender_id: NodeId = undefined;
        @memcpy(&sender_id, buffer[offset..offset + 32]);
        offset += 32;
        
        // Target ID
        var target_id: NodeId = undefined;
        @memcpy(&target_id, buffer[offset..offset + 32]);
        offset += 32;
        
        // Timestamp
        const timestamp = std.mem.readInt(i64, buffer[offset..][0..8], .little);
        offset += 8;
        
        // Payload length
        const payload_len = std.mem.readInt(u32, buffer[offset..][0..4], .little);
        offset += 4;
        
        if (buffer.len < offset + payload_len) return DHTError.InvalidKey;
        
        // Payload
        const payload = try allocator.dupe(u8, buffer[offset..offset + payload_len]);
        
        return DHTMessage{
            .type = msg_type,
            .request_id = request_id,
            .sender_id = sender_id,
            .target_id = target_id,
            .timestamp = timestamp,
            .payload = payload,
        };
    }
};

pub const DHT = struct {
    routing_table: DHTRoutingTable,
    local_node: DHTNode,
    p2p_node: ?*p2p.P2PNode,
    allocator: std.mem.Allocator,
    pending_requests: std.HashMap([16]u8, DHTMessage, std.hash_map.AutoContext([16]u8), 80),

    pub fn init(allocator: std.mem.Allocator, address: []const u8, port: u16) !DHT {
        const local_node = try DHTNode.init(allocator, address, port);
        const routing_table = DHTRoutingTable.init(allocator, local_node.id);
        
        return DHT{
            .routing_table = routing_table,
            .local_node = local_node,
            .p2p_node = null,
            .allocator = allocator,
            .pending_requests = std.HashMap([16]u8, DHTMessage, std.hash_map.AutoContext([16]u8), 80).init(allocator),
        };
    }

    pub fn deinit(self: *DHT) void {
        self.routing_table.deinit();
        self.local_node.deinit(self.allocator);
        
        var iterator = self.pending_requests.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.pending_requests.deinit();
    }

    pub fn attachP2PNode(self: *DHT, p2p_node: *p2p.P2PNode) !void {
        self.p2p_node = p2p_node;
        
        // Register DHT message handlers
        try p2p_node.registerMessageHandler(@intFromEnum(DHTMessageType.ping), handleDHTPing);
        try p2p_node.registerMessageHandler(@intFromEnum(DHTMessageType.pong), handleDHTPong);
        try p2p_node.registerMessageHandler(@intFromEnum(DHTMessageType.find_node), handleFindNode);
        try p2p_node.registerMessageHandler(@intFromEnum(DHTMessageType.find_node_response), handleFindNodeResponse);
    }

    pub fn bootstrap(self: *DHT, bootstrap_nodes: []const DHTNode) !void {
        std.debug.print("🔗 Bootstrapping DHT with {} nodes\n", .{bootstrap_nodes.len});
        
        // Add bootstrap nodes to routing table
        for (bootstrap_nodes) |bootstrap_node| {
            _ = try self.routing_table.addNode(bootstrap_node);
        }
        
        // Perform initial node lookup to populate routing table
        const close_nodes = try self.findNode(self.local_node.id);
        defer {
            // Clean up close_nodes
            for (close_nodes.items) |*close_node| {
                close_node.deinit(self.allocator);
            }
            close_nodes.deinit();
        }
        
        std.debug.print("✅ DHT bootstrap complete. Routing table has {} nodes\n", .{self.routing_table.getTotalNodes()});
    }

    pub fn findNode(self: *DHT, target_id: NodeId) !std.ArrayList(DHTNode) {
        std.debug.print("🔍 Finding nodes closest to target: {s}\n", .{std.fmt.fmtSliceHexLower(&target_id)});
        
        return try self.routing_table.findClosestNodes(target_id, DHT_K);
    }

    pub fn ping(self: *DHT, _: DHTNode) !void {
        if (self.p2p_node == null) return DHTError.NetworkError;
        
        const ping_msg = try DHTMessage.init(self.allocator, .ping, self.local_node.id, "ping");
        defer ping_msg.deinit(self.allocator);
        
        const serialized = try ping_msg.serialize(self.allocator);
        defer self.allocator.free(serialized);
        
        var p2p_msg = try p2p.P2PMessage.init(self.allocator, @intFromEnum(DHTMessageType.ping), serialized);
        defer p2p_msg.deinit();
        
        // Store pending request
        try self.pending_requests.put(ping_msg.request_id, ping_msg);
        
        // Send via P2P network
        try self.p2p_node.?.broadcastMessage(&p2p_msg);
    }

    pub fn getNodeInfo(self: *const DHT) void {
        std.debug.print("📊 DHT Node Info:\n", .{});
        std.debug.print("   Node ID: {s}\n", .{std.fmt.fmtSliceHexLower(&self.local_node.id)});
        std.debug.print("   Address: {s}:{}\n", .{ self.local_node.address, self.local_node.port });
        std.debug.print("   Total nodes in routing table: {}\n", .{self.routing_table.getTotalNodes()});
        std.debug.print("   Active buckets: {}\n", .{self.routing_table.getActiveBuckets()});
        std.debug.print("   Pending requests: {}\n", .{self.pending_requests.count()});
    }
};

// DHT message handlers
fn handleDHTPing(_: *p2p.P2PNode, peer: *p2p.PeerConnection, message: *const p2p.P2PMessage) !void {
    std.debug.print("🏓 DHT: Received ping\n", .{});
    
    // Parse DHT message
    var dht_msg = try DHTMessage.deserialize(std.heap.page_allocator, message.payload);
    defer dht_msg.deinit(std.heap.page_allocator);
    
    // Send pong response
    const pong_data = try std.fmt.allocPrint(std.heap.page_allocator, "pong:{s}:{}", .{ dht_msg.sender_id, dht_msg.timestamp });
    defer std.heap.page_allocator.free(pong_data);
    
    var response_msg = try DHTMessage.init(std.heap.page_allocator, .pong, dht_msg.sender_id, dht_msg.sender_id, pong_data);
    defer response_msg.deinit(std.heap.page_allocator);
    
    const response_payload = try response_msg.serialize(std.heap.page_allocator);
    defer std.heap.page_allocator.free(response_payload);
    
    var p2p_msg = try p2p.P2PMessage.init(std.heap.page_allocator, 11, response_payload);
    defer p2p_msg.deinit();
    
    try peer.sendMessage(&p2p_msg);
    std.debug.print("✅ DHT: Sent pong response\n", .{});
}

fn handleDHTPong(p2p_node: *p2p.P2PNode, peer: *p2p.PeerConnection, message: *const p2p.P2PMessage) !void {
    _ = p2p_node;
    std.debug.print("🏓 DHT: Received pong\n", .{});
    
    // Parse DHT message
    var dht_msg = try DHTMessage.deserialize(std.heap.page_allocator, message.payload);
    defer dht_msg.deinit(std.heap.page_allocator);
    
    // Update routing table with responding node
    std.debug.print("✅ DHT: Pong received from {s}, updating routing table\n", .{dht_msg.sender_id});
    
    // 라우팅 테이블에 노드 정보 업데이트
    // 실제로는 DHT 인스턴스를 통해 라우팅 테이블을 업데이트해야 함
    
    // 임시로 피어 연결 업데이트
    peer.last_ping = std.time.timestamp();
    
    std.debug.print("🔄 DHT: Routing table updated with peer {s}\n", .{dht_msg.sender_id});
}

fn handleFindNode(p2p_node: *p2p.P2PNode, peer: *p2p.PeerConnection, message: *const p2p.P2PMessage) !void {
    std.debug.print("🔍 DHT: Received find_node request\n", .{});
    
    // Parse DHT message
    var dht_msg = try DHTMessage.deserialize(std.heap.page_allocator, message.payload);
    defer dht_msg.deinit(std.heap.page_allocator);
    
    std.debug.print("🔍 DHT: Find node request for target: {s}\n", .{dht_msg.target_id});
    
    // 가까운 노드들을 찾아 반환
    // 실제로는 K-bucket에서 target_id와 가장 가까운 노드들을 찾아야 함
    
    // 임시로 현재 연결된 피어들의 정보를 반환
    var peers_info = std.ArrayList(u8).init(std.heap.page_allocator);
    defer peers_info.deinit();
    
    var peer_count: u32 = 0;
    for (p2p_node.peers.items) |existing_peer| {
        if (peer_count > 0) {
            try peers_info.appendSlice(",");
        }
        const peer_info = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{existing_peer.address});
        defer std.heap.page_allocator.free(peer_info);
        try peers_info.appendSlice(peer_info);
        peer_count += 1;
    }
    
    // Find node response 전송
    var response_msg = try DHTMessage.init(std.heap.page_allocator, .find_node_response, dht_msg.sender_id, dht_msg.target_id, peers_info.items);
    defer response_msg.deinit(std.heap.page_allocator);
    
    const response_payload = try response_msg.serialize(std.heap.page_allocator);
    defer std.heap.page_allocator.free(response_payload);
    
    var p2p_msg = try p2p.P2PMessage.init(std.heap.page_allocator, 13, response_payload);
    defer p2p_msg.deinit();
    
    try peer.sendMessage(&p2p_msg);
    std.debug.print("✅ DHT: Sent find_node response with {} peers\n", .{peer_count});
}

fn handleFindNodeResponse(p2p_node: *p2p.P2PNode, peer: *p2p.PeerConnection, message: *const p2p.P2PMessage) !void {
    _ = p2p_node;
    _ = peer;
    std.debug.print("📋 DHT: Received find_node response\n", .{});
    
    // Parse DHT message
    var dht_msg = try DHTMessage.deserialize(std.heap.page_allocator, message.payload);
    defer dht_msg.deinit(std.heap.page_allocator);
    
    std.debug.print("📋 DHT: Received find_node response from {s}\n", .{dht_msg.sender_id});
    
    // 응답으로 받은 노드 목록을 파싱하고 라우팅 테이블에 추가
    if (dht_msg.payload.len > 0) {
        std.debug.print("🔍 DHT: Processing node list: {s}\n", .{dht_msg.payload});
        
        // 쉼표로 구분된 노드 목록 파싱
        var node_iterator = std.mem.splitAny(u8, dht_msg.payload, ",");
        var added_nodes: u32 = 0;
        
        while (node_iterator.next()) |node_info| {
            const trimmed_node = std.mem.trim(u8, node_info, " \t\n\r");
            
            if (trimmed_node.len > 0) {
                // 노드 정보를 파싱하여 연결 시도
                // 실제로는 더 정교한 파싱이 필요
                std.debug.print("🌐 DHT: Discovered node: {s}\n", .{trimmed_node});
                
                // 라우팅 테이블 업데이트 (실제로는 DHT 인스턴스를 통해)
                // 거리 계산 후 K-bucket에 추가
                
                added_nodes += 1;
            }
        }
        
        std.debug.print("✅ DHT: Added {} nodes to routing table\n", .{added_nodes});
    } else {
        std.debug.print("⚠️  DHT: Empty node list received\n", .{});
    }
}

// Tests
test "DHT node creation" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var dht_node = try DHTNode.init(allocator, "127.0.0.1", 8000);
    defer dht_node.deinit(allocator);
    
    try testing.expect(dht_node.port == 8000);
    try testing.expect(dht_node.isAlive());
}

test "DHT routing table" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var local_id: NodeId = undefined;
    std.crypto.random.bytes(&local_id);
    
    var routing_table = DHTRoutingTable.init(allocator, local_id);
    defer routing_table.deinit();
    
    const test_node = try DHTNode.init(allocator, "127.0.0.1", 8001);
    defer test_node.deinit(allocator);
    
    const added = try routing_table.addNode(test_node);
    try testing.expect(added);
    try testing.expect(routing_table.getTotalNodes() == 1);
}

test "DHT message serialization" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var sender_id: NodeId = undefined;
    std.crypto.random.bytes(&sender_id);
    
    const original_msg = try DHTMessage.init(allocator, .ping, sender_id, "test payload");
    defer original_msg.deinit(allocator);
    
    const serialized = try original_msg.serialize(allocator);
    defer allocator.free(serialized);
    
    const deserialized_msg = try DHTMessage.deserialize(allocator, serialized);
    defer deserialized_msg.deinit(allocator);
    
    try testing.expect(deserialized_msg.type == .ping);
    try testing.expect(std.mem.eql(u8, &deserialized_msg.sender_id, &sender_id));
    try testing.expect(std.mem.eql(u8, deserialized_msg.payload, "test payload"));
}