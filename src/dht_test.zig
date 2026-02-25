const std = @import("std");
const node = @import("network/node.zig");
const dht = @import("network/dht.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <port> [bootstrap_port]\n", .{args[0]});
        std.debug.print("Example: {s} 8000\n", .{args[0]});
        std.debug.print("Example: {s} 8001 8000\n", .{args[0]});
        return;
    }

    const port = std.fmt.parseInt(u16, args[1], 10) catch {
        std.debug.print("❌ Invalid port number: {s}\n", .{args[1]});
        return;
    };

    var bootstrap_port: ?u16 = null;
    if (args.len >= 3) {
        bootstrap_port = std.fmt.parseInt(u16, args[2], 10) catch {
            std.debug.print("❌ Invalid bootstrap port number: {s}\n", .{args[2]});
            return;
        };
    }

    std.debug.print("🚀 Starting DHT Test Node on port {}\n", .{port});
    if (bootstrap_port) |bp| {
        std.debug.print("🔗 Will bootstrap from port {}\n", .{bp});
    }

    // Create and start node
    var test_node = node.Node.init(allocator, "127.0.0.1", port);
    defer test_node.deinit();

    try test_node.start();
    defer test_node.stop();

    // If bootstrap port is provided, connect to it
    if (bootstrap_port) |bp| {
        std.Thread.sleep(1000000000); // Wait 1 second for node to fully start

        std.debug.print("🔗 Attempting to connect to bootstrap node at port {}\n", .{bp});
        test_node.connectToPeer("127.0.0.1", bp) catch |err| {
            std.debug.print("⚠️  Could not connect to bootstrap node: {}\n", .{err});
        };
    }

    // Discover peers using DHT
    std.Thread.sleep(2000000000); // Wait 2 seconds
    try test_node.discoverPeers();

    // Run the node for a while to demonstrate DHT functionality
    std.debug.print("🏃 Running DHT test for 30 seconds...\n", .{});

    var elapsed_time: u32 = 0;
    const test_duration: u32 = 30; // 30 seconds

    while (elapsed_time < test_duration) {
        std.Thread.sleep(1000000000); // Sleep for 1 second
        elapsed_time += 1;

        // Every 5 seconds, show status and ping peers
        if (elapsed_time % 5 == 0) {
            std.debug.print("\n📊 Status update ({}s elapsed):\n", .{elapsed_time});
            std.debug.print("   Connected peers: {}\n", .{test_node.getPeerCount()});

            if (test_node.dht) |dht_instance| {
                dht_instance.getNodeInfo();
            }

            // Ping all peers
            try test_node.pingPeers();

            // Try to discover more peers
            if (elapsed_time % 10 == 0) {
                std.debug.print("🔍 Performing periodic peer discovery...\n", .{});
                try test_node.discoverPeers();
            }
        }
    }

    std.debug.print("\n✅ DHT test completed successfully!\n", .{});
    std.debug.print("📊 Final statistics:\n", .{});
    std.debug.print("   Connected peers: {}\n", .{test_node.getPeerCount()});

    if (test_node.dht) |dht_instance| {
        dht_instance.getNodeInfo();
    }
}

test "DHT integration test" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Create two nodes
    var node1 = node.Node.init(allocator, "127.0.0.1", 9000);
    defer node1.deinit();

    var node2 = node.Node.init(allocator, "127.0.0.1", 9001);
    defer node2.deinit();

    // Start both nodes
    try node1.start();
    defer node1.stop();

    try node2.start();
    defer node2.stop();

    // Connect node2 to node1
    try node2.connectToPeer("127.0.0.1", 9000);

    // Test basic connectivity
    try testing.expect(node1.isConnected() or node2.isConnected());
}
