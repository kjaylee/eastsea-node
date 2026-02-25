const std = @import("std");
const print = std.debug.print;
const net = std.net;

const port_scanner = @import("network/port_scanner.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        print("Usage: {s} <base_port>\n", .{args[0]});
        print("Example: {s} 8000\n", .{args[0]});
        return;
    }

    const base_port = std.fmt.parseInt(u16, args[1], 10) catch {
        print("❌ Invalid port number: {s}\n", .{args[1]});
        return;
    };

    print("🔍 Eastsea Port Scanner Test\n", .{});
    print("============================\n", .{});
    print("Base port: {}\n", .{base_port});
    print("\n", .{});

    // 로컬 네트워크 스캔 (제한된 범위)
    print("🌐 Starting local network scan...\n", .{});
    const scanner = port_scanner.PortScanner.scanLocalNetwork(allocator, base_port) catch |err| {
        print("❌ Failed to create scanner: {}\n", .{err});
        return;
    };
    defer scanner.deinit();

    // 스캔 설정 조정 - 범위를 현재 호스트만으로 제한
    scanner.timeout_ms = 50; // 매우 빠른 스캔을 위해 타임아웃 단축
    scanner.max_threads = 5; // 스레드 수 조정
    scanner.start_host = scanner.base_ip[3]; // 현재 IP만
    scanner.end_host = scanner.base_ip[3]; // 현재 IP만

    print("📊 Scan configuration:\n", .{});
    print("  - IP range: {}.{}.{}.{}-{}\n", .{ scanner.base_ip[0], scanner.base_ip[1], scanner.base_ip[2], scanner.start_host, scanner.end_host });
    print("  - Ports: ", .{});
    for (scanner.ports, 0..) |port, i| {
        if (i > 0) print(", ", .{});
        print("{}", .{port});
    }
    print("\n", .{});
    print("  - Timeout: {}ms\n", .{scanner.timeout_ms});
    print("  - Max threads: {}\n", .{scanner.max_threads});
    print("\n", .{});

    // 스캔 실행 (간단한 수동 스캔으로 대체)
    const start_time = std.time.milliTimestamp();

    print("🔍 Starting simplified scan...\n", .{});
    for (scanner.start_host..scanner.end_host + 1) |host| {
        const ip = [4]u8{ scanner.base_ip[0], scanner.base_ip[1], scanner.base_ip[2], @intCast(host) };
        for (scanner.ports[0..3]) |port| { // 처음 3개 포트만 테스트
            print("Testing {}.{}.{}.{}:{} ... ", .{ ip[0], ip[1], ip[2], ip[3], port });
            const result = scanner.scanSingleTarget(ip, port) catch null;
            if (result) |scan_result| {
                print("✅ Active ({}ms)\n", .{scan_result.response_time_ms});
            } else {
                print("❌ No response\n", .{});
            }
        }
    }

    const end_time = std.time.milliTimestamp();

    print("\n📈 Scan Results:\n", .{});
    print("================\n", .{});
    print("Duration: {}ms\n", .{end_time - start_time});
    print("Active peers found: {}\n", .{scanner.getActivePeers().len});

    if (scanner.getActivePeers().len > 0) {
        print("\n🎯 Active Eastsea nodes:\n", .{});
        for (scanner.getActivePeers()) |peer| {
            print("  ✅ {}\n", .{peer});
        }

        // 포트별 필터링 예시
        print("\n📊 Peers by port:\n", .{});
        for (scanner.ports) |port| {
            var filtered = try scanner.filterByPort(port);
            defer filtered.deinit();

            if (filtered.items.len > 0) {
                print("  Port {}: {} peers\n", .{ port, filtered.items.len });
                for (filtered.items) |peer| {
                    print("    - {}\n", .{peer});
                }
            }
        }
    } else {
        print("\n⚠️ No active Eastsea nodes found in the local network.\n", .{});
        print("💡 Tips:\n", .{});
        print("  - Make sure other Eastsea nodes are running\n", .{});
        print("  - Check if ports {} are accessible\n", .{base_port});
        print("  - Verify network connectivity\n", .{});
    }

    print("\n🔍 Manual scan test (localhost):\n", .{});
    print("================================\n", .{});

    // 로컬호스트에서 특정 포트 테스트
    const test_ports = [_]u16{ base_port, base_port + 1, base_port + 2 };
    for (test_ports) |port| {
        print("Testing localhost:{} ... ", .{port});

        const result = scanner.scanSingleTarget([4]u8{ 127, 0, 0, 1 }, port) catch null;
        if (result) |scan_result| {
            print("✅ Active ({}ms)\n", .{scan_result.response_time_ms});
        } else {
            print("❌ No response\n", .{});
        }
    }

    print("\n✨ Port scanner test completed!\n", .{});
}
