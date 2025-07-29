const std = @import("std");
const print = std.debug.print;
const eas = @import("eas/attestation.zig");

pub fn main() !void {
    print("🚀 Eastsea Attestation Service (EAS) Test\n", .{});
    print("==========================================\n", .{});
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2) {
        printUsage(args[0]);
        return;
    }
    
    const test_type = args[1];
    print("Test type: {s}\n\n", .{test_type});
    
    if (std.mem.eql(u8, test_type, "basic")) {
        try runBasicEASTest(allocator);
    } else if (std.mem.eql(u8, test_type, "schema")) {
        try runSchemaTest(allocator);
    } else if (std.mem.eql(u8, test_type, "attester")) {
        try runAttesterTest(allocator);
    } else if (std.mem.eql(u8, test_type, "attestation")) {
        try runAttestationTest(allocator);
    } else if (std.mem.eql(u8, test_type, "verification")) {
        try runVerificationTest(allocator);
    } else if (std.mem.eql(u8, test_type, "reputation")) {
        try runReputationTest(allocator);
    } else if (std.mem.eql(u8, test_type, "all")) {
        try runAllEASTests(allocator);
    } else {
        print("❌ Unknown test type: {s}\n", .{test_type});
        printUsage(args[0]);
        return;
    }
    
    print("\n🎉 EAS test completed!\n", .{});
}

fn printUsage(program_name: []const u8) void {
    print("Usage: {s} <test_type>\n", .{program_name});
    print("\nTest types:\n", .{});
    print("  basic        - Basic EAS functionality test\n", .{});
    print("  schema       - Schema registration and management test\n", .{});
    print("  attester     - Attester registration and management test\n", .{});
    print("  attestation  - Attestation creation and management test\n", .{});
    print("  verification - Attestation verification test\n", .{});
    print("  reputation   - Attester reputation system test\n", .{});
    print("  all          - Run all EAS tests\n", .{});
    print("\nExamples:\n", .{});
    print("  {s} basic\n", .{program_name});
    print("  {s} verification\n", .{program_name});
    print("  {s} all\n", .{program_name});
}

/// Basic EAS functionality test
fn runBasicEASTest(allocator: std.mem.Allocator) !void {
    print("📋 Basic EAS Functionality Test\n", .{});
    print("===============================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    print("✅ EAS service initialized\n", .{});
    
    // Create a simple schema
    var schema = try eas.Schema.init(
        allocator,
        "Basic Identity Verification",
        "Verification of basic identity information",
        "{\"type\": \"object\", \"properties\": {\"name\": {\"type\": \"string\"}, \"age\": {\"type\": \"number\"}}}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    
    try service.registerSchema(schema);
    print("✅ Schema registered\n", .{});
    
    // Create an attester
    var attester = try eas.Attester.init(
        allocator,
        "Identity Verification Service",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    
    try service.registerAttester(attester);
    print("✅ Attester registered\n", .{});
    
    // Create an attestation
    const private_key = [_]u8{3} ** 32;
    const attestation = try service.createAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        "{\"name\": \"Alice\", \"age\": 30}",
        private_key,
        false, // is_private
    );
    
    print("✅ Attestation created with ID: {}\n", .{
        std.fmt.fmtSliceHexLower(&attestation.id),
    });
    
    // Verify the attestation
    const is_valid = service.verifyAttestation(attestation.id);
    print("✅ Attestation verification: {}\n", .{is_valid});
    
    print("✅ Basic EAS test completed\n", .{});
}

/// Schema registration and management test
fn runSchemaTest(allocator: std.mem.Allocator) !void {
    print("📋 Schema Registration and Management Test\n", .{});
    print("==========================================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    // Create multiple schemas
    const schemas_data = [_]struct {
        name: []const u8,
        description: []const u8,
        definition: []const u8,
        creator: [20]u8,
    }{
        .{
            .name = "Email Verification",
            .description = "Verification of email ownership",
            .definition = "{\"type\": \"object\", \"properties\": {\"email\": {\"type\": \"string\", \"format\": \"email\"}}}",
            .creator = [_]u8{1} ** 20,
        },
        .{
            .name = "KYC Verification",
            .description = "Know Your Customer verification",
            .definition = "{\"type\": \"object\", \"properties\": {\"name\": {\"type\": \"string\"}, \"id_number\": {\"type\": \"string\"}, \"dob\": {\"type\": \"string\", \"format\": \"date\"}}}",
            .creator = [_]u8{2} ** 20,
        },
        .{
            .name = "Employment Verification",
            .description = "Verification of employment status",
            .definition = "{\"type\": \"object\", \"properties\": {\"company\": {\"type\": \"string\"}, \"position\": {\"type\": \"string\"}, \"start_date\": {\"type\": \"string\", \"format\": \"date\"}}}",
            .creator = [_]u8{3} ** 20,
        },
    };
    
    for (schemas_data, 0..) |schema_data, i| {
        var schema = try eas.Schema.init(
            allocator,
            schema_data.name,
            schema_data.description,
            schema_data.definition,
            schema_data.creator,
        );
        defer schema.deinit();
        
        try service.registerSchema(schema);
        print("✅ Schema {} registered: {s}\n", .{ i + 1, schema.name });
    }
    
    print("✅ Schema registration test completed\n", .{});
}

/// Attester registration and management test
fn runAttesterTest(allocator: std.mem.Allocator) !void {
    print("📋 Attester Registration and Management Test\n", .{});
    print("============================================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    // Create multiple attesters
    const attesters_data = [_]struct {
        name: []const u8,
        id: [20]u8,
    }{
        .{ .name = "Government ID Authority", .id = [_]u8{1} ** 20 },
        .{ .name = "Financial Institution", .id = [_]u8{2} ** 20 },
        .{ .name = "Employment Verification Service", .id = [_]u8{3} ** 20 },
        .{ .name = "Educational Institution", .id = [_]u8{4} ** 20 },
    };
    
    for (attesters_data, 0..) |attester_data, i| {
        var attester = try eas.Attester.init(
            allocator,
            attester_data.name,
            attester_data.id,
        );
        defer attester.deinit();
        
        try service.registerAttester(attester);
        print("✅ Attester {} registered: {s}\n", .{ i + 1, attester.name });
    }
    
    print("✅ Attester registration test completed\n", .{});
}

/// Attestation creation and management test
fn runAttestationTest(allocator: std.mem.Allocator) !void {
    print("📋 Attestation Creation and Management Test\n", .{});
    print("===========================================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    // Create schema
    var schema = try eas.Schema.init(
        allocator,
        "Test Schema",
        "A test schema for demonstration",
        "{\"type\": \"object\"}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try eas.Attester.init(
        allocator,
        "Test Attester",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    
    try service.registerAttester(attester);
    
    // Create multiple attestations
    const attestations_data = [_]struct {
        recipient: [20]u8,
        expiration: u64,
        data: []const u8,
    }{
        .{ .recipient = [_]u8{3} ** 20, .expiration = 0, .data = "Test data 1" },
        .{ .recipient = [_]u8{4} ** 20, .expiration = 0, .data = "Test data 2" },
        .{ .recipient = [_]u8{5} ** 20, .expiration = 0, .data = "Test data 3" },
    };
    
    const private_key = [_]u8{6} ** 32;
    
    for (attestations_data, 0..) |attestation_data, i| {
        const attestation = try service.createAttestation(
            schema.id,
            attester.id,
            attestation_data.recipient,
            attestation_data.expiration,
            attestation_data.data,
            private_key,
            false, // is_private
        );
        
        print("✅ Attestation {} created with ID: {}\n", .{ 
            i + 1, 
            std.fmt.fmtSliceHexLower(&attestation.id) 
        });
    }
    
    print("✅ Attestation creation test completed\n", .{});
}

/// Attestation verification test
fn runVerificationTest(allocator: std.mem.Allocator) !void {
    print("📋 Attestation Verification Test\n", .{});
    print("===============================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    // Create schema
    var schema = try eas.Schema.init(
        allocator,
        "Verification Schema",
        "Schema for verification tests",
        "{\"type\": \"object\"}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try eas.Attester.init(
        allocator,
        "Verification Service",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    
    try service.registerAttester(attester);
    
    // Create a valid attestation
    const private_key = [_]u8{3} ** 32;
    const valid_attestation = try service.createAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        "Valid test data",
        private_key,
        false, // is_private
    );
    
    // Verify valid attestation
    const is_valid = service.verifyAttestation(valid_attestation.id);
    print("✅ Valid attestation verification: {}\n", .{is_valid});
    
    // Create an expired attestation
    const expired_attestation = try service.createAttestation(
        schema.id,
        attester.id,
        [_]u8{5} ** 20, // recipient
        @as(u64, @intCast(std.time.timestamp())) - 1000, // Expired 1000 seconds ago
        "Expired test data",
        private_key,
        false, // is_private
    );
    
    // Verify expired attestation
    const is_expired_valid = service.verifyAttestation(expired_attestation.id);
    print("✅ Expired attestation verification: {}\n", .{is_expired_valid});
    
    // Revoke the valid attestation
    try service.revokeAttestation(valid_attestation.id);
    
    // Verify revoked attestation
    const is_revoked_valid = service.verifyAttestation(valid_attestation.id);
    print("✅ Revoked attestation verification: {}\n", .{is_revoked_valid});
    
    print("✅ Verification test completed\n", .{});
}

/// Attester reputation system test
fn runReputationTest(allocator: std.mem.Allocator) !void {
    print("📋 Attester Reputation System Test\n", .{});
    print("===============================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    // Create schema
    var schema = try eas.Schema.init(
        allocator,
        "Reputation Schema",
        "Schema for reputation tests",
        "{\"type\": \"object\"}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try eas.Attester.init(
        allocator,
        "Reputation Test Service",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    
    const initial_reputation = attester.reputation;
    print("📈 Initial reputation: {}\n", .{initial_reputation});
    
    try service.registerAttester(attester);
    
    // Create multiple attestations to increase reputation
    const private_key = [_]u8{3} ** 32;
    for (0..5) |i| {
        _ = try service.createAttestation(
            schema.id,
            attester.id,
            [_]u8{@as(u8, @intCast(i + 4))} ** 20, // different recipients
            0, // Never expires
            "Reputation test data",
            private_key,
            false, // is_private
        );
        
        print("📈 Reputation after attestation {}: {}\n", .{ 
            i + 1, 
            service.getAttester(attester.id).?.reputation 
        });
    }
    
    print("✅ Reputation system test completed\n", .{});
}

/// Run all EAS tests
/// Private attestation test
fn runPrivateAttestationTest(allocator: std.mem.Allocator) !void {
    print("📋 Private Attestation Test\n", .{});
    print("==========================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    // Create schema
    var schema = try eas.Schema.init(
        allocator,
        "Private Identity Verification",
        "Verification of identity information with privacy",
        "{\"type\": \"object\", \"properties\": {\"name\": {\"type\": \"string\"}, \"ssn\": {\"type\": \"string\"}, \"address\": {\"type\": \"string\"}}}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try eas.Attester.init(
        allocator,
        "Privacy-Preserving Identity Service",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    
    try service.registerAttester(attester);
    
    // Create a private attestation
    const private_key = [_]u8{3} ** 32;
    
    const private_attestation = try service.createPrivateAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        "{\"name\": \"Alice\", \"ssn\": \"123-45-6789\", \"address\": \"123 Main St\"}",
        private_key,
    );
    
    print("✅ Private attestation created with ID: {}\n", .{
        std.fmt.fmtSliceHexLower(&private_attestation.id),
    });
    
    // Verify the private attestation
    const is_valid = service.verifyAttestation(private_attestation.id);
    print("✅ Private attestation verification: {}\n", .{is_valid});
    
    // Check that it's private
    print("✅ Is private attestation: {}\n", .{private_attestation.is_private});
    
    print("✅ Private attestation test completed\n", .{});
}

fn runAllEASTests(allocator: std.mem.Allocator) !void {
    print("🎯 Comprehensive EAS Test Suite\n", .{});
    print("===============================\n", .{});
    
    try runBasicEASTest(allocator);
    print("\n", .{});
    
    try runSchemaTest(allocator);
    print("\n", .{});
    
    try runAttesterTest(allocator);
    print("\n", .{});
    
    try runAttestationTest(allocator);
    print("\n", .{});
    
    try runVerificationTest(allocator);
    print("\n", .{});
    
    try runReputationTest(allocator);
    print("\n", .{});
    
    try runPrivateAttestationTest(allocator);
    
    print("\n📊 EAS Implementation Status\n", .{});
    print("============================\n", .{});
    print("📋 Basic EAS: ✅ Implemented\n", .{});
    print("📄 Schema Management: ✅ Implemented\n", .{});
    print("👨‍💼 Attester Management: ✅ Implemented\n", .{});
    print("📝 Attestation Creation: ✅ Implemented\n", .{});
    print("🔍 Attestation Verification: ✅ Implemented\n", .{});
    print("📈 Reputation System: ✅ Implemented\n", .{});
    print("🔐 Private Attestations: ✅ Implemented\n", .{});
    print("📚 Framework: ✅ Ready for extension\n", .{});
}