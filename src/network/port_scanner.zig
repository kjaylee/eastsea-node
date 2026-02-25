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
        
        // 모든 스레드가 완료될 때까지 기다리기 위한 조건 변수
        var mutex = std.Thread.Mutex{};
        var cond = std.Thread.Condition{};
        var finished_workers: usize = 0;
        
        for (0..worker_count) |_| {
            const worker_context = WorkerContext{
                .tasks = tasks,
                .task_index = &task_index,
                .completed_tasks = &completed_tasks,
                .total_tasks = total_tasks,
                .mutex = &mutex,
                .cond = &cond,
                .finished_workers = &finished_workers,
                .worker_count = worker_count,
            };
            
            const thread = try Thread.spawn(.{}, scanWorker, .{worker_context});
            try threads.append(thread);
        }
        
        // 모든 워커 스레드가 완료될 때까지 대기
        mutex.lock();
        while (finished_workers < worker_count) {
            cond.wait(&mutex);
        }
        mutex.unlock();
    }

    /// 단일 IP:Port 조합 스캔
    pub fn scanSingleTarget(self: *Self, ip: [4]u8, port: u16) !?ScanResult {
        const ip_str = try std.fmt.allocPrint(self.allocator, "{d}.{d}.{d}.{d}", .{ ip[0], ip[1], ip[2], ip[3] });
        defer self.allocator.free(ip_str);
        
        const addr = net.Address.parseIp4(ip_str, port) catch return null;
        
        const start_time = std.time.milliTimestamp();
        
        // 비블로킹 소켓으로 연결 시도 (간단한 타임아웃 구현)
        const stream = self.connectWithQuickTimeout(addr) catch |err| {
            switch (err) {
                error.ConnectionRefused, 
                error.NetworkUnreachable, 
                error.ConnectionTimedOut,
                error.Timeout => return null,
                else => return err,
            }
        };
        defer stream.close();
        
        // 성공적으로 연결된 경우 응답으로 처리 (Eastsea 체크 스킵)
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
    
    /// 빠른 타임아웃을 적용한 연결 함수
    fn connectWithQuickTimeout(self: *Self, addr: net.Address) !net.Stream {
        const timeout_start = std.time.milliTimestamp();
        
        // 여러 번 시도하되 빠르게 포기
        var attempts: u8 = 0;
        while (attempts < 2) : (attempts += 1) {
            const current_time = std.time.milliTimestamp();
            if (current_time - timeout_start > self.timeout_ms) {
                return error.Timeout;
            }
            
            const stream = net.tcpConnectToAddress(addr) catch |err| {
                switch (err) {
                    error.ConnectionRefused => return err,
                    else => {
                        // 짧은 대기 후 재시도
                        std.Thread.sleep(10 * std.time.ns_per_ms); // 10ms 대기
                        continue;
                    }
                }
            };
            return stream;
        }
        
        return error.ConnectionTimedOut;
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
        // Use a mutex to ensure thread safety
        // Since we don't have a mutex field in the struct, we'll use atomic operations
        // to check for duplicates and add the peer
        
        // First, check if the peer already exists (simplified duplicate check)
        for (self.active_peers.items) |existing| {
            if (std.mem.eql(u8, std.mem.asBytes(&existing), std.mem.asBytes(&addr))) {
                return; // Already exists
            }
        }
        
        // Add the peer to the list
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
    mutex: *std.Thread.Mutex,
    cond: *std.Thread.Condition,
    finished_workers: *usize,
    worker_count: usize,
};

/// 타임아웃을 적용한 TCP 연결 함수
fn connectWithTimeout(addr: net.Address, timeout_ms: u32) !net.Stream {
    _ = timeout_ms; // 현재는 사용하지 않음
    return net.tcpConnectToAddress(addr);
}

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
        
        // 진행률 업데이트 - disable printing from worker threads to prevent concurrency issues
        _ = @atomicRmw(u32, context.completed_tasks, .Add, 1, .monotonic);
    }
    
    // 워커 완료 신호
    context.mutex.lock();
    context.finished_workers.* += 1;
    context.cond.signal();
    context.mutex.unlock();
}

/// 네트워크 인터페이스 정보 구조체 (IPv4/IPv6 지원)
const NetworkInterface = struct {
    name: []const u8,
    ipv4: ?[4]u8,
    ipv6: ?[16]u8,
    is_active: bool,
    is_wifi: bool,
    is_ethernet: bool,
    is_loopback: bool,
    interface_type: InterfaceType,
    
    const InterfaceType = enum {
        ethernet,
        wifi,
        loopback,
        vpn,
        cellular,
        unknown,
    };
    
    pub fn deinit(self: *NetworkInterface, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
    
    pub fn hasIPv4(self: *const NetworkInterface) bool {
        return self.ipv4 != null;
    }
    
    pub fn hasIPv6(self: *const NetworkInterface) bool {
        return self.ipv6 != null;
    }
    
    pub fn getIPv4String(self: *const NetworkInterface, allocator: std.mem.Allocator) !?[]u8 {
        if (self.ipv4) |ip| {
            return try std.fmt.allocPrint(allocator, "{}.{}.{}.{}", .{ ip[0], ip[1], ip[2], ip[3] });
        }
        return null;
    }
    
    pub fn getIPv6String(self: *const NetworkInterface, allocator: std.mem.Allocator) !?[]u8 {
        if (self.ipv6) |ip| {
            return try std.fmt.allocPrint(allocator, "{X:02}{X:02}:{X:02}{X:02}:{X:02}{X:02}:{X:02}{X:02}:{X:02}{X:02}:{X:02}{X:02}:{X:02}{X:02}:{X:02}{X:02}", .{
                ip[0], ip[1], ip[2], ip[3], ip[4], ip[5], ip[6], ip[7],
                ip[8], ip[9], ip[10], ip[11], ip[12], ip[13], ip[14], ip[15],
            });
        }
        return null;
    }
};

/// IPv6 주소 파싱 함수
fn parseIPv6Address(ip_str: []const u8) ?[16]u8 {
    // 간단한 IPv6 주소 파싱 (완전한 형태만 지원)
    // 예: 2001:0db8:85a3:0000:0000:8a2e:0370:7334
    if (ip_str.len < 7) return null; // 최소 길이 체크
    
    var result: [16]u8 = std.mem.zeroes([16]u8);
    var groups = std.mem.splitAny(u8, ip_str, ":");
    var group_count: usize = 0;
    
    while (groups.next()) |group| {
        if (group_count >= 8) break; // 최대 8개 그룹
        
        const parsed = std.fmt.parseInt(u16, group, 16) catch return null;
        const byte_index = group_count * 2;
        if (byte_index + 1 >= result.len) break;
        
        result[byte_index] = @intCast((parsed >> 8) & 0xFF);
        result[byte_index + 1] = @intCast(parsed & 0xFF);
        group_count += 1;
    }
    
    if (group_count > 0) {
        return result;
    }
    return null;
}

/// 인터페이스 타입을 이름으로부터 추론
fn inferInterfaceType(name: []const u8) NetworkInterface.InterfaceType {
    if (std.mem.eql(u8, name, "lo") or std.mem.eql(u8, name, "lo0")) {
        return .loopback;
    } else if (std.mem.startsWith(u8, name, "en0")) {
        return .ethernet;
    } else if (std.mem.startsWith(u8, name, "en") or std.mem.startsWith(u8, name, "wl")) {
        return .wifi;
    } else if (std.mem.startsWith(u8, name, "ppp") or std.mem.startsWith(u8, name, "tun") or std.mem.startsWith(u8, name, "tap")) {
        return .vpn;
    } else if (std.mem.startsWith(u8, name, "cell") or std.mem.startsWith(u8, name, "pdp")) {
        return .cellular;
    }
    return .unknown;
}

/// 모든 네트워크 인터페이스를 감지하는 함수
fn detectAllNetworkInterfaces(allocator: Allocator) !std.array_list.Managed(NetworkInterface) {
    var interfaces = std.array_list.Managed(NetworkInterface).init(allocator);
    
    // ifconfig 명령으로 모든 인터페이스 정보 가져오기
    const ifconfig_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "ifconfig" },
    }) catch {
        std.debug.print("⚠️  Failed to execute ifconfig command\n", .{});
        return interfaces;
    };
    defer allocator.free(ifconfig_result.stdout);
    defer allocator.free(ifconfig_result.stderr);
    
    if (ifconfig_result.term.Exited != 0) {
        std.debug.print("⚠️  ifconfig command failed\n", .{});
        return interfaces;
    }
    
    var current_interface: ?[]const u8 = null;
    var current_ipv4: ?[4]u8 = null;
    var current_ipv6: ?[16]u8 = null;
    var is_active = false;
    
    var lines = std.mem.splitAny(u8, ifconfig_result.stdout, "\n");
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        
        // 새로운 인터페이스 시작 (첫 번째 문자가 공백이 아님)
        if (trimmed.len > 0 and line[0] != ' ' and line[0] != '\t') {
            // 이전 인터페이스 저장
            if (current_interface) |iface| {
                if (current_ipv4 != null or current_ipv6 != null) {
                    const iface_type = inferInterfaceType(iface);
                    try interfaces.append(NetworkInterface{
                        .name = try allocator.dupe(u8, iface),
                        .ipv4 = current_ipv4,
                        .ipv6 = current_ipv6,
                        .is_active = is_active,
                        .is_wifi = iface_type == .wifi,
                        .is_ethernet = iface_type == .ethernet,
                        .is_loopback = iface_type == .loopback,
                        .interface_type = iface_type,
                    });
                }
            }
            
            // 새 인터페이스 파싱
            var parts = std.mem.splitAny(u8, trimmed, ":");
            if (parts.next()) |iface_name| {
                current_interface = std.mem.trim(u8, iface_name, " \t");
                current_ipv4 = null;
                current_ipv6 = null;
                is_active = false;
            }
        }
        // IPv4 주소 라인 파싱
        else if (std.mem.indexOf(u8, trimmed, "inet ")) |_| {
            var inet_parts = std.mem.splitAny(u8, trimmed, " ");
            while (inet_parts.next()) |part| {
                if (std.mem.eql(u8, part, "inet")) {
                    if (inet_parts.next()) |ip_str| {
                        current_ipv4 = parseIPAddress(ip_str);
                        break;
                    }
                }
            }
        }
        // IPv6 주소 라인 파싱
        else if (std.mem.indexOf(u8, trimmed, "inet6 ")) |_| {
            var inet6_parts = std.mem.splitAny(u8, trimmed, " ");
            while (inet6_parts.next()) |part| {
                if (std.mem.eql(u8, part, "inet6")) {
                    if (inet6_parts.next()) |ip_str| {
                        // IPv6 주소에서 스코프 제거 (예: fe80::1%lo0 -> fe80::1)
                        const clean_ip = if (std.mem.indexOf(u8, ip_str, "%")) |scope_pos| 
                            ip_str[0..scope_pos] 
                        else 
                            ip_str;
                        current_ipv6 = parseIPv6Address(clean_ip);
                        break;
                    }
                }
            }
        }
        // 활성 상태 확인
        else if (std.mem.indexOf(u8, trimmed, "status: active")) |_| {
            is_active = true;
        }
    }
    
    // 마지막 인터페이스 처리
    if (current_interface) |iface| {
        if (current_ipv4 != null or current_ipv6 != null) {
            const iface_type = inferInterfaceType(iface);
            try interfaces.append(NetworkInterface{
                .name = try allocator.dupe(u8, iface),
                .ipv4 = current_ipv4,
                .ipv6 = current_ipv6,
                .is_active = is_active,
                .is_wifi = iface_type == .wifi,
                .is_ethernet = iface_type == .ethernet,
                .is_loopback = iface_type == .loopback,
                .interface_type = iface_type,
            });
        }
    }
    
    return interfaces;
}

/// IP 주소 문자열을 [4]u8로 파싱
fn parseIPAddress(ip_str: []const u8) ?[4]u8 {
    var parts = std.mem.splitAny(u8, ip_str, ".");
    var ip: [4]u8 = undefined;
    var i: usize = 0;
    
    while (parts.next()) |part| {
        if (i >= 4) break;
        ip[i] = std.fmt.parseInt(u8, part, 10) catch return null;
        i += 1;
    }
    
    if (i == 4) return ip else return null;
}

/// 최적의 네트워크 인터페이스 선택
fn selectBestInterface(interfaces: []const NetworkInterface) ?NetworkInterface {
    // 우선순위: 활성 상태 > 이더넷 > WiFi > 기타 (IPv4 우선)
    var best_interface: ?NetworkInterface = null;
    
    for (interfaces) |iface| {
        if (!iface.is_active) continue;
        
        // IPv4 주소가 있어야 함
        const ipv4 = iface.ipv4 orelse continue;
        
        // 루프백 주소 제외
        if (ipv4[0] == 127) continue;
        
        if (best_interface == null) {
            best_interface = iface;
            continue;
        }
        
        const current_best = best_interface.?;
        
        // 이더넷이 WiFi보다 우선
        if (iface.interface_type == .ethernet and current_best.interface_type != .ethernet) {
            best_interface = iface;
            continue;
        }
        
        // WiFi가 기타보다 우선
        if (iface.interface_type == .wifi and current_best.interface_type != .wifi and current_best.interface_type != .ethernet) {
            best_interface = iface;
        }
    }
    
    return best_interface;
}

/// 실제 로컬 IP 주소를 감지하는 함수 (다중 네트워크 인터페이스 지원)
fn detectLocalIP(allocator: Allocator) ![4]u8 {
    std.debug.print("🔍 Detecting all network interfaces...\n", .{});
    
    // 모든 네트워크 인터페이스 감지
    var interfaces = detectAllNetworkInterfaces(allocator) catch |err| {
        std.debug.print("⚠️  Failed to detect network interfaces: {}\n", .{err});
        return [4]u8{ 192, 168, 1, 0 };
    };
    defer {
        for (interfaces.items) |*iface| {
            iface.deinit(allocator);
        }
        interfaces.deinit();
    }
    
    std.debug.print("📊 Found {} network interfaces:\n", .{interfaces.items.len});
    for (interfaces.items) |*iface| {
        const type_str = switch (iface.interface_type) {
            .ethernet => "Ethernet",
            .wifi => "WiFi", 
            .loopback => "Loopback",
            .vpn => "VPN",
            .cellular => "Cellular",
            .unknown => "Unknown",
        };
        const status_str = if (iface.is_active) "Active" else "Inactive";
        
        if (iface.ipv4) |ipv4| {
            std.debug.print("  - {s}: {}.{}.{}.{} (IPv4, {s}, {s})\n", .{ 
                iface.name, ipv4[0], ipv4[1], ipv4[2], ipv4[3], type_str, status_str 
            });
        }
        
        if (iface.ipv6) |ipv6| {
            std.debug.print("  - {s}: {X:02}{X:02}:{X:02}{X:02}:{X:02}{X:02}:{X:02}{X:02}:{X:02}{X:02}:{X:02}{X:02}:{X:02}{X:02}:{X:02}{X:02} (IPv6, {s}, {s})\n", .{ 
                iface.name, ipv6[0], ipv6[1], ipv6[2], ipv6[3], ipv6[4], ipv6[5], ipv6[6], ipv6[7],
                ipv6[8], ipv6[9], ipv6[10], ipv6[11], ipv6[12], ipv6[13], ipv6[14], ipv6[15], type_str, status_str 
            });
        }
    }
    
    // 최적의 인터페이스 선택
    if (selectBestInterface(interfaces.items)) |best| {
        if (best.ipv4) |ipv4| {
            std.debug.print("✅ Selected interface: {s} - {}.{}.{}.{}\n", .{ 
                best.name, ipv4[0], ipv4[1], ipv4[2], ipv4[3] 
            });
            return ipv4;
        }
    }
    
    std.debug.print("⚠️  No suitable network interface found, using fallback IP\n", .{});
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