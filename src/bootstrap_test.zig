const std = @import("std");
const bootstrap = @import("network/bootstrap.zig");
const p2p = @import("network/p2p.zig");
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
        std.debug.print("  port: Local port to listen on\n", .{});
        std.debug.print("  bootstrap_port: Port of bootstrap node to connect to (optional)\n", .{});
        return;
    }

    const local_port = std.fmt.parseInt(u16, args[1], 10) catch {
        std.debug.print("❌ Invalid port number: {s}\n", .{args[1]});
        return;
    };

    const bootstrap_port: ?u16 = if (args.len >= 3) 
        std.fmt.parseInt(u16, args[2], 10) catch null
    else 
        null;

    std.debug.print("🚀 Starting Bootstrap Test Node\n", .{});
    std.debug.print("📍 Local port: {}\n", .{local_port});
    if (bootstrap_port) |bp| {
        std.debug.print("🔗 Bootstrap port: {}\n", .{bp});
    }

    // Initialize P2P node
    var p2p_node = try p2p.P2PNode.init(allocator, local_port);
    defer p2p_node.deinit();

    try p2p_node.start();
    defer p2p_node.stop();

    // Initialize DHT
    var dht_node = try dht.DHT.init(allocator, "127.0.0.1", local_port);
    defer dht_node.deinit();

    try dht_node.attachP2PNode(&p2p_node);

    // Initialize Bootstrap client
    var bootstrap_client = try bootstrap.BootstrapClient.init(allocator, "127.0.0.1", local_port);
    defer bootstrap_client.deinit();

    try bootstrap_client.attachP2PNode(&p2p_node);
    bootstrap_client.attachDHTNode(&dht_node);

    // Initialize Bootstrap server
    var bootstrap_server = try bootstrap.BootstrapServer.init(allocator, "127.0.0.1", local_port, 100);
    defer bootstrap_server.deinit();

    try bootstrap_server.attachP2PNode(&p2p_node);

    // If bootstrap port is provided, add it as a bootstrap node and connect
    if (bootstrap_port) |bp| {
        if (bp != local_port) { // Don't bootstrap to ourselves
            try bootstrap_client.addBootstrapNode("127.0.0.1", bp);
            
            std.debug.print("🔗 Attempting to bootstrap...\n", .{});
            bootstrap_client.bootstrap() catch |err| {
                std.debug.print("⚠️  Bootstrap failed: {}\n", .{err});
            };
        }
    } else {
        // If no bootstrap port provided, add default bootstrap nodes
        try bootstrap_client.addDefaultBootstrapNodes();
        
        std.debug.print("🔗 Attempting to bootstrap with default nodes...\n", .{});
        bootstrap_client.bootstrap() catch |err| {
            std.debug.print("⚠️  Bootstrap with default nodes failed: {}\n", .{err});
        };
    }

    // Start accepting connections in a separate thread
    const accept_thread = try std.Thread.spawn(.{}, acceptConnections, .{&p2p_node});
    defer accept_thread.join();

    // Main loop
    var iteration: u32 = 0;
    while (iteration < 30) { // Run for 30 iterations
        iteration += 1;
        
        std.debug.print("\n--- Iteration {} ---\n", .{iteration});
        
        // Show network status
        showNetworkStatus(&p2p_node, &dht_node, &bootstrap_client, &bootstrap_server);
        
        // Periodically announce our node
        if (iteration % 10 == 0) {
            std.debug.print("📢 Announcing node to network...\n", .{});
            bootstrap_client.announceNode() catch |err| {
                std.debug.print("⚠️  Failed to announce node: {}\n", .{err});
            };
        }
        
        // Periodically try to bootstrap again
        if (iteration % 15 == 0 and bootstrap_client.getBootstrapNodeCount() > 0) {
            std.debug.print("🔄 Re-attempting bootstrap...\n", .{});
            bootstrap_client.bootstrap() catch |err| {
                std.debug.print("⚠️  Re-bootstrap failed: {}\n", .{err});
            };
        }
        
        // Ping all peers
        if (iteration % 5 == 0) {
            std.debug.print("🏓 Pinging all peers...\n", .{});
            p2p_node.pingAllPeers() catch |err| {
                std.debug.print("⚠️  Failed to ping peers: {}\n", .{err});
            };
        }
        
        std.time.sleep(2_000_000_000); // 2 seconds
    }

    std.debug.print("\n🎯 Bootstrap test completed!\n", .{});
    showFinalStatus(&p2p_node, &dht_node, &bootstrap_client, &bootstrap_server);
}

fn acceptConnections(p2p_node: *p2p.P2PNode) !void {
    try p2p_node.acceptConnections();
}

fn showNetworkStatus(p2p_node: *p2p.P2PNode, dht_node: *dht.DHT, bootstrap_client: *bootstrap.BootstrapClient, bootstrap_server: *bootstrap.BootstrapServer) void {
    std.debug.print("📊 Network Status:\n", .{});
    std.debug.print("   P2P Peers: {}\n", .{p2p_node.getPeerCount()});
    std.debug.print("   DHT Nodes: {}\n", .{dht_node.routing_table.getTotalNodes()});
    std.debug.print("   DHT Active Buckets: {}\n", .{dht_node.routing_table.getActiveBuckets()});
    std.debug.print("   Bootstrap Nodes: {}\n", .{bootstrap_client.getBootstrapNodeCount()});
    std.debug.print("   Active Bootstrap Nodes: {}\n", .{bootstrap_client.getActiveBootstrapNodes()});
    std.debug.print("   Known Peers (Server): {}\n", .{bootstrap_server.getKnownPeerCount()});
}

fn showFinalStatus(p2p_node: *p2p.P2PNode, dht_node: *dht.DHT, bootstrap_client: *bootstrap.BootstrapClient, bootstrap_server: *bootstrap.BootstrapServer) void {
    std.debug.print("📈 Final Network Statistics:\n", .{});
    std.debug.print("   Total P2P connections established: {}\n", .{p2p_node.getPeerCount()});
    std.debug.print("   Total DHT nodes discovered: {}\n", .{dht_node.routing_table.getTotalNodes()});
    std.debug.print("   DHT routing table active buckets: {}\n", .{dht_node.routing_table.getActiveBuckets()});
    std.debug.print("   Bootstrap nodes configured: {}\n", .{bootstrap_client.getBootstrapNodeCount()});
    std.debug.print("   Active bootstrap connections: {}\n", .{bootstrap_client.getActiveBootstrapNodes()});
    std.debug.print("   Known peers in bootstrap server: {}\n", .{bootstrap_server.getKnownPeerCount()});
    
    // Show DHT node info
    dht_node.getNodeInfo();
}

test "Bootstrap system integration" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    // Test bootstrap client creation
    var bootstrap_client = try bootstrap.BootstrapClient.init(allocator, "127.0.0.1", 8000);
    defer bootstrap_client.deinit();
    
    try testing.expect(bootstrap_client.getBootstrapNodeCount() == 0);
    
    // Test adding bootstrap nodes
    try bootstrap_client.addBootstrapNode("127.0.0.1", 8001);
    try testing.expect(bootstrap_client.getBootstrapNodeCount() == 1);
    
    // Test bootstrap server creation
    var bootstrap_server = try bootstrap.BootstrapServer.init(allocator, "127.0.0.1", 8000, 10);
    defer bootstrap_server.deinit();
    
    try testing.expect(bootstrap_server.getKnownPeerCount() == 0);
    
    // Test adding known peers
    try bootstrap_server.addKnownPeer("127.0.0.1", 8001);
    try testing.expect(bootstrap_server.getKnownPeerCount() == 1);
}