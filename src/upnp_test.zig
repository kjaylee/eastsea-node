const std = @import("std");
const print = std.debug.print;
const upnp = @import("network/upnp.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // 명령행 인수 파싱
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    var port: u16 = 8000;
    
    if (args.len >= 2) {
        port = std.fmt.parseInt(u16, args[1], 10) catch {
            print("❌ Invalid port number: {s}\n", .{args[1]});
            return;
        };
    }
    
    print("🚀 Starting UPnP Test on port {}\n", .{port});
    print("=====================================\n", .{});
    
    // UPnP 클라이언트 초기화
    const upnp_client = upnp.UPnPClient.init(allocator) catch |err| {
        print("❌ Failed to initialize UPnP client: {any}\n", .{err});
        return;
    };
    defer upnp_client.deinit();
    
    print("✅ UPnP client initialized\n", .{});
    print("🏠 Local IP: {s}\n", .{upnp_client.local_ip});
    
    // UPnP 디바이스 발견
    print("\n🔍 Discovering UPnP devices...\n", .{});
    const discovery_success = upnp_client.discover() catch |err| {
        print("❌ UPnP discovery failed: {any}\n", .{err});
        print("\n📝 This could happen if:\n", .{});
        print("  - No UPnP-enabled router on the network\n", .{});
        print("  - UPnP is disabled on the router\n", .{});
        print("  - Network firewall blocking SSDP traffic\n", .{});
        print("  - Running in a restricted network environment\n", .{});
        return;
    };
    
    if (!discovery_success) {
        print("❌ No UPnP devices found\n", .{});
        print("\n📝 Possible solutions:\n", .{});
        print("  - Enable UPnP/IGD on your router\n", .{});
        print("  - Check router administration panel\n", .{});
        print("  - Ensure you're on the same network as the router\n", .{});
        return;
    }
    
    print("✅ UPnP device discovered successfully\n", .{});
    
    // 외부 IP 주소 조회
    print("\n🌐 Getting external IP address...\n", .{});
    const external_ip = upnp_client.getExternalIP() catch |err| blk: {
        print("⚠️ Failed to get external IP: {any}\n", .{err});
        break :blk null;
    };
    
    if (external_ip) |ip| {
        defer allocator.free(ip);
        print("🌐 External IP: {s}\n", .{ip});
    }
    
    // 포트 매핑 추가
    print("\n🔧 Adding port mappings...\n", .{});
    
    // TCP 포트 매핑
    upnp_client.addPortMapping(
        port, 
        port, 
        upnp.UPnPClient.PortMapping.Protocol.TCP, 
        "Eastsea P2P Node TCP", 
        3600 // 1시간 임대
    ) catch |err| {
        print("⚠️ Failed to add TCP port mapping: {any}\n", .{err});
    };
    
    // UDP 포트 매핑 (DHT용)
    upnp_client.addPortMapping(
        port, 
        port, 
        upnp.UPnPClient.PortMapping.Protocol.UDP, 
        "Eastsea DHT Node UDP", 
        3600 // 1시간 임대
    ) catch |err| {
        print("⚠️ Failed to add UDP port mapping: {any}\n", .{err});
    };
    
    // 현재 포트 매핑 상태 출력
    print("\n📋 Current port mappings:\n", .{});
    upnp_client.printPortMappings();
    
    // 테스트 실행
    print("\n🧪 Running UPnP functionality tests...\n", .{});
    
    // 1. 포트 매핑 목록 확인
    print("1. Port mapping list test: ", .{});
    if (upnp_client.mapped_ports.items.len > 0) {
        print("✅ PASS ({} mappings)\n", .{upnp_client.mapped_ports.items.len});
    } else {
        print("❌ FAIL (no mappings)\n", .{});
    }
    
    // 2. 외부 IP 조회 테스트
    print("2. External IP test: ", .{});
    if (external_ip != null) {
        print("✅ PASS\n", .{});
    } else {
        print("❌ FAIL\n", .{});
    }
    
    // 대화형 모드
    print("\n🎮 Interactive mode (press Enter to continue, 'q' to quit):\n", .{});
    const stdin = std.io.getStdIn().reader();
    var input_buffer: [64]u8 = undefined;
    
    while (true) {
        print("\n📋 Options:\n", .{});
        print("  1. Show port mappings\n", .{});
        print("  2. Get external IP\n", .{});
        print("  3. Add another port mapping\n", .{});
        print("  4. Remove a port mapping\n", .{});
        print("  5. Remove all port mappings\n", .{});
        print("  q. Quit\n", .{});
        print("Choice: ", .{});
        
        if (try stdin.readUntilDelimiterOrEof(input_buffer[0..], '\n')) |input| {
            const trimmed = std.mem.trim(u8, input, " \t\r\n");
            
            if (std.mem.eql(u8, trimmed, "q") or std.mem.eql(u8, trimmed, "quit")) {
                break;
            } else if (std.mem.eql(u8, trimmed, "1")) {
                upnp_client.printPortMappings();
            } else if (std.mem.eql(u8, trimmed, "2")) {
                const new_external_ip = upnp_client.getExternalIP() catch |err| {
                    print("❌ Failed to get external IP: {any}\n", .{err});
                    continue;
                };
                defer allocator.free(new_external_ip);
                print("🌐 External IP: {s}\n", .{new_external_ip});
            } else if (std.mem.eql(u8, trimmed, "3")) {
                print("Enter port number: ", .{});
                if (try stdin.readUntilDelimiterOrEof(input_buffer[0..], '\n')) |port_input| {
                    const port_trimmed = std.mem.trim(u8, port_input, " \t\r\n");
                    const new_port = std.fmt.parseInt(u16, port_trimmed, 10) catch {
                        print("❌ Invalid port number\n", .{});
                        continue;
                    };
                    
                    upnp_client.addPortMapping(
                        new_port, 
                        new_port, 
                        upnp.UPnPClient.PortMapping.Protocol.TCP, 
                        "Eastsea Test Port", 
                        1800 // 30분 임대
                    ) catch |err| {
                        print("❌ Failed to add port mapping: {any}\n", .{err});
                    };
                }
            } else if (std.mem.eql(u8, trimmed, "4")) {
                if (upnp_client.mapped_ports.items.len == 0) {
                    print("❌ No port mappings to remove\n", .{});
                    continue;
                }
                
                upnp_client.printPortMappings();
                print("Enter port number to remove: ", .{});
                if (try stdin.readUntilDelimiterOrEof(input_buffer[0..], '\n')) |port_input| {
                    const port_trimmed = std.mem.trim(u8, port_input, " \t\r\n");
                    const remove_port = std.fmt.parseInt(u16, port_trimmed, 10) catch {
                        print("❌ Invalid port number\n", .{});
                        continue;
                    };
                    
                    upnp_client.removePortMapping(
                        remove_port, 
                        upnp.UPnPClient.PortMapping.Protocol.TCP
                    ) catch |err| {
                        print("❌ Failed to remove port mapping: {any}\n", .{err});
                    };
                }
            } else if (std.mem.eql(u8, trimmed, "5")) {
                upnp_client.removeAllPortMappings() catch |err| {
                    print("❌ Failed to remove all port mappings: {any}\n", .{err});
                };
            } else {
                print("❌ Invalid choice\n", .{});
            }
        } else {
            break;
        }
    }
    
    // 정리
    print("\n🧹 Cleaning up...\n", .{});
    upnp_client.removeAllPortMappings() catch |err| {
        print("⚠️ Failed to remove some port mappings: {any}\n", .{err});
    };
    
    print("✅ UPnP test completed successfully\n", .{});
}