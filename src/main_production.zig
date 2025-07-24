const std = @import("std");
const print = std.debug.print;

// Import modules
const blockchain = @import("blockchain/blockchain.zig");
const crypto = @import("crypto/hash.zig");
const network = @import("network/node.zig");
const consensus = @import("consensus/poh.zig");
const rpc = @import("rpc/server.zig");
const wallet = @import("cli/wallet.zig");

const Config = struct {
    node_address: []const u8 = "127.0.0.1",
    node_port: u16 = 8000,
    rpc_port: u16 = 8545,
    bootstrap_peers: []const []const u8 = &[_][]const u8{},
    is_validator: bool = true,
    demo_mode: bool = false,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var config = Config{};
    
    // Simple argument parsing
    for (args[1..]) |arg| {
        if (std.mem.startsWith(u8, arg, "--port=")) {
            const port_str = arg[7..];
            config.node_port = std.fmt.parseInt(u16, port_str, 10) catch {
                print("❌ Invalid port: {s}\n", .{port_str});
                return;
            };
        } else if (std.mem.startsWith(u8, arg, "--rpc-port=")) {
            const port_str = arg[11..];
            config.rpc_port = std.fmt.parseInt(u16, port_str, 10) catch {
                print("❌ Invalid RPC port: {s}\n", .{port_str});
                return;
            };
        } else if (std.mem.eql(u8, arg, "--demo")) {
            config.demo_mode = true;
        } else if (std.mem.eql(u8, arg, "--help")) {
            printUsage();
            return;
        }
    }

    if (config.demo_mode) {
        try runDemo(allocator);
    } else {
        try runProductionNode(allocator, config);
    }
}

fn printUsage() void {
    print("Eastsea Clone - Production Node\n", .{});
    print("Usage: eastsea [options]\n", .{});
    print("\nOptions:\n", .{});
    print("  --port=PORT        Node port (default: 8000)\n", .{});
    print("  --rpc-port=PORT    RPC server port (default: 8545)\n", .{});
    print("  --demo             Run in demo mode\n", .{});
    print("  --help             Show this help\n", .{});
    print("\nProduction Mode:\n", .{});
    print("  Runs a persistent node that:\n", .{});
    print("  - Maintains P2P connections\n", .{});
    print("  - Processes transactions continuously\n", .{});
    print("  - Participates in consensus\n", .{});
    print("  - Serves RPC requests\n", .{});
}

fn runProductionNode(allocator: std.mem.Allocator, config: Config) !void {
    print("🚀 Starting Eastsea Clone Node in Production Mode\n", .{});
    print("==========================================\n", .{});
    print("📍 Node: {s}:{}\n", .{ config.node_address, config.node_port });
    print("🌐 RPC: {s}:{}\n", .{ config.node_address, config.rpc_port });
    print("⚡ Validator: {}\n", .{config.is_validator});

    // Initialize blockchain
    var chain = try blockchain.Blockchain.init(allocator);
    defer chain.deinit();
    print("✅ Blockchain initialized (Height: {})\n", .{chain.getHeight()});

    // Initialize network node
    var node = network.Node.init(allocator, config.node_address, config.node_port);
    defer node.deinit();
    
    try node.start();
    try node.discoverPeers();

    // Initialize consensus engine
    const node_id = try std.fmt.allocPrint(allocator, "node_{d}", .{config.node_port});
    defer allocator.free(node_id);
    
    var consensus_engine = try consensus.ConsensusEngine.init(allocator, node_id);
    defer consensus_engine.deinit();
    print("⚡ Consensus engine initialized\n", .{});

    // Initialize RPC server
    var rpc_server = rpc.RpcServer.init(allocator, &chain, &node, config.rpc_port);
    try rpc_server.start();
    defer rpc_server.stop();

    print("\n🎯 Node is now running in production mode...\n", .{});
    print("Press Ctrl+C to stop\n", .{});
    print("==========================================\n", .{});

    // Main production loop
    var slot_timer = std.time.Timer.start() catch unreachable;
    const slot_duration_ns = 400 * std.time.ns_per_ms; // 400ms slots
    var last_stats_time = std.time.timestamp();

    while (true) {
        // Process consensus slot every 400ms
        if (slot_timer.read() >= slot_duration_ns) {
            try consensus_engine.processSlot();
            
            // Mine block if we're the leader and have transactions
            if (consensus_engine.isCurrentLeader() and chain.hasPendingTransactions()) {
                try chain.mineBlock();
                print("⛏️  Block mined! Height: {}\n", .{chain.getHeight()});
            }
            
            slot_timer.reset();
        }

        // Handle network messages (simplified)
        try processNetworkMessages(&node);

        // Print stats every 30 seconds
        const current_time = std.time.timestamp();
        if (current_time - last_stats_time >= 30) {
            printNodeStats(&chain, &node, &consensus_engine);
            last_stats_time = current_time;
        }

        // Small sleep to prevent busy waiting
        std.time.sleep(10 * std.time.ns_per_ms); // 10ms
    }
}

fn processNetworkMessages(node: *network.Node) !void {
    // In a real implementation, this would:
    // 1. Check for incoming network messages
    // 2. Process peer discovery
    // 3. Handle block/transaction propagation
    // 4. Maintain peer connections
    
    // For now, just a placeholder
    _ = node;
}

fn printNodeStats(chain: *blockchain.Blockchain, node: *network.Node, consensus_engine: *consensus.ConsensusEngine) void {
    const poh_state = consensus_engine.getCurrentPohState();
    print("\n📊 Node Statistics:\n", .{});
    print("  • Blockchain Height: {}\n", .{chain.getHeight()});
    print("  • Connected Peers: {}\n", .{node.getPeerCount()});
    print("  • PoH Ticks: {}\n", .{poh_state.tick_count});
    print("  • Node Status: {s}\n", .{if (node.isConnected()) "Connected" else "Disconnected"});
    print("==========================================\n", .{});
}

fn runDemo(allocator: std.mem.Allocator) !void {
    print("🚀 Eastsea Clone in Zig Starting (Demo Mode)...\n", .{});
    print("==========================================\n", .{});
    
    // Initialize blockchain
    var chain = try blockchain.Blockchain.init(allocator);
    defer chain.deinit();

    print("✅ Blockchain initialized\n", .{});
    print("📦 Genesis block created\n", .{});
    print("🔗 Block height: {}\n", .{chain.getHeight()});

    // Initialize network node
    var node = network.Node.init(allocator, "127.0.0.1", 8000);
    defer node.deinit();
    
    try node.start();
    try node.discoverPeers();

    // Initialize Proof of History consensus
    var consensus_engine = try consensus.ConsensusEngine.init(allocator, "main_node");
    defer consensus_engine.deinit();

    print("⚡ Proof of History consensus initialized\n", .{});

    // Initialize RPC server
    var rpc_server = rpc.RpcServer.init(allocator, &chain, &node, 8545);
    try rpc_server.start();
    defer rpc_server.stop();

    // Initialize wallet
    var cli_wallet = wallet.WalletCLI.init(allocator);
    defer cli_wallet.deinit();

    print("\n🎯 Demo Sequence Starting...\n", .{});
    print("==========================================\n", .{});

    // Demo 1: Create wallet accounts
    print("\n1️⃣  Creating wallet accounts...\n", .{});
    const addr1 = try cli_wallet.wallet.createAccount();
    const addr2 = try cli_wallet.wallet.createAccount();
    
    // Set initial balances for demo
    try cli_wallet.wallet.setBalance(addr1, 1000);
    try cli_wallet.wallet.setBalance(addr2, 500);
    
    cli_wallet.wallet.listAccounts();

    // Demo 2: Process some transactions with PoH
    print("\n2️⃣  Processing transactions with Proof of History...\n", .{});
    
    const tx1 = blockchain.Transaction{
        .from = addr1,
        .to = addr2,
        .amount = 100,
        .timestamp = std.time.timestamp(),
    };

    // Process transaction through consensus
    const tx1_data = try std.fmt.allocPrint(allocator, "{s}{s}{d}{d}", .{ tx1.from, tx1.to, tx1.amount, tx1.timestamp });
    defer allocator.free(tx1_data);
    
    try consensus_engine.processTransaction(tx1_data);
    try chain.addTransaction(tx1);

    print("💸 Transaction processed: {s} -> {s} ({})\n", .{ tx1.from, tx1.to, tx1.amount });

    // Demo 3: Mine blocks with PoH
    print("\n3️⃣  Mining blocks with consensus...\n", .{});
    
    // Process a few slots
    try consensus_engine.processSlot();
    try consensus_engine.processSlot();
    
    // Mine the block
    try chain.mineBlock();
    print("⛏️  New block mined! Height: {}\n", .{chain.getHeight()});

    const poh_state = consensus_engine.getCurrentPohState();
    print("🕐 PoH State - Ticks: {}, Hash: {s}\n", .{ poh_state.tick_count, std.fmt.fmtSliceHexLower(poh_state.hash[0..8]) });

    // Demo 4: Network operations
    print("\n4️⃣  Network operations...\n", .{});
    
    const ping_msg = network.Message.init(.ping, "ping");
    try node.broadcastMessage(ping_msg);

    // Demo 5: RPC operations
    print("\n5️⃣  RPC API demonstrations...\n", .{});
    
    const height_response = try rpc_server.processRequest("getBlockHeight", "null");
    defer allocator.free(height_response);
    print("📡 RPC getBlockHeight: {s}\n", .{height_response});

    const node_info_response = try rpc_server.processRequest("getNodeInfo", "null");
    defer allocator.free(node_info_response);
    print("📡 RPC getNodeInfo: {s}\n", .{node_info_response});

    // Demo 6: Wallet operations
    print("\n6️⃣  Wallet operations...\n", .{});
    
    const transfer_tx = try cli_wallet.wallet.transfer(addr1, addr2, 50);
    print("💰 Wallet transfer completed\n", .{});
    
    // Sign the transaction
    const signature = try cli_wallet.wallet.signTransaction(transfer_tx);
    defer allocator.free(signature);
    print("✍️  Transaction signed: {s}\n", .{signature[0..16]});

    cli_wallet.wallet.listAccounts();

    // Demo 7: Blockchain validation
    print("\n7️⃣  Blockchain validation...\n", .{});
    
    const is_valid = chain.isChainValid();
    print("🔍 Blockchain is valid: {}\n", .{is_valid});

    // Demo 8: Merkle tree operations
    print("\n8️⃣  Merkle tree operations...\n", .{});
    
    var merkle = crypto.MerkleTree.init(allocator);
    defer merkle.deinit();
    
    const transactions = [_][]const u8{ "tx1", "tx2", "tx3", "tx4" };
    try merkle.buildTree(&transactions);
    
    if (merkle.getRoot()) |root| {
        print("🌳 Merkle root: {s}\n", .{root[0..16]});
    }

    print("\n🎉 Eastsea Clone Demo Completed Successfully!\n", .{});
    print("==========================================\n", .{});
    print("📊 Final Statistics:\n", .{});
    print("  • Blockchain height: {}\n", .{chain.getHeight()});
    print("  • Network peers: {}\n", .{node.getPeerCount()});
    print("  • Wallet accounts: {}\n", .{cli_wallet.wallet.getAccountCount()});
    print("  • PoH ticks processed: {}\n", .{poh_state.tick_count});
    print("  • RPC server running: {}\n", .{rpc_server.isRunning()});
}

test "production node config" {
    const testing = std.testing;
    
    const config = Config{
        .node_port = 9000,
        .rpc_port = 9545,
        .is_validator = true,
    };
    
    try testing.expect(config.node_port == 9000);
    try testing.expect(config.rpc_port == 9545);
    try testing.expect(config.is_validator == true);
}