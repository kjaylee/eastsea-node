const std = @import("std");
const net = std.net;
const crypto = @import("../crypto/hash.zig");
const blockchain = @import("../blockchain/blockchain.zig");

/// Error types for QUIC operations
pub const QuicError = error{
    ConnectionFailed,
    InvalidMessage,
    PeerNotFound,
    NetworkError,
    StreamError,
    SecurityError,
};

/// QUIC message header structure
pub const QuicMessageHeader = struct {
    magic: u32 = 0x51554943, // "QUIC" in hex
    version: u16 = 1,
    msg_type: u8,
    payload_size: u32,
    checksum: u32,

    pub fn serialize(self: *const QuicMessageHeader, buffer: []u8) !void {
        if (buffer.len < @sizeOf(QuicMessageHeader)) return error.BufferTooSmall;
        
        std.mem.writeInt(u32, buffer[0..4], self.magic, .little);
        std.mem.writeInt(u16, buffer[4..6], self.version, .little);
        buffer[6] = self.msg_type;
        std.mem.writeInt(u32, buffer[7..11], self.payload_size, .little);
        std.mem.writeInt(u32, buffer[11..15], self.checksum, .little);
    }

    pub fn deserialize(buffer: []const u8) !QuicMessageHeader {
        if (buffer.len < @sizeOf(QuicMessageHeader)) return error.BufferTooSmall;
        
        return QuicMessageHeader{
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

/// QUIC message structure
pub const QuicMessage = struct {
    header: QuicMessageHeader,
    payload: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, msg_type: u8, payload: []const u8) !QuicMessage {
        const payload_copy = try allocator.dupe(u8, payload);
        const checksum = QuicMessageHeader.calculateChecksum(payload);
        
        return QuicMessage{
            .header = QuicMessageHeader{
                .msg_type = msg_type,
                .payload_size = @intCast(payload.len),
                .checksum = checksum,
            },
            .payload = payload_copy,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *QuicMessage) void {
        self.allocator.free(self.payload);
    }

    pub fn serialize(self: *const QuicMessage, buffer: []u8) !usize {
        const total_size = @sizeOf(QuicMessageHeader) + self.payload.len;
        if (buffer.len < total_size) return error.BufferTooSmall;

        try self.header.serialize(buffer[0..@sizeOf(QuicMessageHeader)]);
        @memcpy(buffer[@sizeOf(QuicMessageHeader)..total_size], self.payload);
        
        return total_size;
    }

    pub fn deserialize(allocator: std.mem.Allocator, buffer: []const u8) !QuicMessage {
        if (buffer.len < @sizeOf(QuicMessageHeader)) return error.BufferTooSmall;
        
        const header = try QuicMessageHeader.deserialize(buffer[0..@sizeOf(QuicMessageHeader)]);
        
        if (header.magic != 0x51554943) return error.InvalidMessage;
        if (buffer.len < @sizeOf(QuicMessageHeader) + header.payload_size) return error.BufferTooSmall;
        
        const payload_start = @sizeOf(QuicMessageHeader);
        const payload_end = payload_start + header.payload_size;
        const payload = buffer[payload_start..payload_end];
        
        // Verify checksum
        const calculated_checksum = QuicMessageHeader.calculateChecksum(payload);
        if (calculated_checksum != header.checksum) return error.InvalidMessage;
        
        const payload_copy = try allocator.dupe(u8, payload);
        
        return QuicMessage{
            .header = header,
            .payload = payload_copy,
            .allocator = allocator,
        };
    }
};

/// QUIC stream structure
pub const QuicStream = struct {
    id: u64,
    is_bidirectional: bool,
    send_window: u64,
    recv_window: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, id: u64, is_bidirectional: bool) QuicStream {
        return QuicStream{
            .id = id,
            .is_bidirectional = is_bidirectional,
            .send_window = 1024 * 1024, // 1MB initial window
            .recv_window = 1024 * 1024, // 1MB initial window
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *QuicStream) void {
        _ = self;
        // Cleanup stream resources
    }

    pub fn send(self: *QuicStream, data: []const u8) !void {
        _ = self;
        // In a real implementation, this would send data over the QUIC stream
        std.debug.print("📡 Sending {} bytes over QUIC stream\n", .{data.len});
    }

    pub fn receive(self: *QuicStream, buffer: []u8) !usize {
        _ = self;
        _ = buffer;
        // In a real implementation, this would receive data from the QUIC stream
        std.debug.print("📥 Receiving data from QUIC stream\n", .{});
        return 0; // Return number of bytes received
    }
};

/// QUIC connection structure
pub const QuicConnection = struct {
    stream: net.Stream,
    address: net.Address,
    port: u16,
    id: [32]u8,
    connected: bool,
    last_activity: i64,
    streams: std.ArrayList(QuicStream),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, stream: net.Stream, address: net.Address) QuicConnection {
        var id: [32]u8 = undefined;
        std.crypto.random.bytes(&id);
        
        const port = switch (address.any.family) {
            std.posix.AF.INET => address.in.getPort(),
            std.posix.AF.INET6 => address.in6.getPort(),
            else => 0,
        };
        
        return QuicConnection{
            .stream = stream,
            .address = address,
            .port = port,
            .id = id,
            .connected = true,
            .last_activity = std.time.timestamp(),
            .streams = std.ArrayList(QuicStream).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *QuicConnection) void {
        for (self.streams.items) |*stream| {
            stream.deinit();
        }
        self.streams.deinit();
        
        if (self.connected) {
            self.stream.close();
            self.connected = false;
        }
    }

    pub fn sendMessage(self: *QuicConnection, message: *const QuicMessage) !void {
        if (!self.connected) return QuicError.ConnectionFailed;

        var buffer: [4096]u8 = undefined;
        const size = try message.serialize(&buffer);
        
        _ = try self.stream.writeAll(buffer[0..size]);
    }

    pub fn receiveMessage(self: *QuicConnection) !QuicMessage {
        if (!self.connected) return QuicError.ConnectionFailed;

        var header_buffer: [@sizeOf(QuicMessageHeader)]u8 = undefined;
        _ = try self.stream.readAll(&header_buffer);
        
        const header = try QuicMessageHeader.deserialize(&header_buffer);
        
        if (header.payload_size > 4096) return QuicError.InvalidMessage;
        
        const payload_buffer = try self.allocator.alloc(u8, header.payload_size);
        defer self.allocator.free(payload_buffer);
        
        _ = try self.stream.readAll(payload_buffer);
        
        var full_buffer = try self.allocator.alloc(u8, @sizeOf(QuicMessageHeader) + header.payload_size);
        defer self.allocator.free(full_buffer);
        
        @memcpy(full_buffer[0..@sizeOf(QuicMessageHeader)], &header_buffer);
        @memcpy(full_buffer[@sizeOf(QuicMessageHeader)..], payload_buffer);
        
        return try QuicMessage.deserialize(self.allocator, full_buffer);
    }

    pub fn createStream(self: *QuicConnection, is_bidirectional: bool) !*QuicStream {
        const stream_id = self.streams.items.len;
        const stream = QuicStream.init(self.allocator, stream_id, is_bidirectional);
        try self.streams.append(stream);
        return &self.streams.items[self.streams.items.len - 1];
    }

    pub fn getStream(self: *QuicConnection, stream_id: u64) ?*QuicStream {
        if (stream_id >= self.streams.items.len) return null;
        return &self.streams.items[stream_id];
    }

    pub fn isAlive(self: *const QuicConnection) bool {
        const current_time = std.time.timestamp();
        return self.connected and (current_time - self.last_activity) < 60; // 60 seconds timeout
    }
};

/// QUIC node structure
pub const QuicNode = struct {
    allocator: std.mem.Allocator,
    address: net.Address,
    server: ?net.Server,
    connections: std.ArrayList(*QuicConnection),
    node_id: [32]u8,
    running: bool,
    message_handlers: std.HashMap(u8, *const fn(*QuicNode, *QuicConnection, *const QuicMessage) anyerror!void, std.hash_map.AutoContext(u8), 80),
    blockchain_ref: ?*blockchain.Blockchain,
    user_data: ?*anyopaque,

    pub fn init(allocator: std.mem.Allocator, port: u16) !QuicNode {
        var node_id: [32]u8 = undefined;
        std.crypto.random.bytes(&node_id);
        
        const address = try net.Address.parseIp4("127.0.0.1", port);
        
        return QuicNode{
            .allocator = allocator,
            .address = address,
            .server = null,
            .connections = std.ArrayList(*QuicConnection).init(allocator),
            .node_id = node_id,
            .running = false,
            .message_handlers = std.HashMap(u8, *const fn(*QuicNode, *QuicConnection, *const QuicMessage) anyerror!void, std.hash_map.AutoContext(u8), 80).init(allocator),
            .blockchain_ref = null,
            .user_data = null,
        };
    }

    pub fn deinit(self: *QuicNode) void {
        self.stop();
        
        for (self.connections.items) |connection| {
            connection.deinit();
            self.allocator.destroy(connection);
        }
        self.connections.deinit();
        self.message_handlers.deinit();
    }
    
    pub fn setBlockchain(self: *QuicNode, blockchain_ref: *blockchain.Blockchain) void {
        self.blockchain_ref = blockchain_ref;
    }

    pub fn start(self: *QuicNode) !void {
        // Try to bind to the address, with retry logic for port conflicts
        self.server = self.address.listen(.{}) catch |err| switch (err) {
            error.AddressInUse => {
                std.debug.print("⚠️  Port {} in use, trying to find available port...\n", .{self.address.getPort()});
                return self.findAndBindAvailablePort();
            },
            else => return err,
        };
        self.running = true;
        
        std.debug.print("🌐 QUIC Node started on {}\n", .{self.address});
        std.debug.print("🆔 Node ID: {}\n", .{std.fmt.fmtSliceHexLower(&self.node_id)});
    }
    
    fn findAndBindAvailablePort(self: *QuicNode) !void {
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

    pub fn stop(self: *QuicNode) void {
        if (self.server) |*server| {
            server.deinit();
            self.server = null;
        }
        self.running = false;
        std.debug.print("🛑 QUIC Node stopped\n", .{});
    }

    pub fn connectToPeer(self: *QuicNode, peer_address: net.Address) !*QuicConnection {
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
        
        const connection = try self.allocator.create(QuicConnection);
        connection.* = QuicConnection.init(self.allocator, stream, peer_address);
        
        try self.connections.append(connection);
        
        std.debug.print("🤝 Connected to peer: {}\n", .{peer_address});
        
        return connection;
    }

    pub fn acceptConnections(self: *QuicNode) !void {
        if (self.server == null) return QuicError.NetworkError;
        
        while (self.running) {
            if (self.server.?.accept()) |connection| {
                const quic_connection = try self.allocator.create(QuicConnection);
                quic_connection.* = QuicConnection.init(self.allocator, connection.stream, connection.address);
                
                try self.connections.append(quic_connection);
                
                std.debug.print("📥 Accepted connection from: {}\n", .{connection.address});
                
                // Handle connection in separate thread (simplified for demo)
                try self.handleConnection(quic_connection);
            } else |err| {
                if (err == error.WouldBlock) {
                    std.time.sleep(1000000); // 1ms
                    continue;
                }
                return err;
            }
        }
    }

    pub fn handleConnection(self: *QuicNode, connection: *QuicConnection) !void {
        while (connection.connected and self.running) {
            if (connection.receiveMessage()) |message| {
                var mut_message = message;
                defer mut_message.deinit();
                try self.processMessage(connection, &mut_message);
            } else |err| {
                if (err == error.WouldBlock) {
                    std.time.sleep(1000000); // 1ms
                    continue;
                }
                std.debug.print("❌ Error receiving message from connection: {}\n", .{err});
                break;
            }
        }
        
        self.removeConnection(connection);
    }

    pub fn processMessage(self: *QuicNode, connection: *QuicConnection, message: *const QuicMessage) !void {
        if (self.message_handlers.get(message.header.msg_type)) |handler| {
            try handler(self, connection, message);
        } else {
            std.debug.print("⚠️  Unknown message type: {}\n", .{message.header.msg_type});
        }
    }

    pub fn registerMessageHandler(self: *QuicNode, msg_type: u8, handler: *const fn(*QuicNode, *QuicConnection, *const QuicMessage) anyerror!void) !void {
        try self.message_handlers.put(msg_type, handler);
    }

    pub fn broadcastMessage(self: *QuicNode, message: *const QuicMessage) !void {
        std.debug.print("📡 Broadcasting message type {} to {} connections\n", .{ message.header.msg_type, self.connections.items.len });
        
        for (self.connections.items) |connection| {
            if (connection.connected) {
                connection.sendMessage(message) catch |err| {
                    std.debug.print("❌ Failed to send message to connection: {}\n", .{err});
                };
            }
        }
    }

    pub fn removeConnection(self: *QuicNode, connection_to_remove: *QuicConnection) void {
        for (self.connections.items, 0..) |connection, i| {
            if (connection == connection_to_remove) {
                _ = self.connections.swapRemove(i);
                connection.deinit();
                self.allocator.destroy(connection);
                std.debug.print("❌ Removed connection\n", .{});
                break;
            }
        }
    }

    pub fn getConnectionCount(self: *const QuicNode) usize {
        return self.connections.items.len;
    }
};

// Message handlers for different message types
fn handlePingMessage(node: *QuicNode, connection: *QuicConnection, message: *const QuicMessage) !void {
    _ = message;
    std.debug.print("🏓 Received ping from connection\n", .{});
    
    var pong_msg = try QuicMessage.init(node.allocator, 1, "pong");
    defer pong_msg.deinit();
    
    try connection.sendMessage(&pong_msg);
}

fn handlePongMessage(node: *QuicNode, connection: *QuicConnection, message: *const QuicMessage) !void {
    _ = node;
    _ = message;
    std.debug.print("🏓 Received pong from connection\n", .{});
    connection.last_activity = std.time.timestamp();
}

fn handleBlockMessage(node: *QuicNode, connection: *QuicConnection, message: *const QuicMessage) !void {
    _ = connection;
    std.debug.print("📦 Received block: {} bytes\n", .{message.payload.len});
    
    if (node.blockchain_ref) |blockchain_ref| {
        if (message.payload.len > 0) {
            // Block data parsing and validation (simplified simulation)
            const block_data = std.mem.trim(u8, message.payload, " \t\n\r");
            
            if (std.mem.startsWith(u8, block_data, "BLOCK:")) {
                std.debug.print("🔍 Validating received block...\n", .{});
                
                // Parse block info (simplified)
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
                
                // Validate block index (continuity check)
                if (parsed_index) |block_index| {
                    const current_height = blockchain_ref.getHeight();
                    if (block_index != current_height) {
                        std.debug.print("❌ Block index mismatch: expected {}, got {}\n", .{ current_height, block_index });
                        return;
                    }
                } else {
                    std.debug.print("❌ Invalid block: could not parse index\n", .{});
                    return;
                }
                
                // Validate timestamp (newer than latest block)
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
                
                // Create new block from received data (simulation)
                std.debug.print("✅ Block validation passed\n", .{});
                std.debug.print("📊 Block info: index={}, timestamp={}, transactions={}\n", .{ parsed_index.?, parsed_timestamp.?, tx_count });
                
                // Add transactions to pending pool if any
                if (tx_count > 0) {
                    var i: u32 = 0;
                    while (i < tx_count and i < 3) : (i += 1) { // Max 3 for demo
                        const mock_tx = blockchain.Transaction{
                            .from = "quic_peer",
                            .to = "local_node",
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
                
                std.debug.print("📋 Block data processed, {} pending transactions\n", .{blockchain_ref.pending_transactions.items.len});
            } else {
                std.debug.print("❌ Invalid block format: does not start with 'BLOCK:'\n", .{});
            }
        } else {
            std.debug.print("❌ Invalid block: empty payload\n", .{});
        }
    } else {
        std.debug.print("❌ No blockchain reference set for QUIC node\n", .{});
    }
}

fn handleTransactionMessage(node: *QuicNode, connection: *QuicConnection, message: *const QuicMessage) !void {
    _ = connection;
    std.debug.print("💸 Received transaction: {} bytes\n", .{message.payload.len});
    
    if (node.blockchain_ref) |blockchain_ref| {
        if (message.payload.len > 0) {
            // Transaction data parsing (simplified simulation)
            const tx_data = std.mem.trim(u8, message.payload, " \t\n\r");
            
            if (std.mem.startsWith(u8, tx_data, "TX:")) {
                std.debug.print("🔍 Validating received transaction...\n", .{});
                
                // Parse transaction format
                // Example: "TX:from=alice,to=bob,amount=50,timestamp=1234567890"
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
                
                // Validate required fields
                if (from == null or to == null or amount == null or timestamp == null) {
                    std.debug.print("❌ Invalid transaction: missing required fields\n", .{});
                    return;
                }
                
                // Basic validation
                if (amount.? == 0) {
                    std.debug.print("❌ Invalid transaction: amount cannot be zero\n", .{});
                    return;
                }
                
                if (std.mem.eql(u8, from.?, to.?)) {
                    std.debug.print("❌ Invalid transaction: sender and recipient cannot be the same\n", .{});
                    return;
                }
                
                // Validate timestamp (reject too old transactions)
                const current_time = std.time.timestamp();
                const max_age = 3600; // 1 hour
                if (current_time - timestamp.? > max_age) {
                    std.debug.print("❌ Invalid transaction: too old (age: {} seconds)\n", .{current_time - timestamp.?});
                    return;
                }
                
                // Reject future transactions
                if (timestamp.? > current_time + 300) { // 5 minutes buffer
                    std.debug.print("❌ Invalid transaction: timestamp too far in the future\n", .{});
                    return;
                }
                
                // Duplicate transaction check (simple form)
                for (blockchain_ref.pending_transactions.items) |existing_tx| {
                    if (std.mem.eql(u8, existing_tx.from, from.?) and 
                        existing_tx.timestamp == timestamp.? and 
                        existing_tx.amount == amount.?) {
                        std.debug.print("❌ Invalid transaction: potential duplicate transaction\n", .{});
                        return;
                    }
                }
                
                // Create validated transaction
                const validated_tx = blockchain.Transaction{
                    .from = from.?,
                    .to = to.?,
                    .amount = amount.?,
                    .timestamp = timestamp.?,
                };
                
                // Add transaction to pending pool
                blockchain_ref.addTransaction(validated_tx) catch |err| {
                    std.debug.print("❌ Failed to add transaction to pool: {}\n", .{err});
                    return;
                };
                
                std.debug.print("✅ Transaction validated and added to pending pool\n", .{});
                std.debug.print("📊 Transaction details: {} -> {}, amount: {}, timestamp: {}\n", .{ from.?, to.?, amount.?, timestamp.? });
                std.debug.print("📋 Pending transactions: {}\n", .{blockchain_ref.pending_transactions.items.len});
                
                // Trigger mining if sufficient transactions accumulated
                const min_tx_for_broadcast = 3;
                if (blockchain_ref.pending_transactions.items.len >= min_tx_for_broadcast) {
                    std.debug.print("📡 Sufficient transactions accumulated, ready for mining/broadcasting\n", .{});
                    
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
        std.debug.print("❌ No blockchain reference set for QUIC node\n", .{});
    }
}

test "QUIC message serialization" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var original_msg = try QuicMessage.init(allocator, 0, "test payload");
    defer original_msg.deinit();
    
    var buffer: [1024]u8 = undefined;
    const size = try original_msg.serialize(&buffer);
    
    const deserialized_msg = try QuicMessage.deserialize(allocator, buffer[0..size]);
    defer deserialized_msg.deinit();
    
    try testing.expect(deserialized_msg.header.msg_type == 0);
    try testing.expect(std.mem.eql(u8, deserialized_msg.payload, "test payload"));
}

test "QUIC node creation" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var node = try QuicNode.init(allocator, 8000);
    defer node.deinit();
    
    try testing.expect(node.getConnectionCount() == 0);
    try testing.expect(!node.running);
}
