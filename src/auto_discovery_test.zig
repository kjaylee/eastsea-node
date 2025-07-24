const std = @import("std");
const net = std.net;
const print = std.debug.print;

const AutoDiscovery = @import("network/auto_discovery.zig").AutoDiscovery;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 명령행 인수 파싱
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        print("Usage: {s} <port> [bootstrap_host:port]\n", .{args[0]});
        print("Example: {s} 8000\n", .{args[0]});
        print("Example: {s} 8001 127.0.0.1:8000\n", .{args[0]});
        return;
    }

    // 포트 파싱
    const port = std.fmt.parseInt(u16, args[1], 10) catch {
        print("❌ Invalid port number: {s}\n", .{args[1]});
        return;
    };

    // Bootstrap 피어 파싱 (선택적)
    var bootstrap_peer: ?net.Address = null;
    if (args.len >= 3) {
        // 호스트:포트 형식 파싱
        var parts = std.mem.splitScalar(u8, args[2], ':');
        const host = parts.next() orelse {
            print("❌ Invalid bootstrap address format: {s}\n", .{args[2]});
            return;
        };
        const port_str = parts.next() orelse {
            print("❌ Invalid bootstrap address format: {s}\n", .{args[2]});
            return;
        };
        
        const bootstrap_port = std.fmt.parseInt(u16, port_str, 10) catch {
            print("❌ Invalid bootstrap port: {s}\n", .{port_str});
            return;
        };
        
        bootstrap_peer = net.Address.parseIp4(host, bootstrap_port) catch {
            print("❌ Failed to parse bootstrap address: {s}:{d}\n", .{ host, bootstrap_port });
            return;
        };
    }

    print("🚀 Starting Eastsea Auto Discovery Test\n", .{});
    print("=====================================\n", .{});
    print("Port: {d}\n", .{port});
    if (bootstrap_peer) |peer| {
        print("Bootstrap peer: {}\n", .{peer});
    } else {
        print("Mode: Bootstrap server\n", .{});
    }
    print("\n", .{});

    // Auto Discovery 시스템 초기화
    const auto_discovery = AutoDiscovery.init(allocator, port) catch |err| {
        print("❌ Failed to initialize Auto Discovery: {any}\n", .{err});
        return;
    };
    defer auto_discovery.deinit();

    // 시스템 시작
    auto_discovery.start(bootstrap_peer) catch |err| {
        print("❌ Failed to start Auto Discovery: {any}\n", .{err});
        return;
    };
    defer auto_discovery.stop();

    print("✅ Auto Discovery system is running...\n", .{});
    print("Press Ctrl+C to stop\n\n", .{});

    // 신호 처리를 위한 설정
    var should_exit = false;
    
    // 테스트 시간 제한 (30초)
    const test_duration_seconds = 30;
    const start_time = std.time.timestamp();
    
    // 메인 루프
    var iteration: u32 = 0;
    while (!should_exit) {
        iteration += 1;
        
        // 10초마다 상태 출력 (빈도 감소)
        if (iteration % 10 == 0) {
            auto_discovery.printStatus();
        }
        
        // 시간 제한 확인
        const current_time = std.time.timestamp();
        if (current_time - start_time >= test_duration_seconds) {
            print("⏰ Test time limit reached ({d}s), shutting down...\n", .{test_duration_seconds});
            should_exit = true;
            break;
        }
        
        // 사용자 입력 확인 (non-blocking)
        if (checkForExit()) {
            should_exit = true;
            break;
        }
        
        // 1초 대기
        std.time.sleep(1 * std.time.ns_per_s);
    }

    print("\n🛑 Shutting down Auto Discovery system...\n", .{});
}

/// 종료 신호 확인 (간단한 구현)
fn checkForExit() bool {
    // 실제 구현에서는 신호 처리를 사용할 수 있지만,
    // 여기서는 간단히 타임아웃으로 처리
    return false;
}

// 테스트 시나리오 실행
fn runTestScenarios(auto_discovery: *AutoDiscovery) !void {
    print("🧪 Running test scenarios...\n", .{});
    
    // 시나리오 1: 로컬 피어 추가
    const local_peer = try net.Address.parseIp4("127.0.0.1", 8002);
    try auto_discovery.connectToPeer(local_peer);
    
    // 시나리오 2: 상태 확인
    std.time.sleep(2 * std.time.ns_per_s);
    auto_discovery.printStatus();
    
    // 시나리오 3: 여러 피어 시뮬레이션
    const test_peers = [_]net.Address{
        try net.Address.parseIp4("127.0.0.1", 8003),
        try net.Address.parseIp4("127.0.0.1", 8004),
        try net.Address.parseIp4("127.0.0.1", 8005),
    };
    
    for (test_peers) |peer| {
        try auto_discovery.connectToPeer(peer);
        std.time.sleep(500 * std.time.ns_per_ms); // 0.5초 간격
    }
    
    // 최종 상태 출력
    std.time.sleep(3 * std.time.ns_per_s);
    auto_discovery.printStatus();
    
    print("✅ Test scenarios completed\n", .{});
}

// 데모 모드 실행
fn runDemoMode(auto_discovery: *AutoDiscovery) !void {
    print("🎮 Demo mode started\n", .{});
    print("This will simulate network activity...\n\n", .{});
    
    var demo_iteration: u32 = 0;
    while (demo_iteration < 30) { // 30초간 데모 실행
        demo_iteration += 1;
        
        // 5초마다 상태 출력
        if (demo_iteration % 5 == 0) {
            auto_discovery.printStatus();
            
            // 가상 피어 추가 (데모용)
            if (demo_iteration == 10) {
                print("🎭 Simulating peer discovery...\n", .{});
                const demo_peer = try net.Address.parseIp4("127.0.0.1", 9000 + demo_iteration);
                try auto_discovery.connectToPeer(demo_peer);
            }
        }
        
        std.time.sleep(1 * std.time.ns_per_s);
    }
    
    print("🎮 Demo mode completed\n", .{});
}

// 성능 테스트 모드
fn runPerformanceTest(auto_discovery: *AutoDiscovery) !void {
    print("⚡ Performance test started\n", .{});
    
    const start_time = std.time.milliTimestamp();
    
    // 대량 피어 연결 시뮬레이션
    for (0..100) |i| {
        const port_offset: u16 = @intCast(i);
        const test_peer = try net.Address.parseIp4("127.0.0.1", 9000 + port_offset);
        try auto_discovery.connectToPeer(test_peer);
        
        if (i % 10 == 0) {
            print("📊 Added {d} peers\n", .{i + 1});
        }
    }
    
    const end_time = std.time.milliTimestamp();
    const duration = end_time - start_time;
    
    print("⚡ Performance test completed in {d}ms\n", .{duration});
    auto_discovery.printStatus();
}