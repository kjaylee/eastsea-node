const std = @import("std");
const net = std.net;
const crypto = @import("../crypto/hash.zig");
const p2p = @import("p2p.zig");
const bootstrap = @import("bootstrap.zig");

pub const MDNSError = error{
    SocketCreationFailed,
    BindFailed,
    SendFailed,
    ReceiveFailed,
    InvalidMessage,
    NetworkError,
};

// mDNS constants
pub const MDNS_MULTICAST_ADDRESS = "224.0.0.251";
pub const MDNS_PORT = 5353;
pub const MDNS_TTL = 255;

// Service discovery constants
pub const SERVICE_NAME = "_eastsea._tcp.local";
pub const SERVICE_INSTANCE_PREFIX = "eastsea-node-";

// mDNS message types
pub const MDNSMessageType = enum(u8) {
    query = 0,
    response = 1,
};

// mDNS record types
pub const MDNSRecordType = enum(u16) {
    A = 1,      // IPv4 address
    PTR = 12,   // Pointer record
    TXT = 16,   // Text record
    SRV = 33,   // Service record
};

// mDNS record class
pub const MDNSRecordClass = enum(u16) {
    IN = 1,     // Internet class
};

pub const MDNSHeader = struct {
    id: u16,
    flags: u16,
    questions: u16,
    answers: u16,
    authority: u16,
    additional: u16,

    pub fn init(id: u16, is_response: bool, questions: u16, answers: u16) MDNSHeader {
        var flags: u16 = 0;
        if (is_response) {
            flags |= 0x8000; // Response flag
        }
        
        return MDNSHeader{
            .id = id,
            .flags = flags,
            .questions = questions,
            .answers = answers,
            .authority = 0,
            .additional = 0,
        };
    }

    pub fn serialize(self: *const MDNSHeader, buffer: []u8) !void {
        if (buffer.len < 12) return error.BufferTooSmall;
        
        std.mem.writeInt(u16, buffer[0..][0..2], self.id, .big);
        std.mem.writeInt(u16, buffer[2..][0..2], self.flags, .big);
        std.mem.writeInt(u16, buffer[4..][0..2], self.questions, .big);
        std.mem.writeInt(u16, buffer[6..][0..2], self.answers, .big);
        std.mem.writeInt(u16, buffer[8..][0..2], self.authority, .big);
        std.mem.writeInt(u16, buffer[10..][0..2], self.additional, .big);
    }

    pub fn deserialize(buffer: []const u8) !MDNSHeader {
        if (buffer.len < 12) return error.BufferTooSmall;
        
        return MDNSHeader{
            .id = std.mem.readInt(u16, buffer[0..][0..2], .big),
            .flags = std.mem.readInt(u16, buffer[2..][0..2], .big),
            .questions = std.mem.readInt(u16, buffer[4..][0..2], .big),
            .answers = std.mem.readInt(u16, buffer[6..][0..2], .big),
            .authority = std.mem.readInt(u16, buffer[8..][0..2], .big),
            .additional = std.mem.readInt(u16, buffer[10..][0..2], .big),
        };
    }

    pub fn isResponse(self: *const MDNSHeader) bool {
        return (self.flags & 0x8000) != 0;
    }
};

pub const MDNSQuestion = struct {
    name: []const u8,
    qtype: MDNSRecordType,
    qclass: MDNSRecordClass,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, qtype: MDNSRecordType, qclass: MDNSRecordClass) !MDNSQuestion {
        return MDNSQuestion{
            .name = try allocator.dupe(u8, name),
            .qtype = qtype,
            .qclass = qclass,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MDNSQuestion) void {
        self.allocator.free(self.name);
    }

    pub fn serialize(self: *const MDNSQuestion, allocator: std.mem.Allocator) ![]u8 {
        const encoded_name = try encodeDomainName(allocator, self.name);
        defer allocator.free(encoded_name);
        
        const total_size = encoded_name.len + 4; // name + qtype + qclass
        var buffer = try allocator.alloc(u8, total_size);
        
        var offset: usize = 0;
        @memcpy(buffer[offset..offset + encoded_name.len], encoded_name);
        offset += encoded_name.len;
        
        std.mem.writeInt(u16, buffer[offset..][0..2], @intFromEnum(self.qtype), .big);
        offset += 2;
        
        std.mem.writeInt(u16, buffer[offset..][0..2], @intFromEnum(self.qclass), .big);
        
        return buffer;
    }
};

pub const MDNSRecord = struct {
    name: []const u8,
    rtype: MDNSRecordType,
    rclass: MDNSRecordClass,
    ttl: u32,
    data: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, rtype: MDNSRecordType, rclass: MDNSRecordClass, ttl: u32, data: []const u8) !MDNSRecord {
        return MDNSRecord{
            .name = try allocator.dupe(u8, name),
            .rtype = rtype,
            .rclass = rclass,
            .ttl = ttl,
            .data = try allocator.dupe(u8, data),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MDNSRecord) void {
        self.allocator.free(self.name);
        self.allocator.free(self.data);
    }

    pub fn serialize(self: *const MDNSRecord, allocator: std.mem.Allocator) ![]u8 {
        const encoded_name = try encodeDomainName(allocator, self.name);
        defer allocator.free(encoded_name);
        
        const total_size = encoded_name.len + 10 + self.data.len; // name + type + class + ttl + rdlength + data
        var buffer = try allocator.alloc(u8, total_size);
        
        var offset: usize = 0;
        @memcpy(buffer[offset..offset + encoded_name.len], encoded_name);
        offset += encoded_name.len;
        
        std.mem.writeInt(u16, buffer[offset..][0..2], @intFromEnum(self.rtype), .big);
        offset += 2;
        
        std.mem.writeInt(u16, buffer[offset..][0..2], @intFromEnum(self.rclass), .big);
        offset += 2;
        
        std.mem.writeInt(u32, buffer[offset..][0..4], self.ttl, .big);
        offset += 4;
        
        std.mem.writeInt(u16, buffer[offset..][0..2], @intCast(self.data.len), .big);
        offset += 2;
        
        @memcpy(buffer[offset..offset + self.data.len], self.data);
        
        return buffer;
    }
};

pub const MDNSMessage = struct {
    header: MDNSHeader,
    questions: std.ArrayList(MDNSQuestion),
    answers: std.ArrayList(MDNSRecord),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, id: u16, is_response: bool) MDNSMessage {
        return MDNSMessage{
            .header = MDNSHeader.init(id, is_response, 0, 0),
            .questions = std.ArrayList(MDNSQuestion).init(allocator),
            .answers = std.ArrayList(MDNSRecord).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MDNSMessage) void {
        for (self.questions.items) |*question| {
            question.deinit();
        }
        self.questions.deinit();
        
        for (self.answers.items) |*answer| {
            answer.deinit();
        }
        self.answers.deinit();
    }

    pub fn addQuestion(self: *MDNSMessage, question: MDNSQuestion) !void {
        try self.questions.append(question);
        self.header.questions = @intCast(self.questions.items.len);
    }

    pub fn addAnswer(self: *MDNSMessage, answer: MDNSRecord) !void {
        try self.answers.append(answer);
        self.header.answers = @intCast(self.answers.items.len);
    }

    pub fn serialize(self: *const MDNSMessage) ![]u8 {
        var total_size: usize = 12; // Header size
        
        // Calculate questions size
        var question_buffers = std.ArrayList([]u8).init(self.allocator);
        defer {
            for (question_buffers.items) |buffer| {
                self.allocator.free(buffer);
            }
            question_buffers.deinit();
        }
        
        for (self.questions.items) |*question| {
            const buffer = try question.serialize(self.allocator);
            try question_buffers.append(buffer);
            total_size += buffer.len;
        }
        
        // Calculate answers size
        var answer_buffers = std.ArrayList([]u8).init(self.allocator);
        defer {
            for (answer_buffers.items) |buffer| {
                self.allocator.free(buffer);
            }
            answer_buffers.deinit();
        }
        
        for (self.answers.items) |*answer| {
            const buffer = try answer.serialize(self.allocator);
            try answer_buffers.append(buffer);
            total_size += buffer.len;
        }
        
        // Allocate final buffer
        var result = try self.allocator.alloc(u8, total_size);
        var offset: usize = 0;
        
        // Serialize header
        try self.header.serialize(result[offset..]);
        offset += 12;
        
        // Serialize questions
        for (question_buffers.items) |buffer| {
            @memcpy(result[offset..offset + buffer.len], buffer);
            offset += buffer.len;
        }
        
        // Serialize answers
        for (answer_buffers.items) |buffer| {
            @memcpy(result[offset..offset + buffer.len], buffer);
            offset += buffer.len;
        }
        
        return result;
    }
};

pub const MDNSDiscovery = struct {
    allocator: std.mem.Allocator,
    socket: ?std.net.Server,
    local_address: []const u8,
    local_port: u16,
    service_instance: []const u8,
    p2p_node: ?*p2p.P2PNode,
    bootstrap_client: ?*bootstrap.BootstrapClient,
    discovered_peers: std.ArrayList(DiscoveredPeer),
    running: bool,

    pub const DiscoveredPeer = struct {
        address: []const u8,
        port: u16,
        service_instance: []const u8,
        last_seen: i64,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, address: []const u8, port: u16, service_instance: []const u8) !DiscoveredPeer {
            return DiscoveredPeer{
                .address = try allocator.dupe(u8, address),
                .port = port,
                .service_instance = try allocator.dupe(u8, service_instance),
                .last_seen = std.time.timestamp(),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *DiscoveredPeer) void {
            self.allocator.free(self.address);
            self.allocator.free(self.service_instance);
        }

        pub fn isAlive(self: *const DiscoveredPeer) bool {
            const current_time = std.time.timestamp();
            return (current_time - self.last_seen) < 300; // 5 minutes
        }

        pub fn updateLastSeen(self: *DiscoveredPeer) void {
            self.last_seen = std.time.timestamp();
        }
    };

    pub fn init(allocator: std.mem.Allocator, local_address: []const u8, local_port: u16) !MDNSDiscovery {
        // Generate unique service instance name
        var node_id: [8]u8 = undefined;
        std.crypto.random.bytes(&node_id);
        const service_instance = try std.fmt.allocPrint(allocator, "{s}{s}", .{ SERVICE_INSTANCE_PREFIX, std.fmt.fmtSliceHexLower(&node_id) });

        return MDNSDiscovery{
            .allocator = allocator,
            .socket = null,
            .local_address = try allocator.dupe(u8, local_address),
            .local_port = local_port,
            .service_instance = service_instance,
            .p2p_node = null,
            .bootstrap_client = null,
            .discovered_peers = std.ArrayList(DiscoveredPeer).init(allocator),
            .running = false,
        };
    }

    pub fn deinit(self: *MDNSDiscovery) void {
        self.stop();
        
        for (self.discovered_peers.items) |*peer| {
            peer.deinit();
        }
        self.discovered_peers.deinit();
        
        self.allocator.free(self.local_address);
        self.allocator.free(self.service_instance);
    }

    pub fn attachP2PNode(self: *MDNSDiscovery, p2p_node: *p2p.P2PNode) void {
        self.p2p_node = p2p_node;
    }

    pub fn attachBootstrapClient(self: *MDNSDiscovery, bootstrap_client: *bootstrap.BootstrapClient) void {
        self.bootstrap_client = bootstrap_client;
    }

    pub fn start(self: *MDNSDiscovery) !void {
        // mDNS functionality temporarily disabled due to Zig 0.14 compatibility
        // TODO: Implement UDP multicast socket support for Zig 0.14
        self.running = true;
        
        std.debug.print("🔍 mDNS Discovery started (limited mode) on {s}:{}\n", .{ self.local_address, self.local_port });
        std.debug.print("📡 Service instance: {s}\n", .{self.service_instance});
        std.debug.print("⚠️  UDP multicast temporarily disabled for Zig 0.14 compatibility\n", .{});
    }

    pub fn stop(self: *MDNSDiscovery) void {
        if (self.socket) |*socket| {
            socket.deinit();
            self.socket = null;
        }
        self.running = false;
        std.debug.print("🛑 mDNS Discovery stopped\n", .{});
    }

    fn joinMulticastGroup(self: *MDNSDiscovery) !void {
        // mDNS multicast temporarily disabled for Zig 0.14 compatibility
        _ = self;
        std.debug.print("📡 mDNS multicast group joining disabled (Zig 0.14 compatibility)\n", .{});
    }

    pub fn announceService(self: *MDNSDiscovery) !void {
        std.debug.print("📢 Announcing mDNS service: {s}\n", .{self.service_instance});
        
        var message = MDNSMessage.init(self.allocator, 0, true); // Response message
        defer message.deinit();
        
        // Create PTR record for service discovery
        const ptr_data = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ self.service_instance, SERVICE_NAME });
        defer self.allocator.free(ptr_data);
        
        const ptr_record = try MDNSRecord.init(
            self.allocator,
            SERVICE_NAME,
            .PTR,
            .IN,
            120, // TTL
            ptr_data
        );
        try message.addAnswer(ptr_record);
        
        // Create SRV record with port information
        const srv_data = try self.createSRVData();
        defer self.allocator.free(srv_data);
        
        const srv_record_name = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ self.service_instance, SERVICE_NAME });
        defer self.allocator.free(srv_record_name);
        
        const srv_record = try MDNSRecord.init(
            self.allocator,
            srv_record_name,
            .SRV,
            .IN,
            120, // TTL
            srv_data
        );
        try message.addAnswer(srv_record);
        
        // Create TXT record with additional info
        const txt_data = try std.fmt.allocPrint(self.allocator, "version=1.0", .{});
        defer self.allocator.free(txt_data);
        
        const txt_record = try MDNSRecord.init(
            self.allocator,
            srv_record_name,
            .TXT,
            .IN,
            120, // TTL
            txt_data
        );
        try message.addAnswer(txt_record);
        
        // Send announcement
        try self.sendMessage(&message);
    }

    pub fn queryForServices(self: *MDNSDiscovery) !void {
        std.debug.print("🔍 Querying for mDNS services: {s}\n", .{SERVICE_NAME});
        
        var message = MDNSMessage.init(self.allocator, 1, false); // Query message
        defer message.deinit();
        
        const question = try MDNSQuestion.init(self.allocator, SERVICE_NAME, .PTR, .IN);
        try message.addQuestion(question);
        
        try self.sendMessage(&message);
    }

    fn createSRVData(self: *MDNSDiscovery) ![]u8 {
        // SRV record format: priority(2) + weight(2) + port(2) + target
        var buffer = try self.allocator.alloc(u8, 6 + self.local_address.len + 1);
        
        var offset: usize = 0;
        
        // Priority (0 = highest)
        std.mem.writeInt(u16, buffer[offset..][0..2], 0, .big);
        offset += 2;
        
        // Weight
        std.mem.writeInt(u16, buffer[offset..][0..2], 0, .big);
        offset += 2;
        
        // Port
        std.mem.writeInt(u16, buffer[offset..][0..2], self.local_port, .big);
        offset += 2;
        
        // Target (simplified - should be encoded domain name)
        @memcpy(buffer[offset..offset + self.local_address.len], self.local_address);
        offset += self.local_address.len;
        buffer[offset] = 0; // Null terminator
        
        return buffer;
    }

    fn sendMessage(self: *MDNSDiscovery, message: *const MDNSMessage) !void {
        // mDNS sending temporarily disabled for Zig 0.14 compatibility
        _ = self;
        _ = message;
        std.debug.print("📤 mDNS message sending disabled (Zig 0.14 compatibility)\n", .{});
    }

    pub fn receiveMessages(self: *MDNSDiscovery) !void {
        // mDNS receiving temporarily disabled for Zig 0.14 compatibility
        _ = self;
        std.debug.print("📥 mDNS message receiving disabled (Zig 0.14 compatibility)\n", .{});
    }

    fn processReceivedMessage(self: *MDNSDiscovery, buffer: []const u8) !void {
        if (buffer.len < 12) return; // Too small for mDNS header
        
        const header = try MDNSHeader.deserialize(buffer);
        
        std.debug.print("📥 Received mDNS message: questions={}, answers={}\n", .{ header.questions, header.answers });
        
        // Simple processing - in a real implementation, you would parse the full message
        if (header.answers > 0) {
            // This is a response - could contain service announcements
            try self.handleServiceResponse(buffer);
        } else if (header.questions > 0) {
            // This is a query - we might need to respond
            try self.handleServiceQuery(buffer);
        }
    }

    fn handleServiceResponse(self: *MDNSDiscovery, buffer: []const u8) !void {
        _ = buffer;
        
        // Simplified implementation - in reality, you would parse the records
        // and extract service information
        
        std.debug.print("🎯 Discovered potential service announcement\n", .{});
        
        // For demo purposes, add a mock discovered peer
        const mock_peer = try DiscoveredPeer.init(
            self.allocator,
            "127.0.0.1",
            8001,
            "mock-service-instance"
        );
        
        // Check if peer already exists
        var found = false;
        for (self.discovered_peers.items) |*peer| {
            if (std.mem.eql(u8, peer.address, mock_peer.address) and peer.port == mock_peer.port) {
                peer.updateLastSeen();
                found = true;
                break;
            }
        }
        
        if (!found) {
            try self.discovered_peers.append(mock_peer);
            std.debug.print("➕ Added discovered peer: {s}:{}\n", .{ mock_peer.address, mock_peer.port });
            
            // Try to connect via P2P
            if (self.p2p_node) |p2p_node| {
                const peer_address = try net.Address.parseIp4(mock_peer.address, mock_peer.port);
                _ = p2p_node.connectToPeer(peer_address) catch |err| {
                    std.debug.print("⚠️  Failed to connect to discovered peer: {}\n", .{err});
                };
            }
            
            // Add to bootstrap client
            if (self.bootstrap_client) |bootstrap_client| {
                bootstrap_client.addBootstrapNode(mock_peer.address, mock_peer.port) catch |err| {
                    std.debug.print("⚠️  Failed to add discovered peer to bootstrap: {}\n", .{err});
                };
            }
        } else {
            mock_peer.deinit();
        }
    }

    fn handleServiceQuery(self: *MDNSDiscovery, buffer: []const u8) !void {
        _ = buffer;
        
        std.debug.print("❓ Received service query - sending announcement\n", .{});
        
        // Respond with our service announcement
        try self.announceService();
    }

    pub fn getDiscoveredPeerCount(self: *const MDNSDiscovery) usize {
        return self.discovered_peers.items.len;
    }

    pub fn getActivePeerCount(self: *const MDNSDiscovery) usize {
        var active: usize = 0;
        for (self.discovered_peers.items) |peer| {
            if (peer.isAlive()) {
                active += 1;
            }
        }
        return active;
    }

    pub fn cleanupStaleEntries(self: *MDNSDiscovery) void {
        var i: usize = 0;
        while (i < self.discovered_peers.items.len) {
            if (!self.discovered_peers.items[i].isAlive()) {
                var stale_peer = self.discovered_peers.swapRemove(i);
                stale_peer.deinit();
                std.debug.print("🧹 Removed stale peer entry\n", .{});
            } else {
                i += 1;
            }
        }
    }
};

// Helper function to encode domain names for DNS
fn encodeDomainName(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    // Simplified implementation - in reality, you would properly encode DNS names
    // with length prefixes for each label
    
    var result = try allocator.alloc(u8, name.len + 2);
    result[0] = @intCast(name.len);
    @memcpy(result[1..name.len + 1], name);
    result[name.len + 1] = 0; // Null terminator
    
    return result;
}

test "mDNS header serialization" {
    const testing = std.testing;
    
    const header = MDNSHeader.init(1234, true, 1, 2);
    
    var buffer: [12]u8 = undefined;
    try header.serialize(&buffer);
    
    const deserialized = try MDNSHeader.deserialize(&buffer);
    
    try testing.expect(deserialized.id == 1234);
    try testing.expect(deserialized.isResponse());
    try testing.expect(deserialized.questions == 1);
    try testing.expect(deserialized.answers == 2);
}

test "mDNS discovery creation" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var discovery = try MDNSDiscovery.init(allocator, "127.0.0.1", 8000);
    defer discovery.deinit();
    
    try testing.expect(discovery.getDiscoveredPeerCount() == 0);
    try testing.expect(std.mem.startsWith(u8, discovery.service_instance, SERVICE_INSTANCE_PREFIX));
}