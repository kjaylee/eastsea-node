const std = @import("std");
const crypto = @import("../crypto/hash.zig");

// Proof of History Entry
pub const PohEntry = struct {
    hash: [32]u8,
    num_hashes: u64,
    
    pub fn init(prev_hash: [32]u8, num_hashes: u64) PohEntry {
        return PohEntry{
            .hash = prev_hash,
            .num_hashes = num_hashes,
        };
    }
};

// Proof of History Sequence Generator
pub const PohSequence = struct {
    current_hash: [32]u8,
    tick_count: u64,
    entries: std.ArrayList(PohEntry),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, seed: ?[32]u8) PohSequence {
        const initial_hash = seed orelse blk: {
            var hash: [32]u8 = undefined;
            std.crypto.random.bytes(&hash);
            break :blk hash;
        };
        
        return PohSequence{
            .current_hash = initial_hash,
            .tick_count = 0,
            .entries = std.ArrayList(PohEntry).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *PohSequence) void {
        self.entries.deinit();
    }
    
    // Generate next hash in the sequence
    pub fn tick(self: *PohSequence) void {
        self.current_hash = crypto.sha256Raw(std.mem.asBytes(&self.current_hash));
        self.tick_count += 1;
    }
    
    // Generate multiple ticks
    pub fn tickN(self: *PohSequence, n: u64) void {
        var i: u64 = 0;
        while (i < n) : (i += 1) {
            self.tick();
        }
    }
    
    // Record an entry with the current state
    pub fn recordEntry(self: *PohSequence, num_hashes: u64) !void {
        const entry = PohEntry.init(self.current_hash, num_hashes);
        try self.entries.append(entry);
    }
    
    // Mix in external data (like transaction hash)
    pub fn mixIn(self: *PohSequence, data: []const u8) void {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(std.mem.asBytes(&self.current_hash));
        hasher.update(data);
        hasher.final(&self.current_hash);
        self.tick_count += 1;
    }
    
    pub fn getCurrentHash(self: *const PohSequence) [32]u8 {
        return self.current_hash;
    }
    
    pub fn getTickCount(self: *const PohSequence) u64 {
        return self.tick_count;
    }
    
    pub fn getEntryCount(self: *const PohSequence) usize {
        return self.entries.items.len;
    }
};

// Proof of History Verifier
pub const PohVerifier = struct {
    pub fn verifySequence(entries: []const PohEntry, initial_hash: [32]u8) bool {
        if (entries.len == 0) return true;
        
        var current_hash = initial_hash;
        
        for (entries) |entry| {
            // Verify that the entry hash matches the expected hash after num_hashes iterations
            var temp_hash = current_hash;
            var i: u64 = 0;
            while (i < entry.num_hashes) : (i += 1) {
                temp_hash = crypto.sha256Raw(std.mem.asBytes(&temp_hash));
            }
            
            if (!std.mem.eql(u8, &temp_hash, &entry.hash)) {
                return false;
            }
            
            current_hash = entry.hash;
        }
        
        return true;
    }
    
    pub fn verifyEntry(prev_hash: [32]u8, entry: PohEntry) bool {
        var hash = prev_hash;
        var i: u64 = 0;
        while (i < entry.num_hashes) : (i += 1) {
            hash = crypto.sha256Raw(std.mem.asBytes(&hash));
        }
        
        return std.mem.eql(u8, &hash, &entry.hash);
    }
};

// Leader Schedule - determines which node is the leader at what time
pub const LeaderSchedule = struct {
    leaders: std.ArrayList([]const u8),
    slot_duration_ms: u64,
    current_slot: u64,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, slot_duration_ms: u64) LeaderSchedule {
        return LeaderSchedule{
            .leaders = std.ArrayList([]const u8).init(allocator),
            .slot_duration_ms = slot_duration_ms,
            .current_slot = 0,
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *LeaderSchedule) void {
        for (self.leaders.items) |leader| {
            self.allocator.free(leader);
        }
        self.leaders.deinit();
    }
    
    pub fn addLeader(self: *LeaderSchedule, leader_id: []const u8) !void {
        const owned_id = try self.allocator.dupe(u8, leader_id);
        try self.leaders.append(owned_id);
    }
    
    pub fn getCurrentLeader(self: *const LeaderSchedule) ?[]const u8 {
        if (self.leaders.items.len == 0) return null;
        const leader_index = self.current_slot % self.leaders.items.len;
        return self.leaders.items[leader_index];
    }
    
    pub fn advanceSlot(self: *LeaderSchedule) void {
        self.current_slot += 1;
    }
    
    pub fn isLeader(self: *const LeaderSchedule, node_id: []const u8) bool {
        const current_leader = self.getCurrentLeader() orelse return false;
        return std.mem.eql(u8, current_leader, node_id);
    }
};

// Consensus Engine combining PoH with leader rotation
pub const ConsensusEngine = struct {
    poh_sequence: PohSequence,
    leader_schedule: LeaderSchedule,
    node_id: []const u8,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, node_id: []const u8) !ConsensusEngine {
        var engine = ConsensusEngine{
            .poh_sequence = PohSequence.init(allocator, null),
            .leader_schedule = LeaderSchedule.init(allocator, 400), // 400ms slots
            .node_id = try allocator.dupe(u8, node_id),
            .allocator = allocator,
        };
        
        // Add some initial leaders for demo
        try engine.leader_schedule.addLeader("leader1");
        try engine.leader_schedule.addLeader("leader2");
        try engine.leader_schedule.addLeader("leader3");
        
        return engine;
    }
    
    pub fn deinit(self: *ConsensusEngine) void {
        self.poh_sequence.deinit();
        self.leader_schedule.deinit();
        self.allocator.free(self.node_id);
    }
    
    pub fn isCurrentLeader(self: *const ConsensusEngine) bool {
        return self.leader_schedule.isLeader(self.node_id);
    }
    
    pub fn processSlot(self: *ConsensusEngine) !void {
        // Generate PoH ticks for this slot
        const ticks_per_slot = 64; // Configurable
        self.poh_sequence.tickN(ticks_per_slot);
        
        // Record entry for this slot
        try self.poh_sequence.recordEntry(ticks_per_slot);
        
        // Advance to next slot
        self.leader_schedule.advanceSlot();
        
        std.debug.print("⏰ Slot {} processed, Leader: {?s}\n", .{ 
            self.leader_schedule.current_slot - 1, 
            self.leader_schedule.getCurrentLeader() 
        });
    }
    
    pub fn processTransaction(self: *ConsensusEngine, tx_data: []const u8) !void {
        // Mix transaction into PoH sequence
        self.poh_sequence.mixIn(tx_data);
        
        // Record the mix-in
        try self.poh_sequence.recordEntry(1);
        
        std.debug.print("💸 Transaction processed in PoH sequence\n", .{});
    }
    
    pub fn getCurrentPohState(self: *const ConsensusEngine) struct { hash: [32]u8, tick_count: u64 } {
        return .{
            .hash = self.poh_sequence.getCurrentHash(),
            .tick_count = self.poh_sequence.getTickCount(),
        };
    }
};

test "poh sequence generation" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var poh = PohSequence.init(allocator, null);
    defer poh.deinit();
    
    const initial_hash = poh.getCurrentHash();
    poh.tick();
    const after_tick = poh.getCurrentHash();
    
    try testing.expect(!std.mem.eql(u8, &initial_hash, &after_tick));
    try testing.expect(poh.getTickCount() == 1);
}

test "poh verification" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var poh = PohSequence.init(allocator, null);
    defer poh.deinit();
    
    const initial_hash = poh.getCurrentHash();
    poh.tickN(10);
    try poh.recordEntry(10);
    
    const is_valid = PohVerifier.verifySequence(poh.entries.items, initial_hash);
    try testing.expect(is_valid);
}

test "leader schedule" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var schedule = LeaderSchedule.init(allocator, 400);
    defer schedule.deinit();
    
    try schedule.addLeader("leader1");
    try schedule.addLeader("leader2");
    
    const leader1 = schedule.getCurrentLeader();
    try testing.expect(std.mem.eql(u8, leader1.?, "leader1"));
    
    schedule.advanceSlot();
    const leader2 = schedule.getCurrentLeader();
    try testing.expect(std.mem.eql(u8, leader2.?, "leader2"));
}

test "consensus engine" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var engine = try ConsensusEngine.init(allocator, "test_node");
    defer engine.deinit();
    
    try engine.processSlot();
    try engine.processTransaction("test_transaction");
    
    const state = engine.getCurrentPohState();
    try testing.expect(state.tick_count > 0);
}