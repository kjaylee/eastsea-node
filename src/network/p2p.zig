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
        // Try to bind to the address, with retry logic for port conflicts
        self.server = self.address.listen(.{}) catch |err| switch (err) {
            error.AddressInUse => {
                std.debug.print("⚠️  Port {} in use, trying to find available port...\n", .{self.address.getPort()});
                return self.findAndBindAvailablePort();
            },
            else => return err,
        };
        self.running = true;
        
        std.debug.print("🌐 P2P Node started on {}\n", .{self.address});
        std.debug.print("🆔 Node ID: {}\n", .{std.fmt.fmtSliceHexLower(&self.node_id)});
        
        // Register default message handlers
        try self.registerMessageHandler(0, handlePingMessage);
        try self.registerMessageHandler(1, handlePongMessage);
        try self.registerMessageHandler(2, handleBlockMessage);
        try self.registerMessageHandler(3, handleTransactionMessage);
    }
    
    fn findAndBindAvailablePort(self: *P2PNode) !void {
        const base_port = self.address.getPort();
        var port = base_port;
        const max_attempts = 10;
        
        for (0..max_attempts) |i| {
            port = base_port + @as(u16, @intCast(i));
            const new_address = std.net.Address.initIp4([4]u8{127, 0, 0, 1}, port);
            
            if (new_address.listen(.{})) |server| {
                self.server = server;
                self.address = new_address;
                std.debug.print("✅ Found available port: {}\n", .{port});
                return;
            } else |_| {
                continue;
            }
        }
        
        return error.NoAvailablePort;
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
        const stream = net.tcpConnectToAddress(peer_address) catch |err| switch (err) {
            error.ConnectionRefused => {
                std.debug.print("⚠️  Could not connect to peer {}: Connection refused\n", .{peer_address});
                return error.PeerNotFound;
            },
            error.NetworkUnreachable => {
                std.debug.print("⚠️  Could not connect to peer {}: Network unreachable\n", .{peer_address});
                return error.NetworkError;
            },
            error.ConnectionTimedOut => {
                std.debug.print("⚠️  Could not connect to peer {}: Connection timed out\n", .{peer_address});
                return error.ConnectionTimedOut;
            },
            else => {
                std.debug.print("⚠️  Could not connect to peer {}: {}\n", .{ peer_address, err });
                return err;
            },
        };
        
        const peer = try self.allocator.create(PeerConnection);
        peer.* = PeerConnection.init(self.allocator, stream, peer_address);
        
        try self.peers.append(peer);
        
        std.debug.print("🤝 Connected to peer: {}\n", .{peer_address});
        
        // Send handshake
        self.sendHandshake(peer) catch |err| {
            std.debug.print("⚠️  Failed to send handshake to {}: {}\n", .{ peer_address, err });
            // Don't fail the connection for handshake errors
        };
        
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
        if (message.payload.len > 0) {
            // 블록 데이터를 문자열로 파싱 (간단한 형태로 시뮬레이션)
            const block_data = std.mem.trim(u8, message.payload, " \t\n\r");
            
            // 블록 데이터 검증 (간단한 형태)
            if (std.mem.startsWith(u8, block_data, "BLOCK:")) {
                std.debug.print("🔍 Validating received block...\n", .{});
                
                // 1. 현재 블록체인 높이 확인
                const current_height = blockchain_ref.getHeight();
                std.debug.print("📊 Current blockchain height: {}\n", .{current_height});
                
                // 2. 블록체인 무결성 검증
                if (!blockchain_ref.isChainValid()) {
                    std.debug.print("❌ Current blockchain is invalid, cannot add new block\n", .{});
                    return;
                }
                
                // 3. 간단한 블록 정보 파싱 (실제로는 더 복잡한 구조)
                // 예시: "BLOCK:index=2,timestamp=1234567890,txcount=3"
                var parts = std.mem.splitScalar(u8, block_data[6..], ','); // Skip "BLOCK:"
                var parsed_index: ?u64 = null;
                var parsed_timestamp: ?i64 = null;
                var tx_count: u32 = 0;
                
                while (parts.next()) |part| {
                    if (std.mem.startsWith(u8, part, "index=")) {
                        parsed_index = std.fmt.parseUnsigned(u64, part[6..], 10) catch null;
                    } else if (std.mem.startsWith(u8, part, "timestamp=")) {
                        parsed_timestamp = std.fmt.parseInt(i64, part[10..], 10) catch null;
                    } else if (std.mem.startsWith(u8, part, "txcount=")) {
                        tx_count = std.fmt.parseUnsigned(u32, part[8..], 10) catch 0;
                    }
                }
                
                // 4. 블록 인덱스 검증 (연속성 확인)
                if (parsed_index) |block_index| {
                    if (block_index != current_height) {
                        std.debug.print("❌ Block index mismatch: expected {}, got {}\n", .{ current_height, block_index });
                        return;
                    }
                } else {
                    std.debug.print("❌ Invalid block: could not parse index\n", .{});
                    return;
                }
                
                // 5. 타임스탬프 검증 (최신 블록보다 나중)
                if (parsed_timestamp) |timestamp| {
                    const latest_block = blockchain_ref.getLatestBlock();
                    if (timestamp <= latest_block.timestamp) {
                        std.debug.print("❌ Block timestamp is not newer than latest block\n", .{});
                        return;
                    }
                } else {
                    std.debug.print("❌ Invalid block: could not parse timestamp\n", .{});
                    return;
                }
                
                // 6. 받은 블록 정보로 새 블록 생성 (시뮬레이션)
                // 실제로는 전체 블록 데이터를 역직렬화해야 함
                std.debug.print("✅ Block validation passed\n", .{});
                std.debug.print("📊 Block info: index={}, timestamp={}, transactions={}\n", .{ parsed_index.?, parsed_timestamp.?, tx_count });
                
                // 7. 트랜잭션이 있으면 pending pool에 추가 (시뮬레이션)
                if (tx_count > 0) {
                    var i: u32 = 0;
                    while (i < tx_count and i < 3) : (i += 1) { // 최대 3개까지만
                        const mock_tx = blockchain.Transaction{
                            .from = "peer_node",
                            .to = "network_user",
                            .amount = 10 + i * 5,
                            .timestamp = parsed_timestamp.?,
                        };
                        
                        blockchain_ref.addTransaction(mock_tx) catch |err| {
                            std.debug.print("❌ Failed to add transaction {}: {}\n", .{ i, err });
                            continue;
                        };
                    }
                    
                    std.debug.print("✅ Added {} transactions from received block\n", .{tx_count});
                }
                
                // 8. 블록 체인에 실제로 추가하지는 않음 (마이닝 필요)
                // 대신 pending transactions으로 처리
                std.debug.print("📋 Block data processed, {} pending transactions\n", .{blockchain_ref.pending_transactions.items.len});
                
            } else {
                std.debug.print("❌ Invalid block format: does not start with 'BLOCK:'\n", .{});
            }
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
        if (message.payload.len > 0) {
            // 트랜잭션 데이터를 문자열로 파싱 (간단한 형태로 시뮬레이션)
            const tx_data = std.mem.trim(u8, message.payload, " \t\n\r");
            
            // 트랜잭션 데이터 검증 (간단한 형태)
            if (std.mem.startsWith(u8, tx_data, "TX:")) {
                std.debug.print("🔍 Validating received transaction...\n", .{});
                
                // 1. 트랜잭션 형식 파싱
                // 예시: "TX:from=alice,to=bob,amount=50,timestamp=1234567890"
                var parts = std.mem.splitScalar(u8, tx_data[3..], ','); // Skip "TX:"
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
                
                // 2. 필수 필드 검증
                if (from == null or to == null or amount == null or timestamp == null) {
                    std.debug.print("❌ Invalid transaction: missing required fields\n", .{});
                    return;
                }
                
                // 3. 기본 검증
                if (amount.? == 0) {
                    std.debug.print("❌ Invalid transaction: amount cannot be zero\n", .{});
                    return;
                }
                
                if (std.mem.eql(u8, from.?, to.?)) {
                    std.debug.print("❌ Invalid transaction: sender and recipient cannot be the same\n", .{});
                    return;
                }
                
                // 4. 타임스탬프 검증 (너무 오래된 트랜잭션 거부)
                const current_time = std.time.timestamp();
                const max_age = 3600; // 1시간
                if (current_time - timestamp.? > max_age) {
                    std.debug.print("❌ Invalid transaction: too old (age: {} seconds)\n", .{current_time - timestamp.?});
                    return;
                }
                
                // 5. 미래 트랜잭션 거부
                if (timestamp.? > current_time + 300) { // 5분 여유
                    std.debug.print("❌ Invalid transaction: timestamp too far in the future\n", .{});
                    return;
                }
                
                // 6. 이중 지출 검사 (간단한 형태)
                // 실제로는 UTXO 모델이나 계정 기반 모델에 따라 다름
                for (blockchain_ref.pending_transactions.items) |existing_tx| {
                    if (std.mem.eql(u8, existing_tx.from, from.?) and 
                        existing_tx.timestamp == timestamp.? and 
                        existing_tx.amount == amount.?) {
                        std.debug.print("❌ Invalid transaction: potential duplicate transaction\n", .{});
                        return;
                    }
                }
                
                // 7. 유효한 트랜잭션 생성
                const validated_tx = blockchain.Transaction{
                    .from = from.?,
                    .to = to.?,
                    .amount = amount.?,
                    .timestamp = timestamp.?,
                };
                
                // 8. 트랜잭션을 pending pool에 추가
                blockchain_ref.addTransaction(validated_tx) catch |err| {
                    std.debug.print("❌ Failed to add transaction to pool: {}\n", .{err});
                    return;
                };
                
                std.debug.print("✅ Transaction validated and added to pending pool\n", .{});
                std.debug.print("📊 Transaction details: {s} -> {s}, amount: {}, timestamp: {}\n", .{ from.?, to.?, amount.?, timestamp.? });
                std.debug.print("📋 Pending transactions: {}\n", .{blockchain_ref.pending_transactions.items.len});
                
                // 9. 트랜잭션 풀이 일정 수준에 도달하면 다른 피어들에게 알림
                const min_tx_for_broadcast = 3;
                if (blockchain_ref.pending_transactions.items.len >= min_tx_for_broadcast) {
                    std.debug.print("📡 Sufficient transactions accumulated, ready for mining/broadcasting\n", .{});
                    
                    // 실제 구현에서는 블록 마이닝을 시작하거나 다른 피어들에게 트랜잭션 집합을 브로드캐스트할 수 있음
                    if (blockchain_ref.hasPendingTransactions()) {
                        std.debug.print("🔨 Mining could be triggered with {} pending transactions\n", .{blockchain_ref.pending_transactions.items.len});
                    }
                }
                
            } else {
                std.debug.print("❌ Invalid transaction format: does not start with 'TX:'\n", .{});
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