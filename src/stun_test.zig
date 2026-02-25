const std = @import("std");
const net = std.net;
const print = std.debug.print;

const StunClient = @import("network/stun.zig").StunClient;
const NatTraversal = @import("network/stun.zig").NatTraversal;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 명령행 인수 파싱
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        print("Usage: {s} <local_port> [mode]\n", .{args[0]});
        print("Modes:\n", .{});
        print("  discover  - Discover public IP using STUN (default)\n", .{});
        print("  full      - Full NAT traversal test\n", .{});
        print("  server    - Test specific STUN server\n", .{});
        print("\nExample: {s} 8000\n", .{args[0]});
        print("Example: {s} 8000 full\n", .{args[0]});
        return;
    }

    // 포트 파싱
    const local_port = std.fmt.parseInt(u16, args[1], 10) catch {
        print("❌ Invalid port number: {s}\n", .{args[1]});
        return;
    };

    // 모드 파싱
    const mode = if (args.len >= 3) args[2] else "discover";

    print("🚀 Starting STUN/NAT Traversal Test\n");
    print("===================================\n");
    print("Local port: {d}\n", .{local_port});
    print("Mode: {s}\n", .{mode});
    print("\n");

    if (std.mem.eql(u8, mode, "discover")) {
        try runDiscoveryTest(allocator);
    } else if (std.mem.eql(u8, mode, "full")) {
        try runFullNatTraversalTest(allocator);
    } else if (std.mem.eql(u8, mode, "server")) {
        try runStunServerTest(allocator);
    } else {
        print("❌ Unknown mode: {s}\n", .{mode});
        return;
    }
}

/// 기본 공인 IP 발견 테스트
fn runDiscoveryTest(allocator: std.mem.Allocator) !void {
    print("🔍 Running Public IP Discovery Test\n");
    print("====================================\n");

    var nat_traversal = NatTraversal.init(allocator);
    defer nat_traversal.deinit();

    // 공인 IP 발견
    const success = nat_traversal.discoverPublicAddress() catch |err| {
        print("❌ Discovery failed: {}\n", .{err});
        return;
    };

    if (success) {
        print("\n✅ Discovery test completed successfully!\n");
        nat_traversal.printStatus();
    } else {
        print("\n❌ Discovery test failed\n");
    }
}

/// 전체 NAT 통과 테스트
fn runFullNatTraversalTest(allocator: std.mem.Allocator) !void {
    print("🚀 Running Full NAT Traversal Test\n");
    print("==================================\n");

    var nat_traversal = NatTraversal.init(allocator);
    defer nat_traversal.deinit();

    // 전체 NAT 통과 프로세스 실행
    const success = nat_traversal.performNatTraversal() catch |err| {
        print("❌ NAT traversal failed: {}\n", .{err});
        return;
    };

    if (success) {
        print("\n🎉 Full NAT traversal test completed successfully!\n");
        nat_traversal.printStatus();

        // 추가 테스트: 포트 매핑 정보
        try testPortMapping(&nat_traversal);
    } else {
        print("\n❌ NAT traversal test failed\n");
    }
}

/// 특정 STUN 서버 테스트
fn runStunServerTest(allocator: std.mem.Allocator) !void {
    print("🌐 Running STUN Server Test\n");
    print("===========================\n");

    const stun_servers = @import("network/stun.zig").PUBLIC_STUN_SERVERS;

    for (stun_servers, 0..) |server, i| {
        print("\n📡 Testing STUN Server {d}/{d}: {}:{}\n", .{ i + 1, stun_servers.len, server.host, server.port });
        print("----------------------------------------\n");

        var stun_client = StunClient.init(allocator, server.host, server.port) catch |err| {
            print("❌ Connection failed: {}\n", .{err});
            continue;
        };
        defer stun_client.deinit();

        const start_time = std.time.milliTimestamp();

        const public_address = stun_client.getPublicAddress() catch |err| {
            print("❌ STUN request failed: {}\n", .{err});
            continue;
        };

        const end_time = std.time.milliTimestamp();
        const duration = end_time - start_time;

        if (public_address) |addr| {
            print("✅ Success! Public address: {}\n", .{addr});
            print("⏱️  Response time: {}ms\n", .{duration});
        } else {
            print("❌ No public address returned\n");
        }
    }

    print("\n🏁 STUN server test completed\n");
}

/// 포트 매핑 테스트
fn testPortMapping(nat_traversal: *const NatTraversal) !void {
    print("🔌 Testing Port Mapping\n");
    print("=======================\n");

    if (nat_traversal.local_address == null or nat_traversal.public_address == null) {
        print("❌ Need both local and public addresses for port mapping test\n");
        return;
    }

    const local_addr = nat_traversal.local_address.?;
    const public_addr = nat_traversal.public_address.?;

    // 포트 정보 비교
    const local_port = local_addr.getPort();
    const public_port = public_addr.getPort();

    print("🏠 Local Port:  {d}\n", .{local_port});
    print("🌐 Public Port: {d}\n", .{public_port});

    if (local_port == public_port) {
        print("✅ Port mapping: Direct (no port translation)\n");
    } else {
        print("🔄 Port mapping: Translated ({d} -> {d})\n", .{ local_port, public_port });
    }

    // NAT 행동 분석
    try analyzeNatBehavior(local_addr, public_addr);
}

/// NAT 행동 분석
fn analyzeNatBehavior(local_addr: net.Address, public_addr: net.Address) !void {
    print("\n🧠 NAT Behavior Analysis\n");
    print("========================\n");

    // IP 주소 비교
    const local_ip = local_addr.any.in.addr;
    const public_ip = public_addr.any.in.addr;

    if (std.mem.eql(u8, &local_ip, &public_ip)) {
        print("📡 Network Type: Direct Internet Connection (No NAT)\n");
        print("   - Your device has a public IP address\n");
        print("   - No NAT traversal needed\n");
    } else {
        print("🛡️ Network Type: Behind NAT/Firewall\n");
        print("   - Your device is behind a NAT device\n");
        print("   - NAT traversal techniques may be needed\n");

        // 로컬 IP 주소 타입 분석
        try analyzeLocalIpType(local_addr);
    }

    // 포트 분석
    const local_port = local_addr.getPort();
    const public_port = public_addr.getPort();

    if (local_port == public_port) {
        print("🔌 Port Behavior: Preserved\n");
        print("   - NAT preserves port numbers\n");
    } else {
        print("🔄 Port Behavior: Translated\n");
        print("   - NAT changes port numbers\n");
        print("   - Port prediction may be difficult\n");
    }
}

/// 로컬 IP 주소 타입 분석
fn analyzeLocalIpType(local_addr: net.Address) !void {
    const ip_bytes = local_addr.any.in.addr;
    const ip_u32 = std.mem.readInt(u32, &ip_bytes, .big);

    // RFC 1918 사설 IP 주소 범위 확인
    const is_private = blk: {
        // 10.0.0.0/8 (10.0.0.0 - 10.255.255.255)
        if ((ip_u32 & 0xFF000000) == 0x0A000000) break :blk true;

        // 172.16.0.0/12 (172.16.0.0 - 172.31.255.255)
        if ((ip_u32 & 0xFFF00000) == 0xAC100000) break :blk true;

        // 192.168.0.0/16 (192.168.0.0 - 192.168.255.255)
        if ((ip_u32 & 0xFFFF0000) == 0xC0A80000) break :blk true;

        break :blk false;
    };

    if (is_private) {
        print("🏠 Local IP Type: Private (RFC 1918)\n");
        print("   - Typical home/office network\n");
    } else {
        print("🌐 Local IP Type: Public\n");
        print("   - Unusual configuration\n");
    }
}

/// 연결성 테스트
fn testConnectivity(allocator: std.mem.Allocator, public_addr: net.Address) !void {
    print("\n🔗 Testing Connectivity\n");
    print("=======================\n");

    // 간단한 연결성 테스트 (예: HTTP 요청)
    _ = allocator;
    _ = public_addr;

    print("📊 Connectivity test would be implemented here\n");
    print("   - Test inbound connections\n");
    print("   - Test outbound connections\n");
    print("   - Measure latency and throughput\n");
}

/// 데모 모드
fn runDemoMode() !void {
    print("🎮 Demo Mode\n");
    print("============\n");
    print("This would demonstrate:\n");
    print("1. 🔍 Public IP discovery\n");
    print("2. 🏠 Local IP detection\n");
    print("3. 🛡️ NAT type analysis\n");
    print("4. 🔌 Port mapping behavior\n");
    print("5. 🔗 Connectivity testing\n");
    print("\nRun with specific modes for actual tests.\n");
}

/// 성능 벤치마크
fn runPerformanceBenchmark(allocator: std.mem.Allocator) !void {
    print("\n⚡ Performance Benchmark\n");
    print("========================\n");

    const iterations = 10;
    var total_time: i64 = 0;
    var successful_requests: u32 = 0;

    print("🏃 Running {} STUN requests...\n", .{iterations});

    for (0..iterations) |i| {
        print("Request {}/{}... ", .{ i + 1, iterations });

        const start_time = std.time.milliTimestamp();

        var nat_traversal = NatTraversal.init(allocator);
        defer nat_traversal.deinit();

        const success = nat_traversal.discoverPublicAddress() catch false;

        const end_time = std.time.milliTimestamp();
        const duration = end_time - start_time;

        if (success) {
            print("✅ {}ms\n", .{duration});
            total_time += duration;
            successful_requests += 1;
        } else {
            print("❌ Failed\n");
        }

        // 요청 간 간격
        std.time.sleep(100 * std.time.ns_per_ms);
    }

    print("\n📊 Benchmark Results\n");
    print("====================\n");
    print("Total requests: {}\n", .{iterations});
    print("Successful: {}\n", .{successful_requests});
    print("Failed: {}\n", .{iterations - successful_requests});

    if (successful_requests > 0) {
        const avg_time = @divTrunc(total_time, successful_requests);
        print("Average response time: {}ms\n", .{avg_time});
        print("Success rate: {d:.1}%\n", .{@as(f64, @floatFromInt(successful_requests)) / @as(f64, @floatFromInt(iterations)) * 100.0});
    }
}
