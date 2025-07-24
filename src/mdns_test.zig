const std = @import("std");
const mdns = @import("network/mdns.zig");
const p2p = @import("network/p2p.zig");
const bootstrap = @import("network/bootstrap.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <port>\n", .{args[0]});
        std.debug.print("  port: Local port to listen on\n", .{});
        return;
    }

    const local_port = std.fmt.parseInt(u16, args[1], 10) catch {
        std.debug.print("❌ Invalid port number: {s}\n", .{args[1]});
        return;
    };

    std.debug.print("🚀 Starting mDNS Discovery Test Node\n", .{});
    std.debug.print("📍 Local port: {}\n", .{local_port});

    // Initialize P2P node
    var p2p_node = try p2p.P2PNode.init(allocator, local_port);
    defer p2p_node.deinit();

    try p2p_node.start();
    defer p2p_node.stop();

    // Initialize Bootstrap client
    var bootstrap_client = try bootstrap.BootstrapClient.init(allocator, "127.0.0.1", local_port);
    defer bootstrap_client.deinit();

    try bootstrap_client.attachP2PNode(&p2p_node);

    // Initialize mDNS Discovery
    var mdns_discovery = try mdns.MDNSDiscovery.init(allocator, "127.0.0.1", local_port);
    defer mdns_discovery.deinit();

    mdns_discovery.attachP2PNode(&p2p_node);
    mdns_discovery.attachBootstrapClient(&bootstrap_client);

    // Start mDNS discovery
    std.debug.print("🔍 Starting mDNS discovery...\n", .{});
    mdns_discovery.start() catch |err| {
        std.debug.print("⚠️  mDNS discovery start failed: {}\n", .{err});
        std.debug.print("ℹ️  This is expected on some systems due to multicast socket limitations\n", .{});
        std.debug.print("ℹ️  Continuing with mock discovery for demonstration...\n", .{});
    };

    // Start accepting P2P connections in a separate thread
    const accept_thread = try std.Thread.spawn(.{}, acceptConnections, .{&p2p_node});
    defer accept_thread.join();

    // Start mDNS message receiving in a separate thread (if mDNS started successfully)
    var mdns_thread: ?std.Thread = null;
    if (mdns_discovery.running) {
        mdns_thread = try std.Thread.spawn(.{}, receiveMessages, .{&mdns_discovery});
    }
    defer if (mdns_thread) |thread| thread.join();

    // Main loop
    var iteration: u32 = 0;
    while (iteration < 20) { // Run for 20 iterations
        iteration += 1;
        
        std.debug.print("\n--- Iteration {} ---\n", .{iteration});
        
        // Show network status
        showNetworkStatus(&p2p_node, &bootstrap_client, &mdns_discovery);
        
        // Periodically announce service
        if (iteration % 5 == 0) {
            std.debug.print("📢 Announcing mDNS service...\n", .{});
            mdns_discovery.announceService() catch |err| {
                std.debug.print("⚠️  Failed to announce service: {}\n", .{err});
            };
        }
        
        // Periodically query for services
        if (iteration % 7 == 0) {
            std.debug.print("🔍 Querying for mDNS services...\n", .{});
            mdns_discovery.queryForServices() catch |err| {
                std.debug.print("⚠️  Failed to query services: {}\n", .{err});
            };
        }
        
        // Cleanup stale entries
        if (iteration % 10 == 0) {
            std.debug.print("🧹 Cleaning up stale mDNS entries...\n", .{});
            mdns_discovery.cleanupStaleEntries();
        }
        
        // Ping all peers
        if (iteration % 3 == 0) {
            std.debug.print("🏓 Pinging all peers...\n", .{});
            p2p_node.pingAllPeers() catch |err| {
                std.debug.print("⚠️  Failed to ping peers: {}\n", .{err});
            };
        }
        
        // Simulate discovering a peer (for demonstration when real mDNS doesn't work)
        if (iteration == 5 and !mdns_discovery.running) {
            std.debug.print("🎭 Simulating peer discovery...\n", .{});
            simulatePeerDiscovery(&mdns_discovery, &bootstrap_client, &p2p_node) catch |err| {
                std.debug.print("⚠️  Failed to simulate peer discovery: {}\n", .{err});
            };
        }
        
        std.time.sleep(3_000_000_000); // 3 seconds
    }

    std.debug.print("\n🎯 mDNS discovery test completed!\n", .{});
    showFinalStatus(&p2p_node, &bootstrap_client, &mdns_discovery);
}

fn acceptConnections(p2p_node: *p2p.P2PNode) !void {
    try p2p_node.acceptConnections();
}

fn receiveMessages(mdns_discovery: *mdns.MDNSDiscovery) !void {
    try mdns_discovery.receiveMessages();
}

fn showNetworkStatus(p2p_node: *p2p.P2PNode, bootstrap_client: *bootstrap.BootstrapClient, mdns_discovery: *mdns.MDNSDiscovery) void {
    std.debug.print("📊 Network Status:\n", .{});
    std.debug.print("   P2P Peers: {}\n", .{p2p_node.getPeerCount()});
    std.debug.print("   Bootstrap Nodes: {}\n", .{bootstrap_client.getBootstrapNodeCount()});
    std.debug.print("   mDNS Discovered Peers: {}\n", .{mdns_discovery.getDiscoveredPeerCount()});
    std.debug.print("   mDNS Active Peers: {}\n", .{mdns_discovery.getActivePeerCount()});
    std.debug.print("   mDNS Running: {}\n", .{mdns_discovery.running});
}

fn showFinalStatus(p2p_node: *p2p.P2PNode, bootstrap_client: *bootstrap.BootstrapClient, mdns_discovery: *mdns.MDNSDiscovery) void {
    std.debug.print("📈 Final mDNS Discovery Statistics:\n", .{});
    std.debug.print("   Total P2P connections: {}\n", .{p2p_node.getPeerCount()});
    std.debug.print("   Bootstrap nodes configured: {}\n", .{bootstrap_client.getBootstrapNodeCount()});
    std.debug.print("   Total peers discovered via mDNS: {}\n", .{mdns_discovery.getDiscoveredPeerCount()});
    std.debug.print("   Active mDNS peers: {}\n", .{mdns_discovery.getActivePeerCount()});
    
    if (mdns_discovery.running) {
        std.debug.print("✅ mDNS discovery was running successfully\n", .{});
    } else {
        std.debug.print("⚠️  mDNS discovery was not running (likely due to system limitations)\n", .{});
    }
}

fn simulatePeerDiscovery(mdns_discovery: *mdns.MDNSDiscovery, bootstrap_client: *bootstrap.BootstrapClient, p2p_node: *p2p.P2PNode) !void {
    // Simulate discovering peers on different ports
    const mock_ports = [_]u16{ 8001, 8002, 8003 };
    
    for (mock_ports) |port| {
        if (port != p2p_node.address.getPort()) { // Don't discover ourselves
            std.debug.print("🎭 Simulating discovery of peer at 127.0.0.1:{}\n", .{port});
            
            // Add to bootstrap client
            try bootstrap_client.addBootstrapNode("127.0.0.1", port);
            
            // Try to connect via P2P
            const peer_address = try std.net.Address.parseIp4("127.0.0.1", port);
            _ = p2p_node.connectToPeer(peer_address) catch |err| {
                std.debug.print("⚠️  Failed to connect to simulated peer {}: {}\n", .{ port, err });
            };
        }
    }
}

test "mDNS discovery integration" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    // Test mDNS discovery creation
    var mdns_discovery = try mdns.MDNSDiscovery.init(allocator, "127.0.0.1", 8000);
    defer mdns_discovery.deinit();
    
    try testing.expect(mdns_discovery.getDiscoveredPeerCount() == 0);
    try testing.expect(!mdns_discovery.running);
    
    // Test P2P node creation
    var p2p_node = try p2p.P2PNode.init(allocator, 8000);
    defer p2p_node.deinit();
    
    // Test bootstrap client creation
    var bootstrap_client = try bootstrap.BootstrapClient.init(allocator, "127.0.0.1", 8000);
    defer bootstrap_client.deinit();
    
    // Test attachments
    mdns_discovery.attachP2PNode(&p2p_node);
    mdns_discovery.attachBootstrapClient(&bootstrap_client);
    
    try testing.expect(mdns_discovery.p2p_node != null);
    try testing.expect(mdns_discovery.bootstrap_client != null);
}

test "mDNS message creation" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    // Test mDNS message creation
    var message = mdns.MDNSMessage.init(allocator, 1234, false);
    defer message.deinit();
    
    try testing.expect(message.header.id == 1234);
    try testing.expect(!message.header.isResponse());
    try testing.expect(message.questions.items.len == 0);
    try testing.expect(message.answers.items.len == 0);
    
    // Test adding question
    const question = try mdns.MDNSQuestion.init(allocator, "_eastsea._tcp.local", .PTR, .IN);
    try message.addQuestion(question);
    
    try testing.expect(message.questions.items.len == 1);
    try testing.expect(message.header.questions == 1);
}