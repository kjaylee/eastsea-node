const std = @import("std");
const net = std.net;
const print = std.debug.print;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const Allocator = std.mem.Allocator;

/// 피어 정보 구조체
pub const PeerInfo = struct {
    address: net.Address,
    port: u16,
    node_id: [32]u8,
    last_seen: i64,
    
    pub fn init(address: net.Address, port: u16, node_id: [32]u8) PeerInfo {
        return PeerInfo{
            .address = address,
            .port = port,
            .node_id = node_id,
            .last_seen = std.time.timestamp(),
        };
    }
    
    pub fn isExpired(self: *const PeerInfo, timeout_seconds: i64) bool {
        const now = std.time.timestamp();
        return (now - self.last_seen) > timeout_seconds;
    }
    
    pub fn updateLastSeen(self: *PeerInfo) void {
        self.last_seen = std.time.timestamp();
    }
};

/// Tracker 서버 메시지 타입
pub const TrackerMessageType = enum(u8) {
    ANNOUNCE = 1,      // 피어가 자신을 등록
    GET_PEERS = 2,     // 피어 목록 요청
    PEER_LIST = 3,     // 피어 목록 응답
    HEARTBEAT = 4,     // 생존 신호
    ERROR = 255,       // 오류 메시지
};

/// Tracker 메시지 구조체
pub const TrackerMessage = struct {
    message_type: TrackerMessageType,
    node_id: [32]u8,
    port: u16,
    peer_count: u16,
    peers: []PeerInfo,
    
    pub fn init(allocator: Allocator, message_type: TrackerMessageType, node_id: [32]u8, port: u16) !TrackerMessage {
        return TrackerMessage{
            .message_type = message_type,
            .node_id = node_id,
            .port = port,
            .peer_count = 0,
            .peers = try allocator.alloc(PeerInfo, 0),
        };
    }
    
    pub fn deinit(self: *TrackerMessage, allocator: Allocator) void {
        allocator.free(self.peers);
    }
    
    /// 메시지를 바이너리로 직렬화
    pub fn serialize(self: *const TrackerMessage, allocator: Allocator) ![]u8 {
        var buffer = ArrayList(u8).init(allocator);
        defer buffer.deinit();
        
        // 메시지 타입 (1바이트)
        try buffer.append(@intFromEnum(self.message_type));
        
        // 노드 ID (32바이트)
        try buffer.appendSlice(&self.node_id);
        
        // 포트 (2바이트)
        const port_bytes = std.mem.toBytes(self.port);
        try buffer.appendSlice(&port_bytes);
        
        // 피어 개수 (2바이트)
        const peer_count_bytes = std.mem.toBytes(self.peer_count);
        try buffer.appendSlice(&peer_count_bytes);
        
        // 피어 목록
        for (self.peers) |peer| {
            // IP 주소 (4바이트 for IPv4)
            const addr_bytes = switch (peer.address.any.family) {
                std.posix.AF.INET => blk: {
                    const ipv4 = peer.address.in;
                    break :blk std.mem.toBytes(ipv4.sa.addr);
                },
                else => [_]u8{0, 0, 0, 0}, // 기본값
            };
            try buffer.appendSlice(&addr_bytes);
            
            // 포트 (2바이트)
            const peer_port_bytes = std.mem.toBytes(peer.port);
            try buffer.appendSlice(&peer_port_bytes);
            
            // 노드 ID (32바이트)
            try buffer.appendSlice(&peer.node_id);
            
            // 마지막 접속 시간 (8바이트)
            const last_seen_bytes = std.mem.toBytes(peer.last_seen);
            try buffer.appendSlice(&last_seen_bytes);
        }
        
        return buffer.toOwnedSlice();
    }
    
    /// 바이너리에서 메시지 역직렬화
    pub fn deserialize(allocator: Allocator, data: []const u8) !TrackerMessage {
        if (data.len < 35) return error.InvalidMessageSize; // 최소 크기
        
        var offset: usize = 0;
        
        const message_type = @as(TrackerMessageType, @enumFromInt(data[offset]));
        offset += 1;
        
        // 노드 ID
        var node_id: [32]u8 = undefined;
        @memcpy(&node_id, data[offset..offset + 32]);
        offset += 32;
        
        // 포트
        const port = std.mem.bytesToValue(u16, data[offset..offset + 2]);
        offset += 2;
        
        // 피어 개수
        const peer_count = std.mem.bytesToValue(u16, data[offset..offset + 2]);
        offset += 2;
        
        // 피어 목록 파싱
        var peers = try allocator.alloc(PeerInfo, peer_count);
        for (0..peer_count) |i| {
            if (offset + 46 > data.len) return error.InvalidMessageSize; // 피어 데이터 크기
            
            // IP 주소 (IPv4)
            const addr_bytes = data[offset..offset + 4];
            const ipv4_addr = std.mem.bytesToValue(u32, addr_bytes);
            const address = net.Address.initIp4(
                @as([4]u8, @bitCast(ipv4_addr)),
                std.mem.bytesToValue(u16, data[offset + 4..offset + 6])
            );
            offset += 6;
            
            // 노드 ID
            var peer_node_id: [32]u8 = undefined;
            @memcpy(&peer_node_id, data[offset..offset + 32]);
            offset += 32;
            
            // 마지막 접속 시간
            const last_seen = std.mem.bytesToValue(i64, data[offset..offset + 8]);
            offset += 8;
            
            peers[i] = PeerInfo{
                .address = address,
                .port = address.getPort(),
                .node_id = peer_node_id,
                .last_seen = last_seen,
            };
        }
        
        return TrackerMessage{
            .message_type = message_type,
            .node_id = node_id,
            .port = port,
            .peer_count = peer_count,
            .peers = peers,
        };
    }
};

/// Tracker 서버 구현
pub const TrackerServer = struct {
    allocator: Allocator,
    socket: net.Server,
    peers: HashMap([32]u8, PeerInfo, std.hash_map.AutoContext([32]u8), std.hash_map.default_max_load_percentage),
    running: bool,
    port: u16,
    max_peers: usize,
    peer_timeout: i64, // 초 단위
    
    pub fn init(allocator: Allocator, port: u16) !TrackerServer {
        const address = net.Address.parseIp4("0.0.0.0", port) catch unreachable;
        const socket = try address.listen(.{
            .reuse_address = true,
            .reuse_port = true,
        });
        
        return TrackerServer{
            .allocator = allocator,
            .socket = socket,
            .peers = HashMap([32]u8, PeerInfo, std.hash_map.AutoContext([32]u8), std.hash_map.default_max_load_percentage).init(allocator),
            .running = false,
            .port = port,
            .max_peers = 1000, // 최대 1000개 피어
            .peer_timeout = 300, // 5분 타임아웃
        };
    }
    
    pub fn deinit(self: *TrackerServer) void {
        self.stop();
        self.peers.deinit();
        self.socket.deinit();
    }
    
    /// 서버 시작
    pub fn start(self: *TrackerServer) !void {
        self.running = true;
        print("🚀 Tracker Server started on port {d}\n", .{self.port});
        print("📊 Max peers: {d}, Timeout: {d}s\n", .{self.max_peers, self.peer_timeout});
        
        while (self.running) {
            // 클라이언트 연결 수락
            const connection = self.socket.accept() catch |err| {
                if (err == error.WouldBlock) {
                    std.time.sleep(1000000); // 1ms 대기
                    continue;
                }
                print("❌ Accept error: {}\n", .{err});
                continue;
            };
            
            // 클라이언트 요청 처리
            self.handleClient(connection) catch |err| {
                print("❌ Client handling error: {}\n", .{err});
            };
            
            // 주기적으로 만료된 피어 정리
            self.cleanupExpiredPeers();
        }
    }
    
    /// 서버 중지
    pub fn stop(self: *TrackerServer) void {
        self.running = false;
        print("🛑 Tracker Server stopped\n", .{});
    }
    
    /// 클라이언트 요청 처리
    fn handleClient(self: *TrackerServer, connection: net.Server.Connection) !void {
        defer connection.stream.close();
        
        // 메시지 읽기
        var buffer: [4096]u8 = undefined;
        const bytes_read = try connection.stream.read(&buffer);
        
        if (bytes_read == 0) return;
        
        // 메시지 파싱
        var message = TrackerMessage.deserialize(self.allocator, buffer[0..bytes_read]) catch |err| {
            print("❌ Message parsing error: {}\n", .{err});
            return;
        };
        defer message.deinit(self.allocator);
        
        // 메시지 타입에 따른 처리
        switch (message.message_type) {
            .ANNOUNCE => try self.handleAnnounce(&message, connection),
            .GET_PEERS => try self.handleGetPeers(&message, connection),
            .HEARTBEAT => try self.handleHeartbeat(&message, connection),
            else => {
                print("❌ Unknown message type: {}\n", .{message.message_type});
            },
        }
    }
    
    /// ANNOUNCE 메시지 처리 (피어 등록)
    fn handleAnnounce(self: *TrackerServer, message: *const TrackerMessage, connection: net.Server.Connection) !void {
        const peer_info = PeerInfo.init(connection.address, message.port, message.node_id);
        
        // 피어 등록 또는 업데이트
        try self.peers.put(message.node_id, peer_info);
        
        print("📝 Peer announced: {}:{d} (Total: {d})\n", .{connection.address, message.port, self.peers.count()});
        
        // 성공 응답 전송
        var response = try TrackerMessage.init(self.allocator, .PEER_LIST, message.node_id, 0);
        defer response.deinit(self.allocator);
        
        const response_data = try response.serialize(self.allocator);
        defer self.allocator.free(response_data);
        
        _ = try connection.stream.write(response_data);
    }
    
    /// GET_PEERS 메시지 처리 (피어 목록 요청)
    fn handleGetPeers(self: *TrackerServer, message: *const TrackerMessage, connection: net.Server.Connection) !void {
        // 활성 피어 목록 수집
        var active_peers = ArrayList(PeerInfo).init(self.allocator);
        defer active_peers.deinit();
        
        var iterator = self.peers.iterator();
        while (iterator.next()) |entry| {
            const peer = entry.value_ptr;
            if (!peer.isExpired(self.peer_timeout)) {
                try active_peers.append(peer.*);
            }
        }
        
        // 응답 메시지 생성
        var response = try TrackerMessage.init(self.allocator, .PEER_LIST, message.node_id, 0);
        defer response.deinit(self.allocator);
        
        response.peer_count = @as(u16, @intCast(active_peers.items.len));
        response.peers = try self.allocator.dupe(PeerInfo, active_peers.items);
        
        print("📤 Sending {d} peers to {}\n", .{response.peer_count, connection.address});
        
        const response_data = try response.serialize(self.allocator);
        defer self.allocator.free(response_data);
        
        _ = try connection.stream.write(response_data);
    }
    
    /// HEARTBEAT 메시지 처리 (생존 신호)
    fn handleHeartbeat(self: *TrackerServer, message: *const TrackerMessage, connection: net.Server.Connection) !void {
        // 피어 정보 업데이트
        if (self.peers.getPtr(message.node_id)) |peer| {
            peer.updateLastSeen();
            print("💓 Heartbeat from {}\n", .{connection.address});
        }
        
        // 간단한 응답
        var response = try TrackerMessage.init(self.allocator, .HEARTBEAT, message.node_id, 0);
        defer response.deinit(self.allocator);
        
        const response_data = try response.serialize(self.allocator);
        defer self.allocator.free(response_data);
        
        _ = try connection.stream.write(response_data);
    }
    
    /// 만료된 피어 정리
    fn cleanupExpiredPeers(self: *TrackerServer) void {
        var expired_keys = ArrayList([32]u8).init(self.allocator);
        defer expired_keys.deinit();
        
        var iterator = self.peers.iterator();
        while (iterator.next()) |entry| {
            if (entry.value_ptr.isExpired(self.peer_timeout)) {
                expired_keys.append(entry.key_ptr.*) catch continue;
            }
        }
        
        for (expired_keys.items) |key| {
            _ = self.peers.remove(key);
            print("🗑️ Removed expired peer\n", .{});
        }
    }
    
    /// 서버 상태 출력
    pub fn printStatus(self: *const TrackerServer) void {
        print("\n📊 Tracker Server Status:\n", .{});
        print("  Port: {d}\n", .{self.port});
        print("  Active Peers: {d}/{d}\n", .{self.peers.count(), self.max_peers});
        print("  Running: {}\n", .{self.running});
        print("  Timeout: {d}s\n", .{self.peer_timeout});
    }
};

/// Tracker 클라이언트 구현
pub const TrackerClient = struct {
    allocator: Allocator,
    node_id: [32]u8,
    local_port: u16,
    
    pub fn init(allocator: Allocator, node_id: [32]u8, local_port: u16) TrackerClient {
        return TrackerClient{
            .allocator = allocator,
            .node_id = node_id,
            .local_port = local_port,
        };
    }
    
    /// Tracker 서버에 자신을 등록
    pub fn announce(self: *const TrackerClient, tracker_address: net.Address) !void {
        const socket = try net.tcpConnectToAddress(tracker_address);
        defer socket.close();
        
        var message = try TrackerMessage.init(self.allocator, .ANNOUNCE, self.node_id, self.local_port);
        defer message.deinit(self.allocator);
        
        const data = try message.serialize(self.allocator);
        defer self.allocator.free(data);
        
        _ = try socket.write(data);
        print("📢 Announced to tracker: {}\n", .{tracker_address});
        
        // 응답 읽기
        var buffer: [1024]u8 = undefined;
        const bytes_read = try socket.read(&buffer);
        if (bytes_read > 0) {
            print("✅ Tracker response received\n", .{});
        }
    }
    
    /// Tracker 서버에서 피어 목록 요청
    pub fn getPeers(self: *const TrackerClient, tracker_address: net.Address) ![]PeerInfo {
        const socket = try net.tcpConnectToAddress(tracker_address);
        defer socket.close();
        
        var message = try TrackerMessage.init(self.allocator, .GET_PEERS, self.node_id, self.local_port);
        defer message.deinit(self.allocator);
        
        const data = try message.serialize(self.allocator);
        defer self.allocator.free(data);
        
        _ = try socket.write(data);
        
        // 응답 읽기
        var buffer: [4096]u8 = undefined;
        const bytes_read = try socket.read(&buffer);
        
        if (bytes_read == 0) return error.NoResponse;
        
        const response = try TrackerMessage.deserialize(self.allocator, buffer[0..bytes_read]);
        // response.deinit은 호출자가 담당
        
        print("📥 Received {d} peers from tracker\n", .{response.peer_count});
        return response.peers;
    }
    
    /// Tracker 서버에 생존 신호 전송
    pub fn sendHeartbeat(self: *const TrackerClient, tracker_address: net.Address) !void {
        const socket = try net.tcpConnectToAddress(tracker_address);
        defer socket.close();
        
        var message = try TrackerMessage.init(self.allocator, .HEARTBEAT, self.node_id, self.local_port);
        defer message.deinit(self.allocator);
        
        const data = try message.serialize(self.allocator);
        defer self.allocator.free(data);
        
        _ = try socket.write(data);
        
        // 응답 읽기
        var buffer: [1024]u8 = undefined;
        const bytes_read = try socket.read(&buffer);
        if (bytes_read > 0) {
            print("💓 Heartbeat acknowledged\n", .{});
        }
    }
};

// 테스트 함수들
test "TrackerMessage serialization" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var node_id: [32]u8 = undefined;
    std.crypto.random.bytes(&node_id);
    
    var message = try TrackerMessage.init(allocator, .ANNOUNCE, node_id, 8080);
    defer message.deinit(allocator);
    
    const serialized = try message.serialize(allocator);
    defer allocator.free(serialized);
    
    var deserialized = try TrackerMessage.deserialize(allocator, serialized);
    defer deserialized.deinit(allocator);
    
    try testing.expect(deserialized.message_type == .ANNOUNCE);
    try testing.expect(deserialized.port == 8080);
    try testing.expect(std.mem.eql(u8, &deserialized.node_id, &node_id));
}

test "PeerInfo expiration" {
    const testing = std.testing;
    
    var node_id: [32]u8 = undefined;
    std.crypto.random.bytes(&node_id);
    
    const address = net.Address.parseIp4("127.0.0.1", 8080) catch unreachable;
    var peer = PeerInfo.init(address, 8080, node_id);
    
    // 새로 생성된 피어는 만료되지 않음
    try testing.expect(!peer.isExpired(300));
    
    // 과거 시간으로 설정
    peer.last_seen = std.time.timestamp() - 400;
    
    // 300초 타임아웃으로 만료됨
    try testing.expect(peer.isExpired(300));
}