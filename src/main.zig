const std = @import("std");
const print = std.debug.print;

// Import modules
const blockchain = @import("blockchain/blockchain.zig");
const crypto = @import("crypto/hash.zig");
const network = @import("network/node.zig");
const consensus = @import("consensus/poh.zig");
const rpc = @import("rpc/server.zig");
const wallet = @import("cli/wallet.zig");

pub fn main() !void {
    print("🚀 Eastsea Clone in Zig Starting...\n", .{});
    print("==========================================\n", .{});
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

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
    const tx1_data = try std.fmt.allocPrint(allocator, "{s}{s}{}{}", .{ tx1.from, tx1.to, tx1.amount, tx1.timestamp });
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
    print("🕐 PoH State - Ticks: {}, Hash: {}\n", .{ poh_state.tick_count, std.fmt.fmtSliceHexLower(poh_state.hash[0..8]) });

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
    
    // Cleanup
    rpc_server.stop();
    node.stop();
}

test "basic functionality" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var chain = try blockchain.Blockchain.init(allocator);
    defer chain.deinit();

    try testing.expect(chain.getHeight() == 1); // Genesis block
}