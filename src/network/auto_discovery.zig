const std = @import("std");
const net = std.net;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const dht = @import("dht.zig");
const bootstrap = @import("bootstrap.zig");
const mdns = @import("mdns.zig");
const p2p = @import("p2p.zig");
const upnp = @import("upnp.zig");
const port_scanner = @import("port_scanner.zig");
const broadcast = @import("broadcast.zig");

/// 자동 피어 발견 및 연결 관리자
/// DHT, Bootstrap, mDNS를 통합하여 완전 자동화된 피어 발견 시스템 제공
pub const AutoDiscovery = struct {
    allocator: Allocator,
    port: u16,
    dht_node: ?*dht.DHT,
    p2p_node: ?*p2p.P2PNode,
    upnp_client: ?*upnp.UPnPClient,
    port_scanner: ?*port_scanner.PortScanner,
    broadcast_announcer: ?*broadcast.BroadcastAnnouncer,
    
    // 발견된 피어 목록
    discovered_peers: ArrayList(net.Address),
    
    // 연결 시도 중인 피어들
    connecting_peers: ArrayList(net.Address),
    
    // 연결된 피어들
    connected_peers: ArrayList(net.Address),
    
    // Bootstrap 노드 설정
    bootstrap_nodes: ArrayList(bootstrap.BootstrapNodeConfig),
    
    // 설정
    max_peers: u32,
    discovery_interval_ms: u64,
    connection_timeout_ms: u64,
    
    // 상태
    is_running: bool,
    discovery_thread: ?std.Thread,
    connection_thread: ?std.Thread,

    const Self = @This();

    pub fn init(allocator: Allocator, port: u16) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .allocator = allocator,
            .port = port,
            .dht_node = null,
            .p2p_node = null,
            .upnp_client = null,
            .port_scanner = null,
            .broadcast_announcer = null,
            .discovered_peers = ArrayList(net.Address).init(allocator),
            .connecting_peers = ArrayList(net.Address).init(allocator),
            .connected_peers = ArrayList(net.Address).init(allocator),
            .bootstrap_nodes = ArrayList(bootstrap.BootstrapNodeConfig).init(allocator),
            .max_peers = 10,
            .discovery_interval_ms = 5000, // 5초마다 피어 발견
            .connection_timeout_ms = 10000, // 10초 연결 타임아웃
            .is_running = false,
            .discovery_thread = null,
            .connection_thread = null,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.stop();
        
        if (self.dht_node) |dht_node| {
            dht_node.deinit();
            self.allocator.destroy(dht_node);
        }
        
        if (self.p2p_node) |p2p_node| {
            p2p_node.deinit();
            self.allocator.destroy(p2p_node);
        }
        
        if (self.upnp_client) |upnp_client| {
            upnp_client.deinit();
        }
        
        if (self.port_scanner) |scanner| {
            scanner.deinit();
        }
        
        if (self.broadcast_announcer) |announcer| {
            announcer.deinit();
        }
        
        // Bootstrap 노드 설정 정리
        for (self.bootstrap_nodes.items) |*node| {
            node.deinit(self.allocator);
        }
        self.bootstrap_nodes.deinit();
        
        self.discovered_peers.deinit();
        self.connecting_peers.deinit();
        self.connected_peers.deinit();
        self.allocator.destroy(self);
    }

    /// 자동 발견 시스템 시작
    pub fn start(self: *Self, bootstrap_peer: ?net.Address) !void {
        if (self.is_running) return;
        
        print("🚀 Starting Auto Discovery on port {}\n", .{self.port});
        
        // P2P 노드 초기화
        const p2p_node = try p2p.P2PNode.init(self.allocator, self.port);
        self.p2p_node = try self.allocator.create(p2p.P2PNode);
        self.p2p_node.?.* = p2p_node;
        try self.p2p_node.?.start();
        print("🔗 P2P network started\n", .{});
        
        // DHT 초기화
        const dht_node = try dht.DHT.init(self.allocator, "127.0.0.1", self.port);
        self.dht_node = try self.allocator.create(dht.DHT);
        self.dht_node.?.* = dht_node;
        try self.dht_node.?.attachP2PNode(self.p2p_node.?);
        print("🌐 DHT started\n", .{});
        
        // UPnP 초기화 및 포트 포워딩 설정
        const upnp_client = try upnp.UPnPClient.init(self.allocator);
        self.upnp_client = upnp_client;
        
        // UPnP 디바이스 발견 시도
        const upnp_available = upnp_client.discover() catch |err| blk: {
            print("⚠️ UPnP discovery failed: {}\n", .{err});
            break :blk false;
        };
        
        if (upnp_available) {
            // 포트 포워딩 설정
            upnp_client.addPortMapping(
                self.port, 
                self.port, 
                upnp.UPnPClient.PortMapping.Protocol.TCP, 
                "Eastsea P2P Node", 
                0 // 무제한 임대
            ) catch |err| {
                print("⚠️ Failed to add UPnP port mapping: {}\n", .{err});
            };
            
            // 외부 IP 조회
            const external_ip = upnp_client.getExternalIP() catch |err| blk: {
                print("⚠️ Failed to get external IP: {}\n", .{err});
                break :blk null;
            };
            
            if (external_ip) |ip| {
                print("🌐 External IP: {s}\n", .{ip});
                self.allocator.free(ip);
            }
            
            print("🔧 UPnP port forwarding configured\n", .{});
        } else {
            print("⚠️ UPnP not available, manual port forwarding may be required\n", .{});
        }
        
        // Bootstrap 피어 추가 (있는 경우)
        if (bootstrap_peer) |peer| {
            const bootstrap_config = try bootstrap.BootstrapNodeConfig.init(
                self.allocator, 
                "127.0.0.1", // 임시로 localhost 사용
                peer.getPort()
            );
            try self.bootstrap_nodes.append(bootstrap_config);
            print("📡 Bootstrap peer added: {}\n", .{peer});
        }
        
        // 포트 스캐너 초기화
        const scanner = try port_scanner.PortScanner.scanLocalNetwork(self.allocator, self.port);
        self.port_scanner = scanner;
        print("🔍 Port scanner initialized\n", .{});
        
        // 브로드캐스트 공지자 초기화
        const announcer = try broadcast.BroadcastAnnouncer.init(self.allocator, self.port);
        self.broadcast_announcer = announcer;
        
        // 노드 ID 생성
        var node_id: [32]u8 = undefined;
        std.crypto.random.bytes(&node_id);
        
        try announcer.start(node_id);
        print("📢 Broadcast announcer started\n", .{});
        
        self.is_running = true;
        
        // 발견 스레드 시작
        self.discovery_thread = try std.Thread.spawn(.{}, discoveryLoop, .{self});
        
        // 연결 스레드 시작
        self.connection_thread = try std.Thread.spawn(.{}, connectionLoop, .{self});
        
        print("✅ Auto Discovery system started successfully\n", .{});
    }

    /// 자동 발견 시스템 중지
    pub fn stop(self: *Self) void {
        if (!self.is_running) return;
        
        print("🛑 Stopping Auto Discovery system...\n", .{});
        self.is_running = false;
        
        // 스레드 종료 대기
        if (self.discovery_thread) |thread| {
            thread.join();
            self.discovery_thread = null;
        }
        
        if (self.connection_thread) |thread| {
            thread.join();
            self.connection_thread = null;
        }
        
        // 각 컴포넌트 중지
        if (self.p2p_node) |p2p_node| p2p_node.stop();
        if (self.broadcast_announcer) |announcer| announcer.stop();
        
        print("✅ Auto Discovery system stopped\n", .{});
    }

    /// 발견된 피어 목록 반환
    pub fn getDiscoveredPeers(self: *Self) []const net.Address {
        return self.discovered_peers.items;
    }

    /// 연결된 피어 목록 반환
    pub fn getConnectedPeers(self: *Self) []const net.Address {
        return self.connected_peers.items;
    }

    /// 네트워크 상태 출력
    pub fn printStatus(self: *Self) void {
        print("📊 Auto Discovery Status: Running={}, Port={}, Discovered={}, Connected={}\n", .{
            self.is_running, 
            self.port, 
            self.discovered_peers.items.len, 
            self.connected_peers.items.len
        });
        
        // 상세 정보는 피어가 있을 때만 출력
        if (self.connected_peers.items.len > 0) {
            print("  🔗 Connected peers: ", .{});
            for (self.connected_peers.items, 0..) |peer, i| {
                if (i > 0) print(", ", .{});
                print("{}", .{peer});
            }
            print("\n", .{});
        }
        
        if (self.bootstrap_nodes.items.len > 0) {
            print("  🏠 Bootstrap nodes: {}\n", .{self.bootstrap_nodes.items.len});
        }
    }

    /// 특정 피어에 수동 연결 시도
    pub fn connectToPeer(self: *Self, peer_addr: net.Address) !void {
        // 이미 연결된 피어인지 확인
        for (self.connected_peers.items) |connected| {
            if (connected.eql(peer_addr)) {
                print("⚠️ Already connected to peer: {}\n", .{peer_addr});
                return;
            }
        }
        
        // 이미 연결 시도 중인지 확인
        for (self.connecting_peers.items) |connecting| {
            if (connecting.eql(peer_addr)) {
                print("⚠️ Already connecting to peer: {}\n", .{peer_addr});
                return;
            }
        }
        
        // 연결 시도 목록에 추가
        try self.connecting_peers.append(peer_addr);
        print("🔄 Attempting to connect to peer: {}\n", .{peer_addr});
    }

    /// 피어 발견 루프 (별도 스레드에서 실행)
    fn discoveryLoop(self: *Self) void {
        print("🔍 Discovery loop started\n", .{});
        
        while (self.is_running) {
            self.runDiscovery() catch |err| {
                print("❌ Discovery error: {}\n", .{err});
            };
            
            // 발견 간격만큼 대기
            std.Thread.sleep(self.discovery_interval_ms * std.time.ns_per_ms);
        }
        
        print("🔍 Discovery loop stopped\n", .{});
    }

    /// 연결 관리 루프 (별도 스레드에서 실행)
    fn connectionLoop(self: *Self) void {
        print("🔗 Connection loop started\n", .{});
        
        while (self.is_running) {
            self.manageConnections() catch |err| {
                print("❌ Connection management error: {}\n", .{err});
            };
            
            // 1초마다 연결 상태 확인
            std.Thread.sleep(1000 * std.time.ns_per_ms);
        }
        
        print("🔗 Connection loop stopped\n", .{});
    }

    /// 피어 발견 실행
    fn runDiscovery(self: *Self) !void {
        var new_peers = ArrayList(net.Address).init(self.allocator);
        defer new_peers.deinit();
        
        // DHT에서 피어 발견
        if (self.dht_node) |dht_node| {
            // DHT에서 가까운 노드들을 찾아서 추가
            const closest_nodes = dht_node.routing_table.findClosestNodes(dht_node.local_node.id, 10) catch blk: {
                // 에러 발생 시 빈 리스트 생성
                break :blk std.array_list.Managed(dht.DHTNode).init(self.allocator);
            };
            defer closest_nodes.deinit();
            
            for (closest_nodes.items) |node| {
                const addr = try net.Address.parseIp4(node.address, node.port);
                try new_peers.append(addr);
            }
        }
        
        // Bootstrap 노드들 추가
        for (self.bootstrap_nodes.items) |node| {
            const addr = try node.toNetAddress();
            try new_peers.append(addr);
        }
        
        // 포트 스캐너를 통한 로컬 네트워크 피어 발견
        if (self.port_scanner) |scanner| {
            // 주기적으로 포트 스캔 실행 (10번에 1번)
            const should_scan = @rem(@divTrunc(std.time.milliTimestamp(), 1000), 10) == 0;
            if (should_scan) {
                print("🔍 Running port scan for peer discovery...\n", .{});
                scanner.scan() catch |err| {
                    print("⚠️ Port scan failed: {}\n", .{err});
                };
                
                // 스캔 결과를 새로운 피어 목록에 추가
                for (scanner.getActivePeers()) |peer| {
                    try new_peers.append(peer);
                }
            }
        }
        
        // 브로드캐스트를 통한 피어 발견
        if (self.broadcast_announcer) |announcer| {
            for (announcer.getDiscoveredPeers()) |peer_info| {
                try new_peers.append(peer_info.address);
            }
        }
        
        // 새로운 피어들을 발견된 피어 목록에 추가
        for (new_peers.items) |new_peer| {
            var already_discovered = false;
            for (self.discovered_peers.items) |discovered| {
                if (discovered.eql(new_peer)) {
                    already_discovered = true;
                    break;
                }
            }
            
            if (!already_discovered) {
                try self.discovered_peers.append(new_peer);
                print("🆕 New peer discovered: {}\n", .{new_peer});
                
                // 자동으로 연결 시도
                if (self.connected_peers.items.len < self.max_peers) {
                    try self.connectToPeer(new_peer);
                }
            }
        }
    }

    /// 연결 관리
    fn manageConnections(self: *Self) !void {
        // 연결 시도 중인 피어들 처리
        var i: usize = 0;
        while (i < self.connecting_peers.items.len) {
            const peer = self.connecting_peers.items[i];
            
            // 실제 연결 시도
            const connected = self.attemptConnection(peer) catch false;
            
            if (connected) {
                // 연결 성공 - 연결된 피어 목록에 추가
                try self.connected_peers.append(peer);
                _ = self.connecting_peers.swapRemove(i);
                print("✅ Successfully connected to peer: {}\n", .{peer});
                
                // P2P 네트워크에 피어 추가
                if (self.p2p_node) |p2p_node| {
                    _ = p2p_node.connectToPeer(peer) catch |err| {
                        print("⚠️ Failed to connect to peer via P2P network: {}\n", .{err});
                    };
                }
            } else {
                // 연결 실패 - 시도 목록에서 제거
                _ = self.connecting_peers.swapRemove(i);
                print("❌ Failed to connect to peer: {}\n", .{peer});
            }
        }
        
        // 연결된 피어들의 상태 확인
        i = 0;
        while (i < self.connected_peers.items.len) {
            const peer = self.connected_peers.items[i];
            
            // 피어 연결 상태 확인 (ping 테스트)
            const is_alive = self.checkPeerAlive(peer) catch false;
            
            if (!is_alive) {
                // 연결이 끊어진 피어 제거
                _ = self.connected_peers.swapRemove(i);
                print("💔 Peer disconnected: {}\n", .{peer});
                
                // P2P 네트워크에서도 제거 (현재는 주소만 가지고 있어서 직접 제거 불가)
                // if (self.p2p_node) |p2p_node| {
                //     p2p_node.removePeer(peer) catch |err| {
                //         print("⚠️ Failed to remove peer from P2P network: {}\n", .{err});
                //     };
                // }
            } else {
                i += 1;
            }
        }
    }

    /// 피어 연결 시도
    fn attemptConnection(self: *Self, peer_addr: net.Address) !bool {
        _ = self; // 현재는 사용하지 않음
        
        // 실제 TCP 연결 시도
        const stream = net.tcpConnectToAddress(peer_addr) catch |err| {
            switch (err) {
                error.ConnectionRefused, error.NetworkUnreachable => return false,
                else => return err,
            }
        };
        defer stream.close();
        
        // 간단한 핸드셰이크 시도
        const handshake_msg = "EASTSEA_HANDSHAKE";
        _ = stream.write(handshake_msg) catch return false;
        
        var response_buf: [64]u8 = undefined;
        const bytes_read = stream.read(&response_buf) catch return false;
        
        if (bytes_read > 0) {
            const response = response_buf[0..bytes_read];
            if (std.mem.startsWith(u8, response, "EASTSEA_ACK")) {
                return true;
            }
        }
        
        return false;
    }

    /// 피어 생존 확인
    fn checkPeerAlive(self: *Self, peer_addr: net.Address) !bool {
        _ = self; // 현재는 사용하지 않음
        
        // 간단한 ping 테스트
        const stream = net.tcpConnectToAddress(peer_addr) catch return false;
        defer stream.close();
        
        const ping_msg = "PING";
        _ = stream.write(ping_msg) catch return false;
        
        var response_buf: [16]u8 = undefined;
        const bytes_read = stream.read(&response_buf) catch return false;
        
        if (bytes_read > 0) {
            const response = response_buf[0..bytes_read];
            return std.mem.startsWith(u8, response, "PONG");
        }
        
        return false;
    }
};

// 테스트 함수들
test "AutoDiscovery creation and destruction" {
    const allocator = std.testing.allocator;
    
    const auto_discovery = try AutoDiscovery.init(allocator, 8000);
    defer auto_discovery.deinit();
    
    try std.testing.expect(auto_discovery.port == 8000);
    try std.testing.expect(!auto_discovery.is_running);
}

test "AutoDiscovery peer management" {
    const allocator = std.testing.allocator;
    
    const auto_discovery = try AutoDiscovery.init(allocator, 8000);
    defer auto_discovery.deinit();
    
    // 테스트 피어 주소 생성
    const test_addr = try net.Address.parseIp4("127.0.0.1", 8001);
    
    // 발견된 피어 목록에 추가
    try auto_discovery.discovered_peers.append(test_addr);
    
    const discovered = auto_discovery.getDiscoveredPeers();
    try std.testing.expect(discovered.len == 1);
}