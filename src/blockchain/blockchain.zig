const std = @import("std");
const crypto = @import("../crypto/hash.zig");

pub const Transaction = struct {
    from: []const u8,
    to: []const u8,
    amount: u64,
    timestamp: i64,

    pub fn hash(self: *const Transaction, allocator: std.mem.Allocator) ![]u8 {
        const data = try std.fmt.allocPrint(allocator, "{s}{s}{d}{d}", .{ self.from, self.to, self.amount, self.timestamp });
        defer allocator.free(data);
        return crypto.sha256(allocator, data);
    }
};

pub const Block = struct {
    index: u64,
    timestamp: i64,
    transactions: std.ArrayList(Transaction),
    previous_hash: []u8,
    hash: []u8,
    nonce: u64,

    pub fn init(allocator: std.mem.Allocator, index: u64, previous_hash: []u8) !Block {
        return Block{
            .index = index,
            .timestamp = std.time.timestamp(),
            .transactions = std.ArrayList(Transaction).init(allocator),
            .previous_hash = try allocator.dupe(u8, previous_hash),
            .hash = &[_]u8{},
            .nonce = 0,
        };
    }

    pub fn deinit(self: *Block, allocator: std.mem.Allocator) void {
        self.transactions.deinit();
        allocator.free(self.previous_hash);
        if (self.hash.len > 0) {
            allocator.free(self.hash);
        }
    }

    pub fn addTransaction(self: *Block, transaction: Transaction) !void {
        try self.transactions.append(transaction);
    }

    pub fn calculateHash(self: *Block, allocator: std.mem.Allocator) ![]u8 {
        var tx_data = std.ArrayList(u8).init(allocator);
        defer tx_data.deinit();

        for (self.transactions.items) |tx| {
            const tx_str = try std.fmt.allocPrint(allocator, "{s}{s}{d}{d}", .{ tx.from, tx.to, tx.amount, tx.timestamp });
            defer allocator.free(tx_str);
            try tx_data.appendSlice(tx_str);
        }

        const block_data = try std.fmt.allocPrint(
            allocator,
            "{}{}{s}{s}{}",
            .{ self.index, self.timestamp, tx_data.items, self.previous_hash, self.nonce }
        );
        defer allocator.free(block_data);

        return crypto.sha256(allocator, block_data);
    }

    pub fn mine(self: *Block, allocator: std.mem.Allocator, difficulty: u32) !void {
        const target = try allocator.alloc(u8, difficulty);
        defer allocator.free(target);
        @memset(target, '0');

        while (true) {
            // Free previous hash if it exists
            if (self.hash.len > 0) {
                allocator.free(self.hash);
                self.hash = &[_]u8{}; // Reset to empty slice
            }
            self.hash = try self.calculateHash(allocator);
            
            if (std.mem.startsWith(u8, self.hash, target)) {
                break;
            }
            self.nonce += 1;
        }
    }
};

pub const Blockchain = struct {
    chain: std.ArrayList(Block),
    pending_transactions: std.ArrayList(Transaction),
    mining_reward: u64,
    difficulty: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Blockchain {
        var blockchain = Blockchain{
            .chain = std.ArrayList(Block).init(allocator),
            .pending_transactions = std.ArrayList(Transaction).init(allocator),
            .mining_reward = 100,
            .difficulty = 2,
            .allocator = allocator,
        };

        // Create genesis block
        try blockchain.createGenesisBlock();
        return blockchain;
    }

    pub fn deinit(self: *Blockchain) void {
        for (self.chain.items) |*block| {
            block.deinit(self.allocator);
        }
        self.chain.deinit();
        self.pending_transactions.deinit();
    }

    fn createGenesisBlock(self: *Blockchain) !void {
        const genesis_hash = try self.allocator.alloc(u8, 64);
        @memset(genesis_hash, '0');

        var genesis_block = try Block.init(self.allocator, 0, genesis_hash);
        genesis_block.hash = try genesis_block.calculateHash(self.allocator);
        
        try self.chain.append(genesis_block);
        self.allocator.free(genesis_hash);
    }

    pub fn getLatestBlock(self: *const Blockchain) *const Block {
        return &self.chain.items[self.chain.items.len - 1];
    }

    pub fn addTransaction(self: *Blockchain, transaction: Transaction) !void {
        try self.pending_transactions.append(transaction);
    }

    pub fn mineBlock(self: *Blockchain) !void {
        const latest_block = self.getLatestBlock();
        var new_block = try Block.init(self.allocator, latest_block.index + 1, latest_block.hash);

        // Add pending transactions
        for (self.pending_transactions.items) |tx| {
            try new_block.addTransaction(tx);
        }

        // Add mining reward transaction
        const reward_tx = Transaction{
            .from = "system",
            .to = "miner",
            .amount = self.mining_reward,
            .timestamp = std.time.timestamp(),
        };
        try new_block.addTransaction(reward_tx);

        // Mine the block
        try new_block.mine(self.allocator, self.difficulty);

        try self.chain.append(new_block);
        self.pending_transactions.clearRetainingCapacity();
    }

    pub fn getHeight(self: *const Blockchain) u64 {
        return self.chain.items.len;
    }

    pub fn isChainValid(self: *const Blockchain) bool {
        return self.validateChain();
    }
    
    pub fn hasPendingTransactions(self: *const Blockchain) bool {
        return self.pending_transactions.items.len > 0;
    }
    
    pub fn validateChain(self: *const Blockchain) bool {
        for (self.chain.items[1..], 1..) |block, i| {
            const previous_block = &self.chain.items[i - 1];
            
            if (!std.mem.eql(u8, block.previous_hash, previous_block.hash)) {
                return false;
            }
        }
        return true;
    }
};

test "blockchain creation" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var blockchain = try Blockchain.init(allocator);
    defer blockchain.deinit();

    try testing.expect(blockchain.getHeight() == 1);
    try testing.expect(blockchain.isChainValid());
}

test "transaction and mining" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var blockchain = try Blockchain.init(allocator);
    defer blockchain.deinit();

    const tx = Transaction{
        .from = "alice",
        .to = "bob",
        .amount = 50,
        .timestamp = std.time.timestamp(),
    };

    try blockchain.addTransaction(tx);
    try blockchain.mineBlock();

    try testing.expect(blockchain.getHeight() == 2);
}