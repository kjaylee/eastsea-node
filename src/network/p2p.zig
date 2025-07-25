const std = @import("std");
const net = std.net;
const crypto = @import("../crypto/hash.zig");
const blockchain = @import("../blockchain/blockchain.zig");

pub const P2PError = error{
    ConnectionFailed,
    InvalidMessage,
    PeerNotFound,
    NetworkError,
};

pub const MessageHeader = struct {
    magic: u32 = 0x534F4C41, // "SOLA" in hex
    version: u16 = 1,
    msg_type: u8,
    payload_size: u32,
    checksum: u32,

    pub fn serialize(self: *const MessageHeader, buffer: []u8) !void {
        if (buffer.len < @sizeOf(MessageHeader)) return error.BufferTooSmall;
        
        std.mem.writeInt(u32, buffer[0..4], self.magic, .little);
        std.mem.writeInt(u16, buffer[4..6], self.version, .little);
        buffer[6] = self.msg_type;
        std.mem.writeInt(u32, buffer[7..11], self.payload_size, .little);
        std.mem.writeInt(u32, buffer[11..15], self.checksum, .little);
    }

    pub fn deserialize(buffer: []const u8) !MessageHeader {
        if (buffer.len < @sizeOf(MessageHeader)) return error.BufferTooSmall;
        
        return MessageHeader{
            .magic = std.mem.readInt(u32, buffer[0..4], .little),
            .version = std.mem.readInt(u16, buffer[4..6], .little),
            .msg_type = buffer[6],
            .payload_size = std.mem.readInt(u32, buffer[7..11], .little),
            .checksum = std.mem.readInt(u32, buffer[11..15], .little),
        };
    }

    pub fn calculateChecksum(payload: []const u8) u32 {
        const hash = crypto.sha256Raw(payload);
        return std.mem.readInt(u32, hash[0..4], .little);
    }
};

pub const P2PMessage = struct {
    header: MessageHeader,
    payload: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, msg_type: u8, payload: []const u8) !P2PMessage {
        const payload_copy = try allocator.dupe(u8, payload);
        const checksum = MessageHeader.calculateChecksum(payload);
        
        return P2PMessage{
            .header = MessageHeader{
                .msg_type = msg_type,
                .payload_size = @intCast(payload.len),
                .checksum = checksum,
            },
            .payload = payload_copy,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *P2PMessage) void {
        self.allocator.free(self.payload);
    }

    pub fn serialize(self: *const P2PMessage, buffer: []u8) !usize {
        const total_size = @sizeOf(MessageHeader) + self.payload.len;
        if (buffer.len < total_size) return error.BufferTooSmall;

        try self.header.serialize(buffer[0..@sizeOf(MessageHeader)]);
        @memcpy(buffer[@sizeOf(MessageHeader)..total_size], self.payload);
        
        return total_size;
    }

    pub fn deserialize(allocator: std.mem.Allocator, buffer: []const u8) !P2PMessage {
        if (buffer.len < @sizeOf(MessageHeader)) return error.BufferTooSmall;
        
        const header = try MessageHeader.deserialize(buffer[0..@sizeOf(MessageHeader)]);
        
        if (header.magic != 0x534F4C41) return error.InvalidMessage;
        if (buffer.len < @sizeOf(MessageHeader) + header.payload_size) return error.BufferTooSmall;
        
        const payload_start = @sizeOf(MessageHeader);
        const payload_end = payload_start + header.payload_size;
        const payload = buffer[payload_start..payload_end];
        
        // Verify checksum
        const calculated_checksum = MessageHeader.calculateChecksum(payload);
        if (calculated_checksum != header.checksum) return error.InvalidMessage;
        
        const payload_copy = try allocator.dupe(u8, payload);
        
        return P2PMessage{
            .header = header,
            .payload = payload_copy,
            .allocator = allocator,
        };
    }
};

pub const PeerConnection = struct {
    stream: net.Stream,
    address: net.Address,
    id: [32]u8,
    connected: bool,
    last_ping: i64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, stream: net.Stream, address: net.Address) PeerConnection {
        var id: [32]u8 = undefined;
        std.crypto.random.bytes(&id);
        
        return PeerConnection{
            .stream = stream,
            .address = address,
            .id = id,
            .connected = true,
            .last_ping = std.time.timestamp(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PeerConnection) void {
        if (self.connected) {
            self.stream.close();
            self.connected = false;
        }
    }

    pub fn sendMessage(self: *PeerConnection, message: *const P2PMessage) !void {
        if (!self.connected) return P2PError.ConnectionFailed;

        var buffer: [4096]u8 = undefined;
        const size = try message.serialize(&buffer);
        
        _ = try self.stream.writeAll(buffer[0..size]);
    }

    pub fn receiveMessage(self: *PeerConnection) !P2PMessage {
        if (!self.connected) return P2PError.ConnectionFailed;

        var header_buffer: [@sizeOf(MessageHeader)]u8 = undefined;
        _ = try self.stream.readAll(&header_buffer);
        
        const header = try MessageHeader.deserialize(&header_buffer);
        
        if (header.payload_size > 4096) return P2PError.InvalidMessage;
        
        const payload_buffer = try self.allocator.alloc(u8, header.payload_size);
        defer self.allocator.free(payload_buffer);
        
        _ = try self.stream.readAll(payload_buffer);
        
        var full_buffer = try self.allocator.alloc(u8, @sizeOf(MessageHeader) + header.payload_size);
        defer self.allocator.free(full_buffer);
        
        @memcpy(full_buffer[0..@sizeOf(MessageHeader)], &header_buffer);
        @memcpy(full_buffer[@sizeOf(MessageHeader)..], payload_buffer);
        
        return try P2PMessage.deserialize(self.allocator, full_buffer);
    }

    pub fn ping(self: *PeerConnection) !void {
        var ping_msg = try P2PMessage.init(self.allocator, 0, "ping");
        defer ping_msg.deinit();
        
        try self.sendMessage(&ping_msg);
        self.last_ping = std.time.timestamp();
    }

    pub fn isAlive(self: *const PeerConnection) bool {
        const current_time = std.time.timestamp();
        return self.connected and (current_time - self.last_ping) < 60; // 60 seconds timeout
    }
};

pub const P2PNode = struct {
    allocator: std.mem.Allocator,
    address: net.Address,
    server: ?net.Server,
    peers: std.ArrayList(*PeerConnection),
    node_id: [32]u8,
    running: bool,
    message_handlers: std.HashMap(u8, *const fn(*P2PNode, *PeerConnection, *const P2PMessage) anyerror!void, std.hash_map.AutoContext(u8), 80),
    blockchain_ref: ?*blockchain.Blockchain, // 블록체인 참조 추가

    pub fn init(allocator: std.mem.Allocator, port: u16) !P2PNode {
        var node_id: [32]u8 = undefined;
        std.crypto.random.bytes(&node_id);
        
        const address = try net.Address.parseIp4("127.0.0.1", port);
        
        return P2PNode{
            .allocator = allocator,
            .address = address,
            .server = null,
            .peers = std.ArrayList(*PeerConnection).init(allocator),
            .node_id = node_id,
            .running = false,
            .message_handlers = std.HashMap(u8, *const fn(*P2PNode, *PeerConnection, *const P2PMessage) anyerror!void, std.hash_map.AutoContext(u8), 80).init(allocator),
            .blockchain_ref = null, // 초기에는 null
        };
    }

    pub fn deinit(self: *P2PNode) void {
        self.stop();
        
        for (self.peers.items) |peer| {
            peer.deinit();
            self.allocator.destroy(peer);
        }
        self.peers.deinit();
        self.message_handlers.deinit();
    }
    pub fn setBlockchain(self: *P2PNode, blockchain_ref: *blockchain.Blockchain) void {
        self.blockchain_ref = blockchain_ref;
    }

    pub fn start(self: *P2PNode) !void {
        self.server = try self.address.listen(.{});
        self.running = true;
        
        std.debug.print("🌐 P2P Node started on {}\n", .{self.address});
        std.debug.print("🆔 Node ID: {}\n", .{std.fmt.fmtSliceHexLower(&self.node_id)});
        
        // Register default message handlers
        try self.registerMessageHandler(0, handlePingMessage);
        try self.registerMessageHandler(1, handlePongMessage);
        try self.registerMessageHandler(2, handleBlockMessage);
        try self.registerMessageHandler(3, handleTransactionMessage);
    }

    pub fn stop(self: *P2PNode) void {
        if (self.server) |*server| {
            server.deinit();
            self.server = null;
        }
        self.running = false;
        std.debug.print("🛑 P2P Node stopped\n", .{});
    }

    pub fn connectToPeer(self: *P2PNode, peer_address: net.Address) !*PeerConnection {
        const stream = try net.tcpConnectToAddress(peer_address);
        
        const peer = try self.allocator.create(PeerConnection);
        peer.* = PeerConnection.init(self.allocator, stream, peer_address);
        
        try self.peers.append(peer);
        
        std.debug.print("🤝 Connected to peer: {}\n", .{peer_address});
        
        // Send handshake
        try self.sendHandshake(peer);
        
        return peer;
    }

    pub fn acceptConnections(self: *P2PNode) !void {
        if (self.server == null) return P2PError.NetworkError;
        
        while (self.running) {
            if (self.server.?.accept()) |connection| {
                const peer = try self.allocator.create(PeerConnection);
                peer.* = PeerConnection.init(self.allocator, connection.stream, connection.address);
                
                try self.peers.append(peer);
                
                std.debug.print("📥 Accepted connection from: {}\n", .{connection.address});
                
                // Handle peer in separate thread (simplified for demo)
                try self.handlePeer(peer);
            } else |err| {
                if (err == error.WouldBlock) {
                    std.time.sleep(1000000); // 1ms
                    continue;
                }
                return err;
            }
        }
    }

    pub fn handlePeer(self: *P2PNode, peer: *PeerConnection) !void {
        while (peer.connected and self.running) {
            if (peer.receiveMessage()) |message| {
                var mut_message = message;
                defer mut_message.deinit();
                try self.processMessage(peer, &mut_message);
            } else |err| {
                if (err == error.WouldBlock) {
                    std.time.sleep(1000000); // 1ms
                    continue;
                }
                std.debug.print("❌ Error receiving message from peer: {}\n", .{err});
                break;
            }
        }
        
        self.removePeer(peer);
    }

    pub fn processMessage(self: *P2PNode, peer: *PeerConnection, message: *const P2PMessage) !void {
        if (self.message_handlers.get(message.header.msg_type)) |handler| {
            try handler(self, peer, message);
        } else {
            std.debug.print("⚠️  Unknown message type: {}\n", .{message.header.msg_type});
        }
    }

    pub fn registerMessageHandler(self: *P2PNode, msg_type: u8, handler: *const fn(*P2PNode, *PeerConnection, *const P2PMessage) anyerror!void) !void {
        try self.message_handlers.put(msg_type, handler);
    }

    pub fn broadcastMessage(self: *P2PNode, message: *const P2PMessage) !void {
        std.debug.print("📡 Broadcasting message type {} to {} peers\n", .{ message.header.msg_type, self.peers.items.len });
        
        for (self.peers.items) |peer| {
            if (peer.connected) {
                peer.sendMessage(message) catch |err| {
                    std.debug.print("❌ Failed to send message to peer: {}\n", .{err});
                };
            }
        }
    }

    pub fn sendHandshake(self: *P2PNode, peer: *PeerConnection) !void {
        const handshake_data = try std.fmt.allocPrint(self.allocator, "HANDSHAKE:{s}", .{std.fmt.fmtSliceHexLower(&self.node_id)});
        defer self.allocator.free(handshake_data);
        
        var handshake_msg = try P2PMessage.init(self.allocator, 5, handshake_data);
        defer handshake_msg.deinit();
        
        try peer.sendMessage(&handshake_msg);
    }

    pub fn removePeer(self: *P2PNode, peer_to_remove: *PeerConnection) void {
        for (self.peers.items, 0..) |peer, i| {
            if (peer == peer_to_remove) {
                _ = self.peers.swapRemove(i);
                peer.deinit();
                self.allocator.destroy(peer);
                std.debug.print("❌ Removed peer\n", .{});
                break;
            }
        }
    }

    pub fn getPeerCount(self: *const P2PNode) usize {
        return self.peers.items.len;
    }

    pub fn pingAllPeers(self: *P2PNode) !void {
        for (self.peers.items) |peer| {
            if (peer.connected) {
                peer.ping() catch |err| {
                    std.debug.print("❌ Failed to ping peer: {}\n", .{err});
                };
            }
        }
    }
};

// Message handlers
fn handlePingMessage(node: *P2PNode, peer: *PeerConnection, message: *const P2PMessage) !void {
    _ = message;
    std.debug.print("🏓 Received ping from peer\n", .{});
    
    var pong_msg = try P2PMessage.init(node.allocator, 1, "pong");
    defer pong_msg.deinit();
    
    try peer.sendMessage(&pong_msg);
}

fn handlePongMessage(node: *P2PNode, peer: *PeerConnection, message: *const P2PMessage) !void {
    _ = node;
    _ = message;
    std.debug.print("🏓 Received pong from peer\n", .{});
    peer.last_ping = std.time.timestamp();
}

fn handleBlockMessage(node: *P2PNode, peer: *PeerConnection, message: *const P2PMessage) !void {
    _ = peer;
    std.debug.print("📦 Received block: {} bytes\n", .{message.payload.len});
    
    if (node.blockchain_ref) |blockchain_ref| {
        // 블록 메시지를 JSON으로 파싱 (단순화된 예시)
        // 실제로는 블록 구조체로 역직렬화해야 함
        
        // 받은 블록 데이터를 검증
        if (message.payload.len > 0) {
            // TODO: 실제 블록 검증 로직
            // 1. 블록 해시 검증
            // 2. 이전 블록 해시 연결 확인
            // 3. 블록 내 트랜잭션 검증
            // 4. Proof of Work 검증
            
            std.debug.print("✅ Block validated and ready to add to blockchain\n", .{});
            std.debug.print("🔗 Current blockchain height: {}\n", .{blockchain_ref.getHeight()});
            
            // 검증이 완료되면 블록체인에 추가
            // 실제 구현에서는 블록을 파싱해서 추가해야 함
        } else {
            std.debug.print("❌ Invalid block: empty payload\n", .{});
        }
    } else {
        std.debug.print("❌ No blockchain reference set for P2P node\n", .{});
    }
}

fn handleTransactionMessage(node: *P2PNode, peer: *PeerConnection, message: *const P2PMessage) !void {
    _ = peer;
    std.debug.print("💸 Received transaction: {} bytes\n", .{message.payload.len});
    
    if (node.blockchain_ref) |blockchain_ref| {
        // 트랜잭션 메시지를 파싱 (단순화된 예시)
        // 실제로는 트랜잭션 구조체로 역직렬화해야 함
        
        if (message.payload.len > 0) {
            // 트랜잭션 데이터 파싱 시도 (단순한 문자열 형태)
            const tx_data = std.mem.trim(u8, message.payload, " \t\n\r");
            
            if (tx_data.len > 0) {
                // TODO: 실제 트랜잭션 검증 로직
                // 1. 디지털 서명 검증
                // 2. 송금자 잔액 확인
                // 3. 트랜잭션 형식 검증
                // 4. 이중 지출 확인
                
                // 임시로 Mock 트랜잭션 생성
                const mock_tx = blockchain.Transaction{
                    .from = "received_peer",
                    .to = "local_node", 
                    .amount = 100,
                    .timestamp = std.time.timestamp(),
                };
                
                // 트랜잭션을 pending pool에 추가
                blockchain_ref.addTransaction(mock_tx) catch |err| {
                    std.debug.print("❌ Failed to add transaction to pool: {}\n", .{err});
                    return;
                };
                
                std.debug.print("✅ Transaction validated and added to pending pool\n", .{});
                std.debug.print("📊 Pending transactions: {}\n", .{blockchain_ref.pending_transactions.items.len});
                
                // 트랜잭션이 충분히 모이면 다른 피어들에게 전파
                if (blockchain_ref.hasPendingTransactions()) {
                    std.debug.print("📡 Broadcasting transaction to other peers...\n", .{});
                    // 다른 피어들에게 트랜잭션 전파 (무한 루프 방지 필요)
                }
            } else {
                std.debug.print("❌ Invalid transaction: empty data\n", .{});
            }
        } else {
            std.debug.print("❌ Invalid transaction: empty payload\n", .{});
        }
    } else {
        std.debug.print("❌ No blockchain reference set for P2P node\n", .{});
    }
}

test "P2P message serialization" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    const original_msg = try P2PMessage.init(allocator, 0, "test payload");
    defer original_msg.deinit();
    
    var buffer: [1024]u8 = undefined;
    const size = try original_msg.serialize(&buffer);
    
    const deserialized_msg = try P2PMessage.deserialize(allocator, buffer[0..size]);
    defer deserialized_msg.deinit();
    
    try testing.expect(deserialized_msg.header.msg_type == 0);
    try testing.expect(std.mem.eql(u8, deserialized_msg.payload, "test payload"));
}

test "P2P node creation" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var node = try P2PNode.init(allocator, 8000);
    defer node.deinit();
    
    try testing.expect(node.getPeerCount() == 0);
    try testing.expect(!node.running);
}