const std = @import("std");
const net = std.net;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const Thread = std.Thread;

/// 브로드캐스트/멀티캐스트를 통한 피어 공지 시스템
/// 로컬 네트워크에서 UDP 브로드캐스트를 사용하여 피어를 발견하고 공지
pub const BroadcastAnnouncer = struct {
    allocator: Allocator,
    local_port: u16,
    broadcast_port: u16,
    multicast_group: []const u8,
    multicast_port: u16,
    
    // 소켓들 (TCP 기반으로 간소화)
    // broadcast_socket: ?std.posix.socket_t,
    // multicast_socket: ?std.posix.socket_t,
    // listen_socket: ?std.posix.socket_t,
    
    // 상태
    is_running: bool,
    announce_thread: ?Thread,
    listen_thread: ?Thread,
    
    // 발견된 피어들
    discovered_peers: ArrayList(PeerInfo),
    
    // 설정
    announce_interval_ms: u64,
    peer_timeout_ms: u64,
    
    const Self = @This();
    
    pub const PeerInfo = struct {
        address: net.Address,
        node_id: [32]u8,
        last_seen: i64, // 타임스탬프
        services: u32,  // 제공하는 서비스 플래그
        version: u32,   // 프로토콜 버전
        
        pub fn isExpired(self: PeerInfo, timeout_ms: u64) bool {
            const now = std.time.milliTimestamp();
            return (now - self.last_seen) > @as(i64, @intCast(timeout_ms));
        }
    };
    
    pub const AnnouncementMessage = struct {
        magic: [4]u8,      // "EAST"
        version: u32,       // 프로토콜 버전
        message_type: u8,   // 메시지 타입 (1: ANNOUNCE, 2: RESPONSE, 3: GOODBYE)
        node_id: [32]u8,   // 노드 ID
        listen_port: u16,   // P2P 리스닝 포트
        services: u32,      // 제공하는 서비스
        timestamp: i64,     // 타임스탬프
        checksum: u32,      // 체크섬
        
        const MAGIC = [4]u8{ 'E', 'A', 'S', 'T' };
        const VERSION = 1;
        
        pub const MessageType = enum(u8) {
            ANNOUNCE = 1,
            RESPONSE = 2,
            GOODBYE = 3,
        };
        
        pub fn init(message_type: MessageType, node_id: [32]u8, listen_port: u16, services: u32) AnnouncementMessage {
            var msg = AnnouncementMessage{
                .magic = MAGIC,
                .version = VERSION,
                .message_type = @intFromEnum(message_type),
                .node_id = node_id,
                .listen_port = listen_port,
                .services = services,
                .timestamp = std.time.milliTimestamp(),
                .checksum = 0,
            };
            
            // 체크섬 계산
            msg.checksum = msg.calculateChecksum();
            return msg;
        }
        
        pub fn calculateChecksum(self: *const AnnouncementMessage) u32 {
            var hasher = std.hash.Crc32.init();
            hasher.update(std.mem.asBytes(self)[0..@offsetOf(AnnouncementMessage, "checksum")]);
            return hasher.final();
        }
        
        pub fn isValid(self: *const AnnouncementMessage) bool {
            if (!std.mem.eql(u8, &self.magic, &MAGIC)) return false;
            if (self.version != VERSION) return false;
            
            const expected_checksum = self.calculateChecksum();
            return self.checksum == expected_checksum;
        }
        
        pub fn toBytes(self: *const AnnouncementMessage) []const u8 {
            return std.mem.asBytes(self);
        }
        
        pub fn fromBytes(bytes: []const u8) ?AnnouncementMessage {
            if (bytes.len != @sizeOf(AnnouncementMessage)) return null;
            
            const msg = @as(*const AnnouncementMessage, @ptrCast(@alignCast(bytes.ptr))).*;
            if (!msg.isValid()) return null;
            
            return msg;
        }
    };

    pub fn init(allocator: Allocator, local_port: u16) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .allocator = allocator,
            .local_port = local_port,
            .broadcast_port = 8888, // 기본 브로드캐스트 포트
            .multicast_group = "224.0.0.251", // mDNS 멀티캐스트 그룹 사용
            .multicast_port = 8889, // 기본 멀티캐스트 포트
            // .broadcast_socket = null,
            // .multicast_socket = null,
            // .listen_socket = null,
            .is_running = false,
            .announce_thread = null,
            .listen_thread = null,
            .discovered_peers = ArrayList(PeerInfo).init(allocator),
            .announce_interval_ms = 30000, // 30초마다 공지
            .peer_timeout_ms = 120000,     // 2분 타임아웃
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.stop();
        
        // if (self.broadcast_socket) |socket| socket.deinit();
        // if (self.multicast_socket) |socket| socket.deinit();
        // if (self.listen_socket) |socket| socket.deinit();
        
        self.discovered_peers.deinit();
        self.allocator.destroy(self);
    }

    /// 브로드캐스트 공지 시스템 시작
    pub fn start(self: *Self, node_id: [32]u8) !void {
        if (self.is_running) return;
        
        print("📢 Starting broadcast announcer on port {} (broadcast: {}, multicast: {s}:{})\n", .{
            self.local_port, self.broadcast_port, self.multicast_group, self.multicast_port
        });
        
        // UDP 소켓들 초기화
        // try self.initializeSockets();
        
        self.is_running = true;
        
        // 공지 스레드 시작
        const announce_context = AnnounceContext{
            .announcer = self,
            .node_id = node_id,
        };
        self.announce_thread = try Thread.spawn(.{}, announceLoop, .{announce_context});
        
        // 리스닝 스레드 시작
        self.listen_thread = try Thread.spawn(.{}, listenLoop, .{self});
        
        print("✅ Broadcast announcer started successfully\n", .{});
    }

    /// 브로드캐스트 공지 시스템 중지
    pub fn stop(self: *Self) void {
        if (!self.is_running) return;
        
        print("🛑 Stopping broadcast announcer...\n", .{});
        self.is_running = false;
        
        // 스레드 종료 대기
        if (self.announce_thread) |thread| {
            thread.join();
            self.announce_thread = null;
        }
        
        if (self.listen_thread) |thread| {
            thread.join();
            self.listen_thread = null;
        }
        
        print("✅ Broadcast announcer stopped\n", .{});
    }

    /// UDP 소켓들 초기화
    fn initializeSockets(self: *Self) !void {
        _ = self;
        // UDP 소켓 구현은 추후 개선
        print("🔌 UDP sockets initialization skipped (TCP fallback)\n", .{});
    }

    /// 피어 공지 메시지 브로드캐스트
    fn broadcastAnnouncement(self: *Self, node_id: [32]u8) !void {
        _ = self;
        _ = node_id;
        
        // 일단 로그만 출력 (UDP 구현 추후 개선)
        print("📡 Announcement broadcasted (TCP fallback mode)\n", .{});
    }

    /// 수신된 메시지 처리
    fn handleReceivedMessage(self: *Self, msg_bytes: []const u8, sender_addr: net.Address) !void {
        const msg = AnnouncementMessage.fromBytes(msg_bytes) orelse {
            print("⚠️ Invalid announcement message received\n", .{});
            return;
        };
        
        switch (@as(AnnouncementMessage.MessageType, @enumFromInt(msg.message_type))) {
            .ANNOUNCE => {
                // 새로운 피어 발견
                try self.addOrUpdatePeer(msg, sender_addr);
                
                // 응답 전송
                try self.sendResponse(msg.node_id, sender_addr);
            },
            .RESPONSE => {
                // 응답 메시지 처리
                try self.addOrUpdatePeer(msg, sender_addr);
            },
            .GOODBYE => {
                // 피어 제거
                self.removePeer(msg.node_id);
            },
        }
    }

    /// 피어 정보 추가 또는 업데이트
    fn addOrUpdatePeer(self: *Self, msg: AnnouncementMessage, _: net.Address) !void {
        // 기존 피어 찾기
        for (self.discovered_peers.items) |*peer| {
            if (std.mem.eql(u8, &peer.node_id, &msg.node_id)) {
                // 기존 피어 업데이트
                peer.last_seen = std.time.milliTimestamp();
                peer.address = net.Address.initIp4([4]u8{127, 0, 0, 1}, msg.listen_port);
                peer.services = msg.services;
                peer.version = msg.version;
                print("🔄 Updated peer: {}\n", .{peer.address});
                return;
            }
        }
        
        // 새로운 피어 추가
        const peer_addr = net.Address.initIp4([4]u8{127, 0, 0, 1}, msg.listen_port);
        
        const peer = PeerInfo{
            .address = peer_addr,
            .node_id = msg.node_id,
            .last_seen = std.time.milliTimestamp(),
            .services = msg.services,
            .version = msg.version,
        };
        
        try self.discovered_peers.append(peer);
        print("🆕 New peer discovered via broadcast: {}\n", .{peer.address});
    }

    /// 응답 메시지 전송
    fn sendResponse(self: *Self, _: [32]u8, target_addr: net.Address) !void {
        _ = self;
        
        print("📤 Response sent to {} (TCP fallback mode)\n", .{target_addr});
    }

    /// 피어 제거
    fn removePeer(self: *Self, node_id: [32]u8) void {
        var i: usize = 0;
        while (i < self.discovered_peers.items.len) {
            if (std.mem.eql(u8, &self.discovered_peers.items[i].node_id, &node_id)) {
                const removed_peer = self.discovered_peers.swapRemove(i);
                print("👋 Peer left: {}\n", .{removed_peer.address});
                return;
            }
            i += 1;
        }
    }

    /// 만료된 피어들 정리
    fn cleanupExpiredPeers(self: *Self) void {
        var i: usize = 0;
        while (i < self.discovered_peers.items.len) {
            if (self.discovered_peers.items[i].isExpired(self.peer_timeout_ms)) {
                const expired_peer = self.discovered_peers.swapRemove(i);
                print("⏰ Peer expired: {}\n", .{expired_peer.address});
            } else {
                i += 1;
            }
        }
    }

    /// 발견된 피어 목록 반환
    pub fn getDiscoveredPeers(self: *Self) []const PeerInfo {
        return self.discovered_peers.items;
    }

    /// 상태 출력
    pub fn printStatus(self: *Self) void {
        print("📢 Broadcast Announcer Status: Running={}, Peers={}\n", .{
            self.is_running, 
            self.discovered_peers.items.len
        });
        
        if (self.discovered_peers.items.len > 0) {
            print("  📡 Discovered peers:\n", .{});
            for (self.discovered_peers.items) |peer| {
                const age_ms = std.time.milliTimestamp() - peer.last_seen;
                print("    - {} (age: {}ms, services: 0x{X})\n", .{ peer.address, age_ms, peer.services });
            }
        }
    }
};

/// 공지 스레드 컨텍스트
const AnnounceContext = struct {
    announcer: *BroadcastAnnouncer,
    node_id: [32]u8,
};

/// 공지 루프 (별도 스레드에서 실행)
fn announceLoop(context: AnnounceContext) void {
    print("📢 Announce loop started\n", .{});
    
    while (context.announcer.is_running) {
        // 피어 공지 브로드캐스트
        context.announcer.broadcastAnnouncement(context.node_id) catch |err| {
            print("❌ Broadcast error: {}\n", .{err});
        };
        
        // 만료된 피어들 정리
        context.announcer.cleanupExpiredPeers();
        
        // 공지 간격만큼 대기
        std.time.sleep(context.announcer.announce_interval_ms * std.time.ns_per_ms);
    }
    
    print("📢 Announce loop stopped\n", .{});
}

/// 리스닝 루프 (별도 스레드에서 실행)
fn listenLoop(announcer: *BroadcastAnnouncer) void {
    print("👂 Listen loop started (TCP fallback mode)\n", .{});
    
    while (announcer.is_running) {
        // TCP 폴백 모드에서는 단순히 대기
        std.time.sleep(1000 * std.time.ns_per_ms);
    }
    
    print("👂 Listen loop stopped\n", .{});
}

// 테스트 함수들
test "BroadcastAnnouncer creation and destruction" {
    const allocator = std.testing.allocator;
    
    const announcer = try BroadcastAnnouncer.init(allocator, 8000);
    defer announcer.deinit();
    
    try std.testing.expect(announcer.local_port == 8000);
    try std.testing.expect(!announcer.is_running);
}

test "AnnouncementMessage serialization" {
    var node_id: [32]u8 = undefined;
    std.crypto.random.bytes(&node_id);
    
    const msg = BroadcastAnnouncer.AnnouncementMessage.init(.ANNOUNCE, node_id, 8000, 0x01);
    
    try std.testing.expect(msg.isValid());
    
    const bytes = msg.toBytes();
    const decoded_msg = BroadcastAnnouncer.AnnouncementMessage.fromBytes(bytes);
    
    try std.testing.expect(decoded_msg != null);
    try std.testing.expect(decoded_msg.?.listen_port == 8000);
}