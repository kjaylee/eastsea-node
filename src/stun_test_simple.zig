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
        print("Modes: discover, full, server\n", .{});
        print("Example: {s} 8000\n", .{args[0]});
        return;
    }

    // 포트 파싱
    const local_port = std.fmt.parseInt(u16, args[1], 10) catch {
        print("Invalid port number: {s}\n", .{args[1]});
        return;
    };

    // 모드 파싱
    const mode = if (args.len >= 3) args[2] else "discover";

    print("Starting STUN/NAT Traversal Test\n", .{});
    print("Local port: {d}\n", .{local_port});
    print("Mode: {s}\n", .{mode});

    if (std.mem.eql(u8, mode, "discover")) {
        try runDiscoveryTest(allocator);
    } else if (std.mem.eql(u8, mode, "full")) {
        try runFullNatTraversalTest(allocator);
    } else if (std.mem.eql(u8, mode, "server")) {
        try runStunServerTest(allocator);
    } else {
        print("Unknown mode: {s}\n", .{mode});
        return;
    }
}

/// 기본 공인 IP 발견 테스트
fn runDiscoveryTest(allocator: std.mem.Allocator) !void {
    print("Running Public IP Discovery Test\n", .{});

    var nat_traversal = NatTraversal.init(allocator);
    defer nat_traversal.deinit();

    // 공인 IP 발견
    const success = nat_traversal.discoverPublicAddress() catch |err| {
        print("Discovery failed: {}\n", .{err});
        return;
    };

    if (success) {
        print("Discovery test completed successfully!\n", .{});
        nat_traversal.printStatus();
    } else {
        print("Discovery test failed\n", .{});
    }
}

/// 전체 NAT 통과 테스트
fn runFullNatTraversalTest(allocator: std.mem.Allocator) !void {
    print("Running Full NAT Traversal Test\n", .{});

    var nat_traversal = NatTraversal.init(allocator);
    defer nat_traversal.deinit();

    // 전체 NAT 통과 프로세스 실행
    const success = nat_traversal.performNatTraversal() catch |err| {
        print("NAT traversal failed: {}\n", .{err});
        return;
    };

    if (success) {
        print("Full NAT traversal test completed successfully!\n", .{});
        nat_traversal.printStatus();
    } else {
        print("NAT traversal test failed\n", .{});
    }
}

/// 특정 STUN 서버 테스트
fn runStunServerTest(allocator: std.mem.Allocator) !void {
    print("Running STUN Server Test\n", .{});

    const stun_servers = @import("network/stun.zig").PUBLIC_STUN_SERVERS;

    for (stun_servers, 0..) |server, i| {
        print("Testing STUN Server {d}/{d}: {s}:{d}\n", .{ i + 1, stun_servers.len, server.host, server.port });

        var stun_client = StunClient.init(allocator, server.host, server.port) catch |err| {
            print("Connection failed: {}\n", .{err});
            continue;
        };
        defer stun_client.deinit();

        const start_time = std.time.milliTimestamp();
        
        const public_address = stun_client.getPublicAddress() catch |err| {
            print("STUN request failed: {}\n", .{err});
            continue;
        };

        const end_time = std.time.milliTimestamp();
        const duration = end_time - start_time;

        if (public_address) |addr| {
            print("Success! Public address: {}\n", .{addr});
            print("Response time: {}ms\n", .{duration});
        } else {
            print("No public address returned\n", .{});
        }
    }

    print("STUN server test completed\n", .{});
}