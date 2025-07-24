const std = @import("std");

pub fn sha256(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(data);
    var hash_bytes: [32]u8 = undefined;
    hasher.final(&hash_bytes);
    
    // Convert to hex string
        const hex_string = try allocator.alloc(u8, 64);
    _ = std.fmt.bufPrint(hex_string, "{}", .{std.fmt.fmtSliceHexLower(&hash_bytes)}) catch unreachable;
    
    return hex_string;
}

pub fn sha256Raw(data: []const u8) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(data);
    var hash_bytes: [32]u8 = undefined;
    hasher.final(&hash_bytes);
    return hash_bytes;
}

pub fn verifyHash(hash1: []const u8, hash2: []const u8) bool {
    return std.mem.eql(u8, hash1, hash2);
}

// Merkle Tree implementation for transaction verification
pub const MerkleTree = struct {
    root: ?[]u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MerkleTree {
        return MerkleTree{
            .root = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MerkleTree) void {
        if (self.root) |root| {
            self.allocator.free(root);
        }
    }

    pub fn buildTree(self: *MerkleTree, transactions: []const []const u8) !void {
        if (transactions.len == 0) return;

        // Free existing root if any
        if (self.root) |root| {
            self.allocator.free(root);
            self.root = null;
        }

        var current_level = std.ArrayList([]u8).init(self.allocator);
        defer {
            for (current_level.items) |hash| {
                self.allocator.free(hash);
            }
            current_level.deinit();
        }

        // Hash all transactions
        for (transactions) |tx| {
            const hash = try sha256(self.allocator, tx);
            try current_level.append(hash);
        }

        // Build tree bottom-up
        while (current_level.items.len > 1) {
            var next_level = std.ArrayList([]u8).init(self.allocator);
            defer next_level.deinit();

            var i: usize = 0;
            while (i < current_level.items.len) : (i += 2) {
                const left = current_level.items[i];
                const right = if (i + 1 < current_level.items.len) 
                    current_level.items[i + 1] 
                else 
                    current_level.items[i]; // Duplicate if odd number

                const combined = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left, right });
                defer self.allocator.free(combined);
                
                const parent_hash = try sha256(self.allocator, combined);
                try next_level.append(parent_hash);
            }

            // Free current level
            for (current_level.items) |hash| {
                self.allocator.free(hash);
            }
            current_level.clearRetainingCapacity();

            // Move to next level
            try current_level.appendSlice(next_level.items);
            
            // Clear next_level without freeing items (they're now in current_level)
            next_level.clearRetainingCapacity();
        }

        if (current_level.items.len == 1) {
            self.root = try self.allocator.dupe(u8, current_level.items[0]);
        }
    }

    pub fn getRoot(self: *const MerkleTree) ?[]const u8 {
        return self.root;
    }
};

test "sha256 hashing" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const data = "hello world";
    const hash = try sha256(allocator, data);
    defer allocator.free(hash);

    try testing.expect(hash.len == 64); // 32 bytes = 64 hex chars
}

test "merkle tree" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tree = MerkleTree.init(allocator);
    defer tree.deinit();

    const transactions = [_][]const u8{ "tx1", "tx2", "tx3", "tx4" };
    try tree.buildTree(&transactions);

    const root = tree.getRoot();
    try testing.expect(root != null);
    try testing.expect(root.?.len == 64);
}