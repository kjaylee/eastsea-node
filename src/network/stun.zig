const std = @import("std");
const net = std.net;
const print = std.debug.print;

/// STUN 메시지 타입
pub const StunMessageType = enum(u16) {
    binding_request = 0x0001,
    binding_response = 0x0101,
    binding_error_response = 0x0111,
    
    pub fn fromU16(value: u16) ?StunMessageType {
        return switch (value) {
            0x0001 => .binding_request,
            0x0101 => .binding_response,
            0x0111 => .binding_error_response,
            else => null,
        };
    }
    
    pub fn toU16(self: StunMessageType) u16 {
        return @intFromEnum(self);
    }
};

/// STUN 속성 타입
pub const StunAttributeType = enum(u16) {
    mapped_address = 0x0001,
    username = 0x0006,
    message_integrity = 0x0008,
    error_code = 0x0009,
    unknown_attributes = 0x000A,
    realm = 0x0014,
    nonce = 0x0015,
    xor_mapped_address = 0x0020,
    software = 0x8022,
    alternate_server = 0x8023,
    fingerprint = 0x8028,
    
    pub fn fromU16(value: u16) ?StunAttributeType {
        return switch (value) {
            0x0001 => .mapped_address,
            0x0006 => .username,
            0x0008 => .message_integrity,
            0x0009 => .error_code,
            0x000A => .unknown_attributes,
            0x0014 => .realm,
            0x0015 => .nonce,
            0x0020 => .xor_mapped_address,
            0x8022 => .software,
            0x8023 => .alternate_server,
            0x8028 => .fingerprint,
            else => null,
        };
    }
    
    pub fn toU16(self: StunAttributeType) u16 {
        return @intFromEnum(self);
    }
};

/// STUN 메시지 헤더 (20바이트)
pub const StunHeader = struct {
    message_type: u16,      // 메시지 타입
    message_length: u16,    // 메시지 길이 (헤더 제외)
    magic_cookie: u32,      // 매직 쿠키 (0x2112A442)
    transaction_id: [12]u8, // 트랜잭션 ID (96비트)
    
    const MAGIC_COOKIE: u32 = 0x2112A442;
    
    pub fn init(msg_type: StunMessageType, transaction_id: [12]u8) StunHeader {
        return StunHeader{
            .message_type = std.mem.nativeToBig(u16, msg_type.toU16()),
            .message_length = 0, // 초기에는 0, 나중에 업데이트
            .magic_cookie = std.mem.nativeToBig(u32, MAGIC_COOKIE),
            .transaction_id = transaction_id,
        };
    }
    
    pub fn setLength(self: *StunHeader, length: u16) void {
        self.message_length = std.mem.nativeToBig(u16, length);
    }
    
    pub fn getMessageType(self: *const StunHeader) ?StunMessageType {
        return StunMessageType.fromU16(std.mem.bigToNative(u16, self.message_type));
    }
    
    pub fn getLength(self: *const StunHeader) u16 {
        return std.mem.bigToNative(u16, self.message_length);
    }
    
    pub fn isValid(self: *const StunHeader) bool {
        return std.mem.bigToNative(u32, self.magic_cookie) == MAGIC_COOKIE;
    }
};

/// STUN 속성
pub const StunAttribute = struct {
    attr_type: StunAttributeType,
    length: u16,
    value: []const u8,
    
    pub fn init(attr_type: StunAttributeType, value: []const u8) StunAttribute {
        return StunAttribute{
            .attr_type = attr_type,
            .length = @intCast(value.len),
            .value = value,
        };
    }
    
    /// 속성을 바이트 배열로 직렬화
    pub fn serialize(self: *const StunAttribute, allocator: std.mem.Allocator) ![]u8 {
        const total_length = 4 + self.length + getPadding(self.length);
        var buffer = try allocator.alloc(u8, total_length);
        
        // 타입 (2바이트)
        std.mem.writeInt(u16, buffer[0..2], self.attr_type.toU16(), .big);
        
        // 길이 (2바이트)
        std.mem.writeInt(u16, buffer[2..4], self.length, .big);
        
        // 값
        @memcpy(buffer[4..4 + self.length], self.value);
        
        // 패딩 (4바이트 정렬)
        const padding = getPadding(self.length);
        if (padding > 0) {
            @memset(buffer[4 + self.length..], 0);
        }
        
        return buffer;
    }
    
    /// 4바이트 정렬을 위한 패딩 계산
    fn getPadding(length: u16) u16 {
        const remainder = length % 4;
        return if (remainder == 0) 0 else 4 - remainder;
    }
};

/// STUN 클라이언트
pub const StunClient = struct {
    allocator: std.mem.Allocator,
    socket: net.Stream,
    server_address: net.Address,
    
    pub fn init(allocator: std.mem.Allocator, server_host: []const u8, server_port: u16) !StunClient {
        // STUN 서버에 연결
        const server_address = try net.Address.resolveIp(server_host, server_port);
        const socket = try net.tcpConnectToAddress(server_address);
        
        return StunClient{
            .allocator = allocator,
            .socket = socket,
            .server_address = server_address,
        };
    }
    
    pub fn deinit(self: *StunClient) void {
        self.socket.close();
    }
    
    /// 바인딩 요청을 보내고 응답을 받아 공인 IP 주소를 얻음
    pub fn getPublicAddress(self: *StunClient) !?net.Address {
        // 트랜잭션 ID 생성
        var transaction_id: [12]u8 = undefined;
        std.crypto.random.bytes(&transaction_id);
        
        // STUN 바인딩 요청 생성
        const request = try self.createBindingRequest(transaction_id);
        defer self.allocator.free(request);
        
        // 요청 전송
        _ = try self.socket.writeAll(request);
        
        // 응답 수신
        var response_buffer: [1024]u8 = undefined;
        const bytes_read = try self.socket.readAll(response_buffer[0..]);
        
        if (bytes_read < @sizeOf(StunHeader)) {
            print("❌ Invalid STUN response: too short\n", .{});
            return null;
        }
        
        // 응답 파싱
        return try self.parseBindingResponse(response_buffer[0..bytes_read], transaction_id);
    }
    
    /// STUN 바인딩 요청 메시지 생성
    fn createBindingRequest(self: *StunClient, transaction_id: [12]u8) ![]u8 {
        var header = StunHeader.init(.binding_request, transaction_id);
        
        // 헤더만 있는 경우 (속성 없음)
        header.setLength(0);
        
        const buffer = try self.allocator.alloc(u8, @sizeOf(StunHeader));
        @memcpy(buffer, std.mem.asBytes(&header));
        
        return buffer;
    }
    
    /// STUN 바인딩 응답 파싱
    fn parseBindingResponse(self: *StunClient, response: []const u8, expected_transaction_id: [12]u8) !?net.Address {
        if (response.len < @sizeOf(StunHeader)) {
            return null;
        }
        
        // 헤더 파싱
        const header = std.mem.bytesToValue(StunHeader, response[0..@sizeOf(StunHeader)]);
        
        if (!header.isValid()) {
            print("❌ Invalid STUN magic cookie\n", .{});
            return null;
        }
        
        if (!std.mem.eql(u8, &header.transaction_id, &expected_transaction_id)) {
            print("❌ Transaction ID mismatch\n", .{});
            return null;
        }
        
        const msg_type = header.getMessageType() orelse {
            print("❌ Unknown STUN message type\n", .{});
            return null;
        };
        
        if (msg_type != .binding_response) {
            print("❌ Expected binding response, got: {}\n", .{msg_type});
            return null;
        }
        
        // 속성 파싱
        const attributes_start = @sizeOf(StunHeader);
        const attributes_length = header.getLength();
        
        if (response.len < attributes_start + attributes_length) {
            print("❌ Invalid STUN response: incomplete attributes\n", .{});
            return null;
        }
        
        return try self.parseAttributes(response[attributes_start..attributes_start + attributes_length]);
    }
    
    /// STUN 속성들 파싱
    fn parseAttributes(self: *StunClient, attributes_data: []const u8) !?net.Address {
        var offset: usize = 0;
        
        while (offset + 4 <= attributes_data.len) {
            const attr_type_raw = std.mem.readInt(u16, attributes_data[offset..][0..2], .big);
            const attr_length = std.mem.readInt(u16, attributes_data[offset + 2..][0..2], .big);
            
            offset += 4;
            
            if (offset + attr_length > attributes_data.len) {
                break;
            }
            
            const attr_type = StunAttributeType.fromU16(attr_type_raw);
            
            if (attr_type) |atype| {
                switch (atype) {
                    .mapped_address => {
                        if (try self.parseMappedAddress(attributes_data[offset..offset + attr_length])) |addr| {
                            return addr;
                        }
                    },
                    .xor_mapped_address => {
                        if (try self.parseXorMappedAddress(attributes_data[offset..offset + attr_length])) |addr| {
                            return addr;
                        }
                    },
                    else => {
                        // 다른 속성들은 무시
                    },
                }
            }
            
            // 4바이트 정렬을 위한 패딩 건너뛰기
            const padding = if (attr_length % 4 == 0) 0 else 4 - (attr_length % 4);
            offset += attr_length + padding;
        }
        
        return null;
    }
    
    /// MAPPED-ADDRESS 속성 파싱
    fn parseMappedAddress(self: *StunClient, data: []const u8) !?net.Address {
        _ = self;
        if (data.len < 8) {
            return null;
        }
        
        // 첫 번째 바이트는 예약됨
        const family = data[1];
        const port = std.mem.readInt(u16, data[2..][0..2], .big);
        
        switch (family) {
            0x01 => { // IPv4
                if (data.len < 8) return null;
                const ip_bytes = data[4..8];
                return net.Address.initIp4(ip_bytes.*, port);
            },
            0x02 => { // IPv6
                if (data.len < 20) return null;
                const ip_bytes = data[4..20];
                return net.Address.initIp6(ip_bytes.*, port, 0, 0);
            },
            else => return null,
        }
    }
    
    /// XOR-MAPPED-ADDRESS 속성 파싱
    fn parseXorMappedAddress(self: *StunClient, data: []const u8) !?net.Address {
        _ = self;
        if (data.len < 8) {
            return null;
        }
        
        // 첫 번째 바이트는 예약됨
        const family = data[1];
        const xor_port = std.mem.readInt(u16, data[2..][0..2], .big);
        const port = xor_port ^ (StunHeader.MAGIC_COOKIE >> 16);
        
        switch (family) {
            0x01 => { // IPv4
                if (data.len < 8) return null;
                const xor_ip = std.mem.readInt(u32, data[4..][0..4], .big);
                const ip = xor_ip ^ StunHeader.MAGIC_COOKIE;
                const ip_bytes = std.mem.asBytes(&std.mem.nativeToBig(u32, ip));
                return net.Address.initIp4(ip_bytes.*, @intCast(port));
            },
            0x02 => { // IPv6 (더 복잡한 XOR 로직 필요)
                // IPv6 XOR 구현은 생략 (필요시 추가)
                return null;
            },
            else => return null,
        }
    }
};

/// 공용 STUN 서버 목록
pub const PUBLIC_STUN_SERVERS = [_]struct { host: []const u8, port: u16 }{
    .{ .host = "stun.l.google.com", .port = 19302 },
    .{ .host = "stun1.l.google.com", .port = 19302 },
    .{ .host = "stun2.l.google.com", .port = 19302 },
    .{ .host = "stun3.l.google.com", .port = 19302 },
    .{ .host = "stun4.l.google.com", .port = 19302 },
    .{ .host = "stun.cloudflare.com", .port = 3478 },
    .{ .host = "stun.stunprotocol.org", .port = 3478 },
};

/// NAT 통과 도우미
pub const NatTraversal = struct {
    allocator: std.mem.Allocator,
    public_address: ?net.Address,
    local_address: ?net.Address,
    
    pub fn init(allocator: std.mem.Allocator) NatTraversal {
        return NatTraversal{
            .allocator = allocator,
            .public_address = null,
            .local_address = null,
        };
    }
    
    pub fn deinit(self: *NatTraversal) void {
        _ = self;
    }
    
    /// STUN을 사용하여 공인 IP 주소 발견
    pub fn discoverPublicAddress(self: *NatTraversal) !bool {
        print("🔍 Discovering public IP address using STUN...\n", .{});
        
        // 여러 STUN 서버를 시도
        for (PUBLIC_STUN_SERVERS) |server| {
            print("🌐 Trying STUN server: {s}:{d}\n", .{ server.host, server.port });
            
            var stun_client = StunClient.init(self.allocator, server.host, server.port) catch |err| {
                print("❌ Failed to connect to STUN server {s}:{d}: {}\n", .{ server.host, server.port, err });
                continue;
            };
            defer stun_client.deinit();
            
            if (stun_client.getPublicAddress()) |public_addr| {
                self.public_address = public_addr;
                print("✅ Public address discovered: {?}\n", .{public_addr});
                return true;
            } else |err| {
                print("❌ Failed to get public address from {s}:{d}: {}\n", .{ server.host, server.port, err });
            }
        }
        
        print("❌ Failed to discover public address from any STUN server\n", .{});
        return false;
    }
    
    /// 로컬 IP 주소 발견
    pub fn discoverLocalAddress(self: *NatTraversal) !bool {
        print("🔍 Discovering local IP address...\n", .{});
        
        // 간단한 방법: 하드코딩된 로컬 주소 사용 (실제로는 시스템 API 사용해야 함)
        const local_addr = try net.Address.parseIp4("127.0.0.1", 0);
        self.local_address = local_addr;
        print("✅ Local address discovered: {}\n", .{local_addr});
        return true;
    }
    
    /// NAT 타입 감지
    pub fn detectNatType(self: *NatTraversal) !void {
        print("🔍 Detecting NAT type...\n", .{});
        
        if (self.public_address == null or self.local_address == null) {
            print("❌ Need both public and local addresses to detect NAT type\n", .{});
            return;
        }
        
        const public_addr = self.public_address.?;
        const local_addr = self.local_address.?;
        
        // 간단한 NAT 타입 감지 (주소 구조체 비교 대신 문자열 비교 사용)
        if (public_addr.getPort() == local_addr.getPort()) {
            print("📡 NAT Type: No NAT (Direct Internet Connection)\n", .{});
        } else {
            print("🛡️ NAT Type: Behind NAT\n", .{});
            print("   Local:  {}\n", .{local_addr});
            print("   Public: {}\n", .{public_addr});
        }
    }
    
    /// 전체 NAT 통과 프로세스 실행
    pub fn performNatTraversal(self: *NatTraversal) !bool {
        print("🚀 Starting NAT traversal process...\n", .{});
        print("===================================\n", .{});
        
        // 1. 로컬 주소 발견
        if (!try self.discoverLocalAddress()) {
            return false;
        }
        
        // 2. 공인 주소 발견
        if (!try self.discoverPublicAddress()) {
            return false;
        }
        
        // 3. NAT 타입 감지
        try self.detectNatType();
        
        print("\n✅ NAT traversal process completed successfully!\n", .{});
        return true;
    }
    
    /// 상태 출력
    pub fn printStatus(self: *const NatTraversal) void {
        print("\n📊 NAT Traversal Status\n", .{});
        print("======================\n", .{});
        if (self.local_address) |addr| {
            print("🏠 Local Address:  {}\n", .{addr});
        } else {
            print("🏠 Local Address:  Not discovered\n", .{});
        }
        
        if (self.public_address) |addr| {
            print("🌐 Public Address: {}\n", .{addr});
        } else {
            print("🌐 Public Address: Not discovered\n", .{});
        }
        print("\n", .{});
    }
};

// 테스트 함수들
test "STUN header creation" {
    const transaction_id = [_]u8{1} ** 12;
    const header = StunHeader.init(.binding_request, transaction_id);
    
    try std.testing.expect(header.isValid());
    try std.testing.expect(header.getMessageType() == .binding_request);
}

test "STUN attribute creation" {
    const allocator = std.testing.allocator;
    const test_value = "test";
    const attr = StunAttribute.init(.software, test_value);
    
    const serialized = try attr.serialize(allocator);
    defer allocator.free(serialized);
    
    try std.testing.expect(serialized.len >= 4 + test_value.len);
}