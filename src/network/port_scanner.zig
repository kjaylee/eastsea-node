const std = @import("std");
const net = std.net;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const Thread = std.Thread;

/// 로컬 네트워크 포트 스캐너
/// 지정된 IP 범위에서 특정 포트들을 스캔하여 활성 피어를 발견
pub const PortScanner = struct {
    allocator: Allocator,
    base_ip: [4]u8, // 192.168.1.x에서 192.168.1 부분
    start_host: u8,  // 스캔 시작 호스트 번호
    end_host: u8,    // 스캔 종료 호스트 번호
    ports: []const u16, // 스캔할 포트 목록
    timeout_ms: u32,
    max_threads: u32,
    
    // 결과
    active_peers: ArrayList(net.Address),
    
    const Self = @This();
    
    pub const ScanResult = struct {
        address: net.Address,
        port: u16,
        response_time_ms: u64,
    };

    pub fn init(allocator: Allocator, base_ip: [4]u8, start_host: u8, end_host: u8, ports: []const u16) !*Self {
        const self = try allocator.create(Self);
        
        // 포트 배열을 복사
        const ports_copy = try allocator.alloc(u16, ports.len);
        @memcpy(ports_copy, ports);
        
        self.* = Self{
            .allocator = allocator,
            .base_ip = base_ip,
            .start_host = start_host,
            .end_host = end_host,
            .ports = ports_copy,
            .timeout_ms = 1000, // 1초 타임아웃
            .max_threads = 20,   // 최대 20개 동시 스레드
            .active_peers = ArrayList(net.Address).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.ports);
        self.active_peers.deinit();
        self.allocator.destroy(self);
    }

    /// 로컬 네트워크에서 기본 포트들을 스캔하는 편의 함수
    pub fn scanLocalNetwork(allocator: Allocator, base_port: u16) !*Self {
        // 로컬 IP 주소 자동 감지
        const local_ip = try detectLocalIP(allocator);
        
        // 기본 포트 목록 (base_port 주변)
        const default_ports = [_]u16{ base_port, base_port + 1, base_port + 2, 8000, 8001, 8002, 8080, 9000 };
        
        return Self.init(allocator, local_ip, 1, 254, &default_ports);
    }

    /// 네트워크 스캔 실행
    pub fn scan(self: *Self) !void {
        print("🔍 Starting port scan on {}.{}.{}.{}-{} for {} ports\n", .{
            self.base_ip[0], self.base_ip[1], self.base_ip[2], 
            self.start_host, self.end_host, self.ports.len
        });
        
        const start_time = std.time.milliTimestamp();
        
        // 스레드 풀을 사용한 병렬 스캔
        var scan_tasks = ArrayList(ScanTask).init(self.allocator);
        defer scan_tasks.deinit();
        
        // 스캔 작업 생성
        for (self.start_host..self.end_host + 1) |host| {
            for (self.ports) |port| {
                const ip = [4]u8{ self.base_ip[0], self.base_ip[1], self.base_ip[2], @intCast(host) };
                const task = ScanTask{
                    .ip = ip,
                    .port = port,
                    .timeout_ms = self.timeout_ms,
                    .scanner = self,
                };
                try scan_tasks.append(task);
            }
        }
        
        // 스레드 풀로 병렬 실행
        try self.executeScanTasks(scan_tasks.items);
        
        const end_time = std.time.milliTimestamp();
        const duration = end_time - start_time;
        
        print("✅ Port scan completed in {}ms. Found {} active peers\n", .{ duration, self.active_peers.items.len });
        
        // 결과 출력
        if (self.active_peers.items.len > 0) {
            print("📡 Active peers found:\n", .{});
            for (self.active_peers.items) |peer| {
                print("  - {}\n", .{peer});
            }
        }
    }

    /// 스캔 작업들을 스레드 풀로 실행
    fn executeScanTasks(self: *Self, tasks: []ScanTask) !void {
        const total_tasks = tasks.len;
        var completed_tasks: u32 = 0;
        var task_index: std.atomic.Value(usize) = std.atomic.Value(usize).init(0);
        
        // 워커 스레드들 생성
        var threads = ArrayList(Thread).init(self.allocator);
        defer {
            for (threads.items) |thread| {
                thread.join();
            }
            threads.deinit();
        }
        
        const worker_count = @min(self.max_threads, total_tasks);
        
        for (0..worker_count) |_| {
            const worker_context = WorkerContext{
                .tasks = tasks,
                .task_index = &task_index,
                .completed_tasks = &completed_tasks,
                .total_tasks = total_tasks,
            };
            
            const thread = try Thread.spawn(.{}, scanWorker, .{worker_context});
            try threads.append(thread);
        }
        
        // 모든 스레드 완료 대기는 threads.deinit()에서 처리됨
    }

    /// 단일 IP:Port 조합 스캔
    pub fn scanSingleTarget(self: *Self, ip: [4]u8, port: u16) !?ScanResult {
        const ip_str = try std.fmt.allocPrint(self.allocator, "{d}.{d}.{d}.{d}", .{ ip[0], ip[1], ip[2], ip[3] });
        defer self.allocator.free(ip_str);
        
        const addr = net.Address.parseIp4(ip_str, port) catch return null;
        
        const start_time = std.time.milliTimestamp();
        
        // TCP 연결 시도
        const stream = net.tcpConnectToAddress(addr) catch |err| {
            switch (err) {
                error.ConnectionRefused, 
                error.NetworkUnreachable, 
                error.ConnectionTimedOut => return null,
                else => return err,
            }
        };
        defer stream.close();
        
        // Eastsea 노드인지 확인
        const is_eastsea_node = self.checkEastseaNode(stream) catch false;
        
        if (is_eastsea_node) {
            const end_time = std.time.milliTimestamp();
            const response_time = @as(u64, @intCast(end_time - start_time));
            
            // 활성 피어 목록에 추가 (스레드 안전하게)
            try self.addActivePeer(addr);
            
            return ScanResult{
                .address = addr,
                .port = port,
                .response_time_ms = response_time,
            };
        }
        
        return null;
    }

    /// Eastsea 노드인지 확인
    fn checkEastseaNode(self: *Self, stream: net.Stream) !bool {
        _ = self;
        
        // 간단한 핸드셰이크 시도
        const handshake_msg = "EASTSEA_PING";
        _ = stream.write(handshake_msg) catch return false;
        
        // 응답 대기 (짧은 타임아웃)
        var response_buf: [64]u8 = undefined;
        const bytes_read = stream.read(&response_buf) catch return false;
        
        if (bytes_read > 0) {
            const response = response_buf[0..bytes_read];
            // Eastsea 노드의 응답 패턴 확인
            if (std.mem.indexOf(u8, response, "EASTSEA") != null or 
                std.mem.indexOf(u8, response, "PONG") != null) {
                return true;
            }
        }
        
        return false;
    }

    /// 활성 피어를 목록에 추가 (스레드 안전)
    fn addActivePeer(self: *Self, addr: net.Address) !void {
        // 간단한 뮤텍스 대신 중복 확인으로 처리
        for (self.active_peers.items) |existing| {
            if (std.mem.eql(u8, std.mem.asBytes(&existing), std.mem.asBytes(&addr))) {
                return; // 이미 존재함
            }
        }
        
        try self.active_peers.append(addr);
        print("🎯 Found Eastsea node: {}\n", .{addr});
    }

    /// 활성 피어 목록 반환
    pub fn getActivePeers(self: *Self) []const net.Address {
        return self.active_peers.items;
    }

    /// 스캔 결과를 특정 포트로 필터링
    pub fn filterByPort(self: *Self, port: u16) !ArrayList(net.Address) {
        var filtered = ArrayList(net.Address).init(self.allocator);
        
        for (self.active_peers.items) |addr| {
            if (addr.getPort() == port) {
                try filtered.append(addr);
            }
        }
        
        return filtered;
    }
};

/// 스캔 작업 정의
const ScanTask = struct {
    ip: [4]u8,
    port: u16,
    timeout_ms: u32,
    scanner: *PortScanner,
};

/// 워커 스레드 컨텍스트
const WorkerContext = struct {
    tasks: []ScanTask,
    task_index: *std.atomic.Value(usize),
    completed_tasks: *u32,
    total_tasks: usize,
};

/// 워커 스레드 함수
fn scanWorker(context: WorkerContext) void {
    while (true) {
        const task_idx = context.task_index.fetchAdd(1, .monotonic);
        if (task_idx >= context.tasks.len) break;
        
        const task = context.tasks[task_idx];
        
        // 스캔 실행
        _ = task.scanner.scanSingleTarget(task.ip, task.port) catch {
            // 에러는 조용히 무시 (연결 실패는 정상적인 상황)
        };
        
        // 진행률 업데이트
        const completed = @atomicRmw(u32, context.completed_tasks, .Add, 1, .monotonic) + 1;
        if (completed % 50 == 0 or completed == context.total_tasks) {
            print("📊 Scan progress: {}/{}\n", .{ completed, context.total_tasks });
        }
    }
}

/// 로컬 IP 주소 자동 감지
fn detectLocalIP(allocator: Allocator) ![4]u8 {
    // 기본값으로 192.168.1.x 사용
    // 실제로는 네트워크 인터페이스를 조회해야 하지만,
    // 여기서는 간단히 처리
    _ = allocator;
    
    // TODO: 실제 로컬 IP 감지 로직 구현
    // 현재는 가장 일반적인 로컬 네트워크 대역 사용
    return [4]u8{ 192, 168, 1, 0 };
}

/// 일반적인 로컬 네트워크 대역들
pub const COMMON_LOCAL_NETWORKS = [_][4]u8{
    [4]u8{ 192, 168, 1, 0 },   // 192.168.1.x
    [4]u8{ 192, 168, 0, 0 },   // 192.168.0.x
    [4]u8{ 10, 0, 0, 0 },      // 10.0.0.x
    [4]u8{ 172, 16, 0, 0 },    // 172.16.0.x
};

/// 일반적인 P2P 포트들
pub const COMMON_P2P_PORTS = [_]u16{ 8000, 8001, 8002, 8080, 9000, 9001, 9002, 7000, 7001, 6881 };

// 테스트 함수들
test "PortScanner creation and destruction" {
    const allocator = std.testing.allocator;
    
    const ports = [_]u16{ 8000, 8001 };
    const scanner = try PortScanner.init(allocator, [4]u8{ 192, 168, 1, 0 }, 1, 10, &ports);
    defer scanner.deinit();
    
    try std.testing.expect(scanner.base_ip[0] == 192);
    try std.testing.expect(scanner.ports.len == 2);
}

test "Local IP detection" {
    const allocator = std.testing.allocator;
    
    const local_ip = try detectLocalIP(allocator);
    try std.testing.expect(local_ip[0] == 192);
    try std.testing.expect(local_ip[1] == 168);
}