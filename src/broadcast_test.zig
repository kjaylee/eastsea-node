const std = @import("std");
const print = std.debug.print;
const net = std.net;

const broadcast = @import("network/broadcast.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        print("Usage: {s} <local_port>\n", .{args[0]});
        print("Example: {s} 8000\n", .{args[0]});
        return;
    }

    const local_port = std.fmt.parseInt(u16, args[1], 10) catch {
        print("❌ Invalid port number: {s}\n", .{args[1]});
        return;
    };

    print("📢 Eastsea Broadcast Announcer Test\n", .{});
    print("===================================\n", .{});
    print("Local port: {}\n", .{local_port});
    print("\n", .{});

    // 브로드캐스트 공지자 생성
    const announcer = try broadcast.BroadcastAnnouncer.init(allocator, local_port);
    defer announcer.deinit();

    // 설정 조정
    announcer.announce_interval_ms = 10000; // 10초마다 공지 (테스트용)
    announcer.peer_timeout_ms = 30000; // 30초 타임아웃

    print("⚙️ Configuration:\n", .{});
    print("  - Local port: {}\n", .{announcer.local_port});
    print("  - Broadcast port: {}\n", .{announcer.broadcast_port});
    print("  - Multicast group: {s}:{}\n", .{ announcer.multicast_group, announcer.multicast_port });
    print("  - Announce interval: {}ms\n", .{announcer.announce_interval_ms});
    print("  - Peer timeout: {}ms\n", .{announcer.peer_timeout_ms});
    print("\n", .{});

    // 노드 ID 생성
    var node_id: [32]u8 = undefined;
    std.crypto.random.bytes(&node_id);

    print("🆔 Node ID: ", .{});
    for (node_id[0..8]) |byte| {
        print("{x:0>2}", .{byte});
    }
    print("...\n\n", .{});

    // 브로드캐스트 시스템 시작
    print("🚀 Starting broadcast announcer...\n", .{});
    try announcer.start(node_id);

    print("✅ Broadcast announcer started successfully!\n", .{});
    print("\n📡 Broadcasting peer announcements...\n", .{});
    print("Press Ctrl+C to stop\n\n", .{});

    // 상태 모니터링 루프
    var iteration: u32 = 0;
    while (true) {
        std.Thread.sleep(5000 * std.time.ns_per_ms); // 5초마다 상태 출력

        iteration += 1;
        print("📊 Status Update #{}\n", .{iteration});
        print("===================\n", .{});
        announcer.printStatus();

        const peers = announcer.getDiscoveredPeers();
        if (peers.len > 0) {
            print("\n🔍 Detailed peer information:\n", .{});
            for (peers, 0..) |peer, i| {
                const age_seconds = @divTrunc(std.time.milliTimestamp() - peer.last_seen, 1000);
                print("  {}. Address: {}\n", .{ i + 1, peer.address });
                print("     Node ID: ", .{});
                for (peer.node_id[0..8]) |byte| {
                    print("{x:0>2}", .{byte});
                }
                print("...\n", .{});
                print("     Services: 0x{X}\n", .{peer.services});
                print("     Version: {}\n", .{peer.version});
                print("     Last seen: {}s ago\n", .{age_seconds});
                print("\n", .{});
            }
        } else {
            print("\n💡 Tips for testing:\n", .{});
            print("  - Run another instance: {s} {}\n", .{ args[0], local_port + 1 });
            print("  - Check firewall settings\n", .{});
            print("  - Ensure UDP ports are accessible\n", .{});
        }

        print("----------------------------------------\n\n", .{});

        // 10번 반복 후 종료 (무한 루프 방지)
        if (iteration >= 10) {
            print("🔄 Test completed after {} iterations\n", .{iteration});
            break;
        }
    }

    print("\n🛑 Stopping broadcast announcer...\n", .{});
    announcer.stop();

    print("✨ Broadcast test completed!\n", .{});

    // 최종 결과 요약
    print("\n📈 Final Results:\n", .{});
    print("================\n", .{});
    print("Total peers discovered: {}\n", .{announcer.getDiscoveredPeers().len});

    if (announcer.getDiscoveredPeers().len > 0) {
        print("Discovered peers:\n", .{});
        for (announcer.getDiscoveredPeers()) |peer| {
            print("  - {}\n", .{peer.address});
        }
    }
}
