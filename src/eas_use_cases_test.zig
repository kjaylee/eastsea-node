const std = @import("std");
const print = std.debug.print;
const eas = @import("eas/attestation.zig");
const UseCases = @import("eas/use_cases.zig").UseCases;

pub fn main() !void {
    print("🚀 Eastsea Attestation Service (EAS) Use Cases Test\n", .{});
    print("==================================================\n", .{});
    
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
    
    if (std.mem.eql(u8, test_type, "kyc")) {
        try runKycTest(allocator);
    } else if (std.mem.eql(u8, test_type, "education")) {
        try runEducationTest(allocator);
    } else if (std.mem.eql(u8, test_type, "age")) {
        try runAgeTest(allocator);
    } else if (std.mem.eql(u8, test_type, "residence")) {
        try runResidenceTest(allocator);
    } else if (std.mem.eql(u8, test_type, "real-estate")) {
        try runRealEstateTest(allocator);
    } else if (std.mem.eql(u8, test_type, "ip")) {
        try runIpTest(allocator);
    } else if (std.mem.eql(u8, test_type, "digital-asset")) {
        try runDigitalAssetTest(allocator);
    } else if (std.mem.eql(u8, test_type, "game")) {
        try runGameAchievementTest(allocator);
    } else if (std.mem.eql(u8, test_type, "community")) {
        try runCommunityParticipationTest(allocator);
    } else if (std.mem.eql(u8, test_type, "all")) {
        try runAllUseCaseTests(allocator);
    } else {
        print("❌ Unknown test type: {s}\n", .{test_type});
        printUsage(args[0]);
        return;
    }
    
    print("\n🎉 EAS use cases test completed!\n", .{});
}

fn printUsage(program_name: []const u8) void {
    print("Usage: {s} <test_type>\n", .{program_name});
    print("\nTest types:\n", .{});
    print("  kyc          - KYC/AML identity verification test\n", .{});
    print("  education    - Educational qualification test\n", .{});
    print("  age          - Age verification test\n", .{});
    print("  residence    - Residence verification test\n", .{});
    print("  real-estate  - Real estate ownership test\n", .{});
    print("  ip           - Intellectual property test\n", .{});
    print("  digital-asset - Digital asset ownership test\n", .{});
    print("  game         - Game achievement test\n", .{});
    print("  community    - Community participation test\n", .{});
    print("  all          - Run all use case tests\n", .{});
    print("\nExamples:\n", .{});
    print("  {s} kyc\n", .{program_name});
    print("  {s} education\n", .{program_name});
    print("  {s} all\n", .{program_name});
}

/// Test KYC/AML identity verification
fn runKycTest(allocator: std.mem.Allocator) !void {
    print("📋 KYC/AML Identity Verification Test\n", .{});
    print("=====================================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    var use_cases = UseCases.init(allocator, &service);
    
    // Create schema
    var schema = try eas.Schema.init(
        allocator,
        "KYC Verification",
        "Verification of identity for regulatory compliance",
        "{\"type\": \"object\", \"properties\": {\"name\": {\"type\": \"string\"}, \"id_number\": {\"type\": \"string\"}, \"dob\": {\"type\": \"string\", \"format\": \"date\"}, \"address\": {\"type\": \"string\"}, \"nationality\": {\"type\": \"string\"}}}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try eas.Attester.init(
        allocator,
        "Government ID Authority",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    try service.registerAttester(attester);
    
    // Create KYC attestation
    const private_key = [_]u8{3} ** 32;
    const kyc_attestation = try use_cases.createKycAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        private_key,
        "John Doe",
        "ID123456789",
        "1990-01-01",
        "123 Main St, Anytown, ST 12345",
        "US",
    );
    
    print("✅ KYC attestation created with ID: {}\n", .{
        std.fmt.fmtSliceHexLower(&kyc_attestation.id),
    });
    
    // Verify the attestation
    const is_valid = service.verifyAttestation(kyc_attestation.id);
    print("✅ KYC attestation verification: {}\n", .{is_valid});
    
    print("✅ KYC test completed\n", .{});
}

/// Test educational qualification verification
fn runEducationTest(allocator: std.mem.Allocator) !void {
    print("📋 Educational Qualification Test\n", .{});
    print("=================================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    var use_cases = UseCases.init(allocator, &service);
    
    // Create schema
    var schema = try eas.Schema.init(
        allocator,
        "Educational Qualification",
        "Verification of educational credentials",
        "{\"type\": \"object\", \"properties\": {\"institution\": {\"type\": \"string\"}, \"degree\": {\"type\": \"string\"}, \"field\": {\"type\": \"string\"}, \"graduation_date\": {\"type\": \"string\", \"format\": \"date\"}, \"gpa\": {\"type\": \"number\"}}}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try eas.Attester.init(
        allocator,
        "University of Example",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    try service.registerAttester(attester);
    
    // Create education attestation
    const private_key = [_]u8{3} ** 32;
    const education_attestation = try use_cases.createEducationAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        private_key,
        "University of Example",
        "Master of Science",
        "Computer Science",
        "2022-05-15",
        3.8,
    );
    
    print("✅ Education attestation created with ID: {}\n", .{
        std.fmt.fmtSliceHexLower(&education_attestation.id),
    });
    
    // Verify the attestation
    const is_valid = service.verifyAttestation(education_attestation.id);
    print("✅ Education attestation verification: {}\n", .{is_valid});
    
    print("✅ Education test completed\n", .{});
}

/// Test age verification
fn runAgeTest(allocator: std.mem.Allocator) !void {
    print("📋 Age Verification Test\n", .{});
    print("========================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    var use_cases = UseCases.init(allocator, &service);
    
    // Create schema
    var schema = try eas.Schema.init(
        allocator,
        "Age Verification",
        "Verification of age for age-restricted services",
        "{\"type\": \"object\", \"properties\": {\"birth_date\": {\"type\": \"string\", \"format\": \"date\"}, \"minimum_age\": {\"type\": \"integer\"}, \"is_over_age\": {\"type\": \"boolean\"}}}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try eas.Attester.init(
        allocator,
        "Age Verification Authority",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    try service.registerAttester(attester);
    
    // Create age attestation
    const private_key = [_]u8{3} ** 32;
    const age_attestation = try use_cases.createAgeAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        private_key,
        "1995-03-20",
        18,
        true,
    );
    
    print("✅ Age attestation created with ID: {}\n", .{
        std.fmt.fmtSliceHexLower(&age_attestation.id),
    });
    
    // Verify the attestation
    const is_valid = service.verifyAttestation(age_attestation.id);
    print("✅ Age attestation verification: {}\n", .{is_valid});
    
    print("✅ Age test completed\n", .{});
}

/// Test residence verification
fn runResidenceTest(allocator: std.mem.Allocator) !void {
    print("📋 Residence Verification Test\n", .{});
    print("==============================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    var use_cases = UseCases.init(allocator, &service);
    
    // Create schema
    var schema = try eas.Schema.init(
        allocator,
        "Residence Verification",
        "Verification of residence for location-based services",
        "{\"type\": \"object\", \"properties\": {\"address\": {\"type\": \"string\"}, \"city\": {\"type\": \"string\"}, \"state\": {\"type\": \"string\"}, \"country\": {\"type\": \"string\"}, \"residency_duration\": {\"type\": \"integer\"}}}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try eas.Attester.init(
        allocator,
        "Municipal Authority",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    try service.registerAttester(attester);
    
    // Create residence attestation
    const private_key = [_]u8{3} ** 32;
    const residence_attestation = try use_cases.createResidenceAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        private_key,
        "456 Oak Avenue",
        "Anytown",
        "State",
        "Country",
        365, // 1 year
    );
    
    print("✅ Residence attestation created with ID: {}\n", .{
        std.fmt.fmtSliceHexLower(&residence_attestation.id),
    });
    
    // Verify the attestation
    const is_valid = service.verifyAttestation(residence_attestation.id);
    print("✅ Residence attestation verification: {}\n", .{is_valid});
    
    print("✅ Residence test completed\n", .{});
}

/// Test real estate ownership verification
fn runRealEstateTest(allocator: std.mem.Allocator) !void {
    print("📋 Real Estate Ownership Test\n", .{});
    print("=============================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    var use_cases = UseCases.init(allocator, &service);
    
    // Create schema
    var schema = try eas.Schema.init(
        allocator,
        "Real Estate Ownership",
        "Verification of real estate ownership",
        "{\"type\": \"object\", \"properties\": {\"property_address\": {\"type\": \"string\"}, \"property_id\": {\"type\": \"string\"}, \"ownership_percentage\": {\"type\": \"number\"}, \"purchase_date\": {\"type\": \"string\", \"format\": \"date\"}, \"estimated_value\": {\"type\": \"integer\"}}}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try eas.Attester.init(
        allocator,
        "Real Estate Registry",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    try service.registerAttester(attester);
    
    // Create real estate attestation
    const private_key = [_]u8{3} ** 32;
    const real_estate_attestation = try use_cases.createRealEstateAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        private_key,
        "789 Pine Street, Anytown, ST 12345",
        "PROP123456",
        100.0, // 100% ownership
        "2020-06-01",
        500000, // $500,000 estimated value
    );
    
    print("✅ Real estate attestation created with ID: {}\n", .{
        std.fmt.fmtSliceHexLower(&real_estate_attestation.id),
    });
    
    // Verify the attestation
    const is_valid = service.verifyAttestation(real_estate_attestation.id);
    print("✅ Real estate attestation verification: {}\n", .{is_valid});
    
    print("✅ Real estate test completed\n", .{});
}

/// Test intellectual property verification
fn runIpTest(allocator: std.mem.Allocator) !void {
    print("📋 Intellectual Property Test\n", .{});
    print("=============================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    var use_cases = UseCases.init(allocator, &service);
    
    // Create schema
    var schema = try eas.Schema.init(
        allocator,
        "Intellectual Property",
        "Verification of intellectual property rights",
        "{\"type\": \"object\", \"properties\": {\"ip_type\": {\"type\": \"string\"}, \"title\": {\"type\": \"string\"}, \"registration_number\": {\"type\": \"string\"}, \"registration_date\": {\"type\": \"string\", \"format\": \"date\"}, \"jurisdiction\": {\"type\": \"string\"}}}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try eas.Attester.init(
        allocator,
        "Patent and Trademark Office",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    try service.registerAttester(attester);
    
    // Create IP attestation
    const private_key = [_]u8{3} ** 32;
    const ip_attestation = try use_cases.createIpAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        private_key,
        "Patent",
        "Innovative Blockchain Algorithm",
        "PAT987654321",
        "2023-01-15",
        "United States",
    );
    
    print("✅ IP attestation created with ID: {}\n", .{
        std.fmt.fmtSliceHexLower(&ip_attestation.id),
    });
    
    // Verify the attestation
    const is_valid = service.verifyAttestation(ip_attestation.id);
    print("✅ IP attestation verification: {}\n", .{is_valid});
    
    print("✅ IP test completed\n", .{});
}

/// Test digital asset ownership verification
fn runDigitalAssetTest(allocator: std.mem.Allocator) !void {
    print("📋 Digital Asset Ownership Test\n", .{});
    print("===============================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    var use_cases = UseCases.init(allocator, &service);
    
    // Create schema
    var schema = try eas.Schema.init(
        allocator,
        "Digital Asset Ownership",
        "Verification of digital asset ownership",
        "{\"type\": \"object\", \"properties\": {\"asset_type\": {\"type\": \"string\"}, \"asset_id\": {\"type\": \"string\"}, \"quantity\": {\"type\": \"number\"}, \"wallet_address\": {\"type\": \"string\"}}}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try eas.Attester.init(
        allocator,
        "Digital Asset Exchange",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    try service.registerAttester(attester);
    
    // Create digital asset attestation
    const private_key = [_]u8{3} ** 32;
    const digital_asset_attestation = try use_cases.createDigitalAssetAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        private_key,
        "Cryptocurrency",
        "BTC",
        2.5,
        "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa",
    );
    
    print("✅ Digital asset attestation created with ID: {}\n", .{
        std.fmt.fmtSliceHexLower(&digital_asset_attestation.id),
    });
    
    // Verify the attestation
    const is_valid = service.verifyAttestation(digital_asset_attestation.id);
    print("✅ Digital asset attestation verification: {}\n", .{is_valid});
    
    print("✅ Digital asset test completed\n", .{});
}

/// Test game achievement verification
fn runGameAchievementTest(allocator: std.mem.Allocator) !void {
    print("📋 Game Achievement Test\n", .{});
    print("========================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    var use_cases = UseCases.init(allocator, &service);
    
    // Create schema
    var schema = try eas.Schema.init(
        allocator,
        "Game Achievement",
        "Verification of in-game achievements",
        "{\"type\": \"object\", \"properties\": {\"game_name\": {\"type\": \"string\"}, \"achievement_name\": {\"type\": \"string\"}, \"achieved_date\": {\"type\": \"string\", \"format\": \"date\"}, \"points\": {\"type\": \"integer\"}}}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try eas.Attester.init(
        allocator,
        "Game Platform",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    try service.registerAttester(attester);
    
    // Create game achievement attestation
    const private_key = [_]u8{3} ** 32;
    const game_attestation = try use_cases.createGameAchievementAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        private_key,
        "BlockQuest Adventures",
        "Master Explorer",
        "2023-07-15",
        1000,
    );
    
    print("✅ Game achievement attestation created with ID: {}\n", .{
        std.fmt.fmtSliceHexLower(&game_attestation.id),
    });
    
    // Verify the attestation
    const is_valid = service.verifyAttestation(game_attestation.id);
    print("✅ Game achievement attestation verification: {}\n", .{is_valid});
    
    print("✅ Game achievement test completed\n", .{});
}

/// Test community participation verification
fn runCommunityParticipationTest(allocator: std.mem.Allocator) !void {
    print("📋 Community Participation Test\n", .{});
    print("===============================\n", .{});
    
    var service = eas.AttestationService.init(allocator);
    defer service.deinit();
    
    var use_cases = UseCases.init(allocator, &service);
    
    // Create schema
    var schema = try eas.Schema.init(
        allocator,
        "Community Participation",
        "Verification of community participation",
        "{\"type\": \"object\", \"properties\": {\"organization\": {\"type\": \"string\"}, \"role\": {\"type\": \"string\"}, \"participation_start\": {\"type\": \"string\", \"format\": \"date\"}, \"participation_end\": {\"type\": \"string\", \"format\": \"date\"}, \"contribution_hours\": {\"type\": \"integer\"}}}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    try service.registerSchema(schema);
    
    // Create attester
    var attester = try eas.Attester.init(
        allocator,
        "Open Source Community",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    try service.registerAttester(attester);
    
    // Create community participation attestation
    const private_key = [_]u8{3} ** 32;
    const community_attestation = try use_cases.createCommunityParticipationAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        private_key,
        "Zig Programming Language Community",
        "Core Contributor",
        "2022-01-01",
        "2023-12-31",
        500,
    );
    
    print("✅ Community participation attestation created with ID: {}\n", .{
        std.fmt.fmtSliceHexLower(&community_attestation.id),
    });
    
    // Verify the attestation
    const is_valid = service.verifyAttestation(community_attestation.id);
    print("✅ Community participation attestation verification: {}\n", .{is_valid});
    
    print("✅ Community participation test completed\n", .{});
}

/// Run all use case tests
fn runAllUseCaseTests(allocator: std.mem.Allocator) !void {
    print("🎯 Comprehensive EAS Use Cases Test Suite\n", .{});
    print("=========================================\n", .{});
    
    try runKycTest(allocator);
    print("\n", .{});
    
    try runEducationTest(allocator);
    print("\n", .{});
    
    try runAgeTest(allocator);
    print("\n", .{});
    
    try runResidenceTest(allocator);
    print("\n", .{});
    
    try runRealEstateTest(allocator);
    print("\n", .{});
    
    try runIpTest(allocator);
    print("\n", .{});
    
    try runDigitalAssetTest(allocator);
    print("\n", .{});
    
    try runGameAchievementTest(allocator);
    print("\n", .{});
    
    try runCommunityParticipationTest(allocator);
    
    print("\n📊 EAS Use Cases Implementation Status\n", .{});
    print("=====================================\n", .{});
    print("📋 KYC/AML Identity Verification: ✅ Implemented\n", .{});
    print("🎓 Educational Qualification: ✅ Implemented\n", .{});
    print("🎂 Age Verification: ✅ Implemented\n", .{});
    print("🏠 Residence Verification: ✅ Implemented\n", .{});
    print("🏢 Real Estate Ownership: ✅ Implemented\n", .{});
    print("🧠 Intellectual Property: ✅ Implemented\n", .{});
    print("💰 Digital Asset Ownership: ✅ Implemented\n", .{});
    print("🎮 Game Achievements: ✅ Implemented\n", .{});
    print("🤝 Community Participation: ✅ Implemented\n", .{});
    print("📚 Framework: ✅ Ready for extension\n", .{});
}