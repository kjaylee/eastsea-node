const std = @import("std");
const crypto = @import("../crypto/hash.zig");
const blockchain = @import("../blockchain/blockchain.zig");

/// Attestation represents a verifiable claim about an entity or action
pub const Attestation = struct {
    /// Unique identifier for the attestation
    id: [32]u8,
    
    /// Schema identifier defining the structure of the attestation
    schema_id: [32]u8,
    
    /// Address of the attester (the entity making the claim)
    attester: [20]u8,
    
    /// Address of the recipient (the entity the claim is about)
    recipient: [20]u8,
    
    /// Unix timestamp when the attestation was created
    timestamp: u64,
    
    /// Expiration timestamp (0 if never expires)
    expiration: u64,
    
    /// Revocation timestamp (0 if not revoked)
    revocation_time: u64,
    
    /// Reference to data (could be on-chain or off-chain)
    data: []const u8,
    
    /// Cryptographic signature by the attester
    signature: [64]u8,
    
    /// Hash of the attestation for verification
    hash: [32]u8,
    
    /// Flag indicating if this is a private attestation
    is_private: bool,
    
    /// Zero-knowledge proof for private attestations (null if not private)
    zk_proof: ?[]const u8,
    
    /// Public inputs for zk-SNARK verification (null if not private)
    public_inputs: ?[]const u8,
    
    allocator: std.mem.Allocator,
    
    pub fn init(
        allocator: std.mem.Allocator,
        schema_id: [32]u8,
        attester: [20]u8,
        recipient: [20]u8,
        expiration: u64,
        data: []const u8,
        is_private: bool,
    ) !Attestation {
        var id: [32]u8 = undefined;
        std.crypto.random.bytes(&id);
        
        const timestamp = @as(u64, @intCast(std.time.timestamp()));
        
        // Create attestation with zeroed signature and hash initially
        var attestation = Attestation{
            .id = id,
            .schema_id = schema_id,
            .attester = attester,
            .recipient = recipient,
            .timestamp = timestamp,
            .expiration = expiration,
            .revocation_time = 0,
            .data = try allocator.dupe(u8, data),
            .signature = [_]u8{0} ** 64,
            .hash = [_]u8{0} ** 32,
            .is_private = is_private,
            .zk_proof = if (is_private) try allocator.dupe(u8, "") else null,
            .public_inputs = if (is_private) try allocator.dupe(u8, "") else null,
            .allocator = allocator,
        };
        
        // Calculate hash
        attestation.hash = attestation.calculateHash();
        
        return attestation;
    }
    
    pub fn deinit(self: *Attestation) void {
        self.allocator.free(self.data);
        if (self.zk_proof) |proof| {
            self.allocator.free(proof);
        }
        if (self.public_inputs) |inputs| {
            self.allocator.free(inputs);
        }
    }
    
    /// Calculate the hash of the attestation
    pub fn calculateHash(self: *const Attestation) [32]u8 {
        // Create a buffer with all attestation data except signature
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();
        
        // Add all fields except signature to the buffer
        buffer.appendSlice(std.mem.asBytes(&self.id)) catch unreachable;
        buffer.appendSlice(std.mem.asBytes(&self.schema_id)) catch unreachable;
        buffer.appendSlice(std.mem.asBytes(&self.attester)) catch unreachable;
        buffer.appendSlice(std.mem.asBytes(&self.recipient)) catch unreachable;
        buffer.appendSlice(std.mem.asBytes(&self.timestamp)) catch unreachable;
        buffer.appendSlice(std.mem.asBytes(&self.expiration)) catch unreachable;
        buffer.appendSlice(std.mem.asBytes(&self.revocation_time)) catch unreachable;
        buffer.appendSlice(self.data) catch unreachable;
        buffer.appendSlice(std.mem.asBytes(&self.hash)) catch unreachable;
        buffer.appendSlice(std.mem.asBytes(&self.is_private)) catch unreachable;
        
        if (self.zk_proof) |proof| {
            buffer.appendSlice(proof) catch unreachable;
        }
        
        if (self.public_inputs) |inputs| {
            buffer.appendSlice(inputs) catch unreachable;
        }
        
        return crypto.sha256Raw(buffer.items);
    }
    
    /// Sign the attestation with the attester's private key
    pub fn sign(self: *Attestation, private_key: [32]u8) !void {
        _ = private_key; // Use the parameter to avoid warning
        // In a real implementation, this would use proper ECDSA signing
        // For this example, we'll simulate a signature
        std.crypto.random.bytes(&self.signature);
        
        // For private attestations, generate a zk-SNARK proof
        if (self.is_private) {
            // In a real implementation, this would generate an actual zk-SNARK proof
            // For this example, we'll create a more realistic simulation:
            // 1. Hash the attestation data
            // 2. Create a commitment to the data
            // 3. Generate a proof that the commitment corresponds to the data
            
            var data_hash: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(self.data, &data_hash, .{});
            
            // Create a buffer for the proof
            var buffer: [64]u8 = undefined;
            @memcpy(buffer[0..32], &data_hash);
            
            // Add a random nonce
            var nonce: [32]u8 = undefined;
            std.crypto.random.bytes(&nonce);
            @memcpy(buffer[32..64], &nonce);
            
            // Hash everything together to create the final proof
            var proof_hash: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(&buffer, &proof_hash, .{});
            
            if (self.zk_proof) |*proof| {
                self.allocator.free(proof.*);
                const new_proof = try self.allocator.alloc(u8, 32);
                @memcpy(new_proof, &proof_hash);
                proof.* = new_proof;
            }
            
            // For public inputs, we'll use a simple placeholder
            if (self.public_inputs) |*inputs| {
                self.allocator.free(inputs.*);
                inputs.* = try self.allocator.dupe(u8, "public_inputs_placeholder");
            }
        }
        
        // Update hash after signing
        self.hash = self.calculateHash();
    }
    
    /// Verify the attestation signature
    pub fn verify(self: *const Attestation) bool {
        // For private attestations, verify the zk-SNARK proof
        if (self.is_private) {
            // In a real implementation, this would verify the actual zk-SNARK proof
            // For this example, we'll do a more realistic verification:
            // 1. Check that the proof and public inputs exist
            // 2. Verify the proof has the correct format
            // 3. (In a real implementation) Verify the proof against the public inputs
            
            if (self.zk_proof == null or self.public_inputs == null) {
                return false;
            }
            
            // Check that proof has the correct length (32 bytes for our SHA-256 hash)
            if (self.zk_proof.?.len != 32) {
                return false;
            }
            
            // Check that inputs are not empty
            if (self.public_inputs.?.len == 0) {
                return false;
            }
            
            // In a real implementation, we would verify the zk-SNARK proof here
            // For this simulation, we'll just check the format
            return true;
        }
        
        // In a real implementation, this would verify the ECDSA signature
        // For this example, we'll just check that the signature is not all zeros
        for (self.signature) |byte| {
            if (byte != 0) {
                return true;
            }
        }
        return false;
    }
    
    /// Check if the attestation is expired
    pub fn isExpired(self: *const Attestation) bool {
        if (self.expiration == 0) return false; // Never expires
        const current_time = @as(u64, @intCast(std.time.timestamp()));
        return current_time > self.expiration;
    }
    
    /// Check if the attestation has been revoked
    pub fn isRevoked(self: *const Attestation) bool {
        return self.revocation_time != 0;
    }
    
    /// Check if the attestation is valid (not expired and not revoked)
    pub fn isValid(self: *const Attestation) bool {
        return !self.isExpired() and !self.isRevoked() and self.verify();
    }
    
    /// Create a private version of this attestation for selective disclosure
    pub fn createPrivateVersion(self: *const Attestation, allocator: std.mem.Allocator) !Attestation {
        // Only public attestations can be converted to private
        if (self.is_private) {
            return error.AlreadyPrivate;
        }
        
        // Create initial private attestation
        var private_attestation = try Attestation.init(
            allocator,
            self.schema_id,
            self.attester,
            self.recipient,
            self.expiration,
            self.data,
            true, // is_private
        );
        
        // Copy other properties
        private_attestation.timestamp = self.timestamp;
        private_attestation.revocation_time = self.revocation_time;
        
        // Generate zk-SNARK proof for private attestation
        // In a real implementation, this would use a proper zk-SNARK library
        std.crypto.random.bytes(&private_attestation.signature);
        
        // For private attestations, generate a zk-SNARK proof
        // In a real implementation, this would generate an actual zk-SNARK proof
        // For this example, we'll create a more realistic simulation:
        // 1. Hash the attestation data
        // 2. Create a commitment to the data
        // 3. Generate a proof that the commitment corresponds to the data
        
        var data_hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(self.data, &data_hash, .{});
        
        // Create a buffer for the proof
        var buffer: [64]u8 = undefined;
        @memcpy(buffer[0..32], &data_hash);
        
        // Add a random nonce
        var nonce: [32]u8 = undefined;
        std.crypto.random.bytes(&nonce);
        @memcpy(buffer[32..64], &nonce);
        
        // Hash everything together to create the final proof
        var proof_hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&buffer, &proof_hash, .{});
        
        if (private_attestation.zk_proof) |*proof| {
            allocator.free(proof.*);
            const new_proof = try allocator.alloc(u8, 32);
            @memcpy(new_proof, &proof_hash);
            proof.* = new_proof;
        }
        
        // For public inputs, we'll use a simple placeholder
        if (private_attestation.public_inputs) |*inputs| {
            allocator.free(inputs.*);
            inputs.* = try allocator.dupe(u8, "public_inputs_placeholder");
        }
        
        // Update hash after making changes
        private_attestation.hash = private_attestation.calculateHash();
        
        return private_attestation;
    }
    
    /// Get the public data that can be revealed in a selective disclosure
    pub fn getPublicData(self: *const Attestation) ?[]const u8 {
        // For private attestations, only some data can be revealed
        if (self.is_private) {
            // In a real implementation, this would return only the selectively disclosed data
            // For this example, we'll just return a placeholder
            return "public_data_placeholder";
        }
        
        // For public attestations, all data can be revealed
        return self.data;
    }
};

/// Schema defines the structure and validation rules for an attestation type
pub const Schema = struct {
    /// Unique identifier for the schema
    id: [32]u8,
    
    /// Name of the schema
    name: []const u8,
    
    /// Description of what the schema represents
    description: []const u8,
    
    /// JSON schema definition
    definition: []const u8,
    
    /// Address of the schema creator
    creator: [20]u8,
    
    /// Unix timestamp when the schema was created
    timestamp: u64,
    
    allocator: std.mem.Allocator,
    
    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        description: []const u8,
        definition: []const u8,
        creator: [20]u8,
    ) !Schema {
        var id: [32]u8 = undefined;
        std.crypto.random.bytes(&id);
        
        return Schema{
            .id = id,
            .name = try allocator.dupe(u8, name),
            .description = try allocator.dupe(u8, description),
            .definition = try allocator.dupe(u8, definition),
            .creator = creator,
            .timestamp = @as(u64, @intCast(std.time.timestamp())),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Schema) void {
        self.allocator.free(self.name);
        self.allocator.free(self.description);
        self.allocator.free(self.definition);
    }
};

/// Attester represents an entity that can create attestations
pub const Attester = struct {
    /// Unique identifier for the attester
    id: [20]u8,
    
    /// Public name or description
    name: []const u8,
    
    /// Reputation score (higher is better)
    reputation: u64,
    
    /// Number of attestations created
    attestation_count: u64,
    
    /// Timestamp of when the attester was registered
    registration_time: u64,
    
    /// Whether the attester is currently active
    is_active: bool,
    
    allocator: std.mem.Allocator,
    
    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        id: [20]u8,
    ) !Attester {
        return Attester{
            .id = id,
            .name = try allocator.dupe(u8, name),
            .reputation = 100, // Starting reputation
            .attestation_count = 0,
            .registration_time = @as(u64, @intCast(std.time.timestamp())),
            .is_active = true,
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Attester) void {
        self.allocator.free(self.name);
    }
    
    /// Increase the attester's reputation
    pub fn increaseReputation(self: *Attester, amount: u64) void {
        self.reputation += amount;
    }
    
    /// Decrease the attester's reputation
    pub fn decreaseReputation(self: *Attester, amount: u64) void {
        if (self.reputation > amount) {
            self.reputation -= amount;
        } else {
            self.reputation = 0;
        }
    }
    
    /// Increment the attestation count
    pub fn incrementAttestationCount(self: *Attester) void {
        self.attestation_count += 1;
    }
};

/// AttestationService provides the core functionality for creating and managing attestations
pub const AttestationService = struct {
    /// Allocator for memory management
    allocator: std.mem.Allocator,
    
    /// Registry of schemas
    schemas: std.AutoHashMap([32]u8, Schema),
    
    /// Registry of attesters
    attesters: std.AutoHashMap([20]u8, Attester),
    
    /// Storage for attestations
    attestations: std.AutoHashMap([32]u8, Attestation),
    
    /// Blockchain reference for on-chain storage (optional)
    blockchain_ref: ?*blockchain.Blockchain,
    
    pub fn init(allocator: std.mem.Allocator) AttestationService {
        return AttestationService{
            .allocator = allocator,
            .schemas = std.AutoHashMap([32]u8, Schema).init(allocator),
            .attesters = std.AutoHashMap([20]u8, Attester).init(allocator),
            .attestations = std.AutoHashMap([32]u8, Attestation).init(allocator),
            .blockchain_ref = null,
        };
    }
    
    pub fn deinit(self: *AttestationService) void {
        // Clean up schemas - they are stored by value, no need to deinit each one
        self.schemas.deinit();
        
        // Clean up attesters - they are stored by value, no need to deinit each one
        self.attesters.deinit();
        
        // Clean up attestations - they are stored by value, but we need to free their data
        var attestation_it = self.attestations.iterator();
        while (attestation_it.next()) |entry| {
            var attestation = entry.value_ptr;
            attestation.allocator.free(attestation.data);
            
            // Free zk_proof if it exists
            if (attestation.zk_proof) |proof| {
                attestation.allocator.free(proof);
            }
            
            // Free public_inputs if it exists
            if (attestation.public_inputs) |inputs| {
                attestation.allocator.free(inputs);
            }
        }
        self.attestations.deinit();
    }
    
    /// Set blockchain reference
    pub fn setBlockchain(self: *AttestationService, blockchain_ref: *blockchain.Blockchain) void {
        self.blockchain_ref = blockchain_ref;
    }
    
    /// Register a new schema
    pub fn registerSchema(self: *AttestationService, schema: Schema) !void {
        try self.schemas.put(schema.id, schema);
        std.debug.print("✅ Registered schema: {s}\n", .{schema.name});
    }
    
    /// Get a schema by ID
    pub fn getSchema(self: *AttestationService, schema_id: [32]u8) ?*Schema {
        return self.schemas.getPtr(schema_id);
    }
    
    /// Register a new attester
    pub fn registerAttester(self: *AttestationService, attester: Attester) !void {
        try self.attesters.put(attester.id, attester);
        std.debug.print("✅ Registered attester: {s}\n", .{attester.name});
    }
    
    /// Get an attester by ID
    pub fn getAttester(self: *AttestationService, attester_id: [20]u8) ?*Attester {
        return self.attesters.getPtr(attester_id);
    }
    
    /// Create a new attestation
    pub fn createAttestation(
        self: *AttestationService,
        schema_id: [32]u8,
        attester_id: [20]u8,
        recipient: [20]u8,
        expiration: u64,
        data: []const u8,
        private_key: [32]u8,
        is_private: bool,
    ) !*Attestation {
        // Verify schema exists
        if (self.getSchema(schema_id) == null) {
            std.debug.print("❌ Schema not found\n", .{});
            return error.SchemaNotFound;
        }
        
        // Verify attester exists and is active
        const attester = self.getAttester(attester_id) orelse {
            std.debug.print("❌ Attester not found\n", .{});
            return error.AttesterNotFound;
        };
        
        if (!attester.is_active) {
            std.debug.print("❌ Attester is not active\n", .{});
            return error.AttesterNotActive;
        }
        
        // Create attestation
        var attestation = try Attestation.init(
            self.allocator,
            schema_id,
            attester_id,
            recipient,
            expiration,
            data,
            is_private,
        );
        
        // Sign attestation
        try attestation.sign(private_key);
        
        // Store attestation by value in the HashMap
        try self.attestations.put(attestation.id, attestation);
        
        // Update attester stats
        attester.incrementAttestationCount();
        attester.increaseReputation(1);
        
        std.debug.print("✅ Created attestation ID: {}\n", .{
            std.fmt.fmtSliceHexLower(&attestation.id),
        });
        
        // Return pointer to stored attestation
        return self.attestations.getPtr(attestation.id).?;
    }
    
    /// Create a private attestation with selective disclosure
    pub fn createPrivateAttestation(
        self: *AttestationService,
        schema_id: [32]u8,
        attester_id: [20]u8,
        recipient: [20]u8,
        expiration: u64,
        data: []const u8,
        private_key: [32]u8,
    ) !*Attestation {
        // Create a regular attestation first
        const regular_attestation = try self.createAttestation(
            schema_id,
            attester_id,
            recipient,
            expiration,
            data,
            private_key,
            false, // is_private=false for regular attestation
        );
        
        // Convert to private attestation
        var private_attestation = try regular_attestation.createPrivateVersion(self.allocator);
        
        // Store the private attestation
        try self.attestations.put(private_attestation.id, private_attestation);
        
        std.debug.print("✅ Created private attestation ID: {}\n", .{
            std.fmt.fmtSliceHexLower(&private_attestation.id),
        });
        
        // Return pointer to stored attestation
        return self.attestations.getPtr(private_attestation.id).?;
    }
    
    /// Get an attestation by ID
    pub fn getAttestation(self: *AttestationService, attestation_id: [32]u8) ?*Attestation {
        return self.attestations.getPtr(attestation_id);
    }
    
    /// Revoke an attestation
    pub fn revokeAttestation(self: *AttestationService, attestation_id: [32]u8) !void {
        const attestation = self.getAttestation(attestation_id) orelse {
            std.debug.print("❌ Attestation not found\n", .{});
            return error.AttestationNotFound;
        };
        
        attestation.revocation_time = @as(u64, @intCast(std.time.timestamp()));
        std.debug.print("✅ Revoked attestation ID: {}\n", .{
            std.fmt.fmtSliceHexLower(&attestation_id),
        });
    }
    
    /// Verify an attestation
    pub fn verifyAttestation(self: *AttestationService, attestation_id: [32]u8) bool {
        const attestation = self.getAttestation(attestation_id) orelse {
            std.debug.print("❌ Attestation not found\n", .{});
            return false;
        };
        
        return attestation.isValid();
    }
    
    /// Get all attestations for a recipient
    pub fn getAttestationsForRecipient(self: *AttestationService, recipient: [20]u8) !std.ArrayList(*Attestation) {
        var result = std.ArrayList(*Attestation).init(self.allocator);
        
        var it = self.attestations.iterator();
        while (it.next()) |entry| {
            const attestation = entry.value_ptr;
            if (std.mem.eql(u8, &attestation.recipient, &recipient)) {
                try result.append(self.attestations.getPtr(entry.key_ptr.*).?);
            }
        }
        
        return result;
    }
    
    /// Get all attestations by an attester
    pub fn getAttestationsByAttester(self: *AttestationService, attester_id: [20]u8) !std.ArrayList(*Attestation) {
        var result = std.ArrayList(*Attestation).init(self.allocator);
        
        var it = self.attestations.iterator();
        while (it.next()) |entry| {
            const attestation = entry.value_ptr;
            if (std.mem.eql(u8, &attestation.attester, &attester_id)) {
                try result.append(self.attestations.getPtr(entry.key_ptr.*).?);
            }
        }
        
        return result;
    }
};

// Test functions
test "attestation creation and verification" {
    const allocator = std.testing.allocator;
    
    // Create attestation service
    var service = AttestationService.init(allocator);
    defer service.deinit();
    
    // Create schema
    var schema = try Schema.init(
        allocator,
        "Test Schema",
        "A test schema for demonstration",
        "{\"type\": \"object\", \"properties\": {\"score\": {\"type\": \"number\"}}}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    
    // Register schema
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try Attester.init(
        allocator,
        "Test Attester",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    
    // Register attester
    try service.registerAttester(attester);
    
    // Create attestation
    const private_key = [_]u8{3} ** 32;
    const attestation = try service.createAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        "Test data",
        private_key,
    );
    
    // Verify attestation
    try std.testing.expect(service.verifyAttestation(attestation.id));
    
    // Test getting attestations by recipient
    const recipient_attestations = try service.getAttestationsForRecipient([_]u8{4} ** 20);
    defer recipient_attestations.deinit();
    try std.testing.expect(recipient_attestations.items.len == 1);
    
    // Test getting attestations by attester
    const attester_attestations = try service.getAttestationsByAttester(attester.id);
    defer attester_attestations.deinit();
    try std.testing.expect(attester_attestations.items.len == 1);
}

test "attestation expiration" {
    const allocator = std.testing.allocator;
    
    // Create attestation service
    var service = AttestationService.init(allocator);
    defer service.deinit();
    
    // Create schema
    var schema = try Schema.init(
        allocator,
        "Test Schema",
        "A test schema for demonstration",
        "{\"type\": \"object\"}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    
    // Register schema
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try Attester.init(
        allocator,
        "Test Attester",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    
    // Register attester
    try service.registerAttester(attester);
    
    // Create expired attestation
    const private_key = [_]u8{3} ** 32;
    const attestation = try service.createAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        @as(u64, @intCast(std.time.timestamp())) - 1000, // Expired 1000 seconds ago
        "Test data",
        private_key,
    );
    
    // Verify attestation is not valid (expired)
    try std.testing.expect(!service.verifyAttestation(attestation.id));
}

test "attestation revocation" {
    const allocator = std.testing.allocator;
    
    // Create attestation service
    var service = AttestationService.init(allocator);
    defer service.deinit();
    
    // Create schema
    var schema = try Schema.init(
        allocator,
        "Test Schema",
        "A test schema for demonstration",
        "{\"type\": \"object\"}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    
    // Register schema
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try Attester.init(
        allocator,
        "Test Attester",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    
    // Register attester
    try service.registerAttester(attester);
    
    // Create attestation
    const private_key = [_]u8{3} ** 32;
    const attestation = try service.createAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        "Test data",
        private_key,
    );
    
    // Verify attestation is valid before revocation
    try std.testing.expect(service.verifyAttestation(attestation.id));
    
    // Revoke attestation
    try service.revokeAttestation(attestation.id);
    
    // Verify attestation is not valid after revocation
    try std.testing.expect(!service.verifyAttestation(attestation.id));
}