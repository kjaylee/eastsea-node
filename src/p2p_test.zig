const std = @import("std");
const print = std.debug.print;
const network = @import("network/node.zig");
const p2p = @import("network/p2p.zig");

pub fn main() !void {
    print("🚀 P2P Network Test Starting...\n", .{});
    print("==========================================\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var port: u16 = 8000;
    var connect_to_port: ?u16 = null;

    // Parse command line arguments
    if (args.len > 1) {
        port = std.fmt.parseInt(u16, args[1], 10) catch 8000;
    }
    if (args.len > 2) {
        connect_to_port = std.fmt.parseInt(u16, args[2], 10) catch null;
    }

    print("🌐 Starting P2P node on port {}\n", .{port});

    // Initialize network node
    var node = network.Node.init(allocator, "127.0.0.1", port);
    defer node.deinit();

    try node.start();

    // Connect to another peer if specified
    if (connect_to_port) |target_port| {
        print("🤝 Attempting to connect to peer on port {}\n", .{target_port});
        std.time.sleep(1000000000); // Wait 1 second for the other node to start

        node.connectToPeer("127.0.0.1", target_port) catch |err| {
            print("❌ Failed to connect to peer: {}\n", .{err});
        };
    }

    print("\n🎯 P2P Network Demo Starting...\n", .{});
    print("==========================================\n", .{});

    // Demo 1: Peer discovery
    print("\n1️⃣  Discovering peers...\n", .{});
    try node.discoverPeers();
    print("👥 Connected peers: {}\n", .{node.getPeerCount()});

    // Demo 2: Ping all peers
    print("\n2️⃣  Pinging all peers...\n", .{});
    try node.pingPeers();

    // Demo 3: Broadcast a test transaction
    print("\n3️⃣  Broadcasting test transaction...\n", .{});
    const test_tx = "test_transaction_data_123";
    try node.broadcastTransaction(test_tx);

    // Demo 4: Broadcast a test block
    print("\n4️⃣  Broadcasting test block...\n", .{});
    const test_block = "test_block_data_456";
    try node.broadcastBlock(test_block);

    // Demo 5: Send legacy messages
    print("\n5️⃣  Sending legacy messages...\n", .{});
    const ping_msg = network.Message.init(.ping, "ping_payload");
    try node.broadcastMessage(ping_msg);

    print("\n🎉 P2P Network Demo Completed!\n", .{});
    print("==========================================\n", .{});
    print("📊 Final Statistics:\n", .{});
    print("  • Node port: {}\n", .{port});
    print("  • Connected peers: {}\n", .{node.getPeerCount()});
    print("  • Node running: {}\n", .{node.is_running});
    print("  • Network connected: {}\n", .{node.isConnected()});

    // Keep the node running for a bit to handle incoming connections
    print("\n⏰ Keeping node alive for 10 seconds...\n", .{});
    var i: u8 = 0;
    while (i < 10) {
        std.time.sleep(1000000000); // 1 second
        i += 1;
        print("⏱️  {} seconds remaining... (peers: {})\n", .{ 10 - i, node.getPeerCount() });

        // Ping peers every 3 seconds
        if (i % 3 == 0) {
            node.pingPeers() catch |err| {
                print("⚠️  Error pinging peers: {}\n", .{err});
            };
        }
    }

    print("\n🛑 Shutting down P2P node...\n", .{});
    node.stop();
}

test "p2p network basic functionality" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var node1 = network.Node.init(allocator, "127.0.0.1", 9000);
    defer node1.deinit();

    var node2 = network.Node.init(allocator, "127.0.0.1", 9001);
    defer node2.deinit();

    try node1.start();
    try node2.start();

    try testing.expect(node1.is_running);
    try testing.expect(node2.is_running);

    node1.stop();
    node2.stop();

    try testing.expect(!node1.is_running);
    try testing.expect(!node2.is_running);
}
