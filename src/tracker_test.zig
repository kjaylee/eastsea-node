const std = @import("std");
const print = std.debug.print;
const net = std.net;
const tracker = @import("network/tracker.zig");

const TrackerServer = tracker.TrackerServer;
const TrackerClient = tracker.TrackerClient;
const PeerInfo = tracker.PeerInfo;

/// Tracker 서버 테스트 실행
fn runTrackerServer(allocator: std.mem.Allocator, port: u16) !void {
    var server = try TrackerServer.init(allocator, port);
    defer server.deinit();

    print("🚀 Starting Tracker Server on port {d}...\n", .{port});

    // 별도 스레드에서 서버 실행
    const server_thread = try std.Thread.spawn(.{}, TrackerServer.start, .{&server});
    defer server_thread.join();

    // 메인 스레드에서 상태 모니터링
    var counter: u32 = 0;
    while (counter < 60) { // 60초 동안 실행
        std.Thread.sleep(1000000000); // 1초 대기
        counter += 1;

        if (counter % 10 == 0) {
            server.printStatus();
        }
    }

    server.stop();
}

/// Tracker 클라이언트 테스트 실행
fn runTrackerClient(allocator: std.mem.Allocator, client_port: u16, tracker_port: u16) !void {
    // 랜덤 노드 ID 생성
    var node_id: [32]u8 = undefined;
    std.crypto.random.bytes(&node_id);

    const client = TrackerClient.init(allocator, node_id, client_port);
    const tracker_address = net.Address.parseIp4("127.0.0.1", tracker_port) catch unreachable;

    print("🔌 Tracker Client starting on port {d}...\n", .{client_port});
    print("📍 Node ID: {s}\n", .{std.fmt.bytesToHex(node_id[0..8], .lower)});

    // 1. Tracker에 자신을 등록
    print("\n📢 Step 1: Announcing to tracker...\n", .{});
    client.announce(tracker_address) catch |err| {
        print("❌ Announce failed: {}\n", .{err});
        return;
    };

    // 2. 피어 목록 요청
    print("\n📥 Step 2: Getting peer list...\n", .{});
    const peers = client.getPeers(tracker_address) catch |err| {
        print("❌ Get peers failed: {}\n", .{err});
        return;
    };
    defer allocator.free(peers);

    print("📋 Received {d} peers:\n", .{peers.len});
    for (peers, 0..) |peer, i| {
        print("  {d}. {}:{d} (ID: {s})\n", .{ i + 1, peer.address, peer.port, std.fmt.bytesToHex(peer.node_id[0..8], .lower) });
    }

    // 3. 주기적으로 하트비트 전송
    print("\n💓 Step 3: Sending heartbeats...\n", .{});
    for (0..5) |i| {
        std.Thread.sleep(2000000000); // 2초 대기

        client.sendHeartbeat(tracker_address) catch |err| {
            print("❌ Heartbeat {d} failed: {}\n", .{ i + 1, err });
            continue;
        };

        print("✅ Heartbeat {d} sent successfully\n", .{i + 1});
    }

    print("🎉 Client test completed successfully!\n", .{});
}

/// 다중 클라이언트 테스트
fn runMultipleClients(allocator: std.mem.Allocator, tracker_port: u16, client_count: u32) !void {
    print("🚀 Starting {d} clients for stress test...\n", .{client_count});

    var threads = try allocator.alloc(std.Thread, client_count);
    defer allocator.free(threads);

    // 클라이언트 스레드 생성
    for (0..client_count) |i| {
        const client_port = @as(u16, @intCast(9000 + i));
        threads[i] = try std.Thread.spawn(.{}, runTrackerClient, .{ allocator, client_port, tracker_port });
    }

    // 모든 스레드 완료 대기
    for (threads) |thread| {
        thread.join();
    }

    print("✅ All {d} clients completed\n", .{client_count});
}

/// 통합 테스트 실행
fn runIntegratedTest(allocator: std.mem.Allocator) !void {
    const tracker_port: u16 = 7000;

    print("🧪 Starting Integrated Tracker Test\n", .{});
    print("==================================\n", .{});

    // 1. Tracker 서버 시작 (별도 스레드)
    var server = try TrackerServer.init(allocator, tracker_port);
    defer server.deinit();

    const server_thread = try std.Thread.spawn(.{}, TrackerServer.start, .{&server});
    defer {
        server.stop();
        server_thread.join();
    }

    // 서버 시작 대기
    std.Thread.sleep(1000000000); // 1초 대기

    // 2. 단일 클라이언트 테스트
    print("\n🔧 Phase 1: Single Client Test\n", .{});
    try runTrackerClient(allocator, 8001, tracker_port);

    // 3. 다중 클라이언트 테스트
    print("\n🔧 Phase 2: Multiple Clients Test\n", .{});
    try runMultipleClients(allocator, tracker_port, 3);

    // 4. 서버 상태 확인
    print("\n📊 Final Server Status:\n", .{});
    server.printStatus();

    print("\n🎉 Integrated test completed successfully!\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 명령행 인자 파싱
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        print("Usage: tracker_test <mode> [options]\n", .{});
        print("Modes:\n", .{});
        print("  server <port>              - Run tracker server\n", .{});
        print("  client <client_port> <tracker_port> - Run single client\n", .{});
        print("  multi <tracker_port> <count> - Run multiple clients\n", .{});
        print("  integrated                 - Run integrated test\n", .{});
        print("\nExamples:\n", .{});
        print("  tracker_test server 7000\n", .{});
        print("  tracker_test client 8001 7000\n", .{});
        print("  tracker_test multi 7000 5\n", .{});
        print("  tracker_test integrated\n", .{});
        return;
    }

    const mode = args[1];

    if (std.mem.eql(u8, mode, "server")) {
        if (args.len < 3) {
            print("❌ Server mode requires port number\n", .{});
            return;
        }

        const port = try std.fmt.parseInt(u16, args[2], 10);
        try runTrackerServer(allocator, port);
    } else if (std.mem.eql(u8, mode, "client")) {
        if (args.len < 4) {
            print("❌ Client mode requires client_port and tracker_port\n", .{});
            return;
        }

        const client_port = try std.fmt.parseInt(u16, args[2], 10);
        const tracker_port = try std.fmt.parseInt(u16, args[3], 10);
        try runTrackerClient(allocator, client_port, tracker_port);
    } else if (std.mem.eql(u8, mode, "multi")) {
        if (args.len < 4) {
            print("❌ Multi mode requires tracker_port and client_count\n", .{});
            return;
        }

        const tracker_port = try std.fmt.parseInt(u16, args[2], 10);
        const client_count = try std.fmt.parseInt(u32, args[3], 10);
        try runMultipleClients(allocator, tracker_port, client_count);
    } else if (std.mem.eql(u8, mode, "integrated")) {
        try runIntegratedTest(allocator);
    } else {
        print("❌ Unknown mode: {s}\n", .{mode});
        print("Available modes: server, client, multi, integrated\n", .{});
    }
}
