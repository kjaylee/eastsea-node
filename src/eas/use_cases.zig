const std = @import("std");
const eas = @import("attestation.zig");
const Attestation = eas.Attestation;
const Schema = eas.Schema;
const Attester = eas.Attester;
const AttestationService = eas.AttestationService;

/// Use cases module for Eastsea Attestation Service
/// Provides implementations for common real-world attestation use cases
pub const UseCases = struct {
    allocator: std.mem.Allocator,
    service: *AttestationService,

    pub fn init(allocator: std.mem.Allocator, service: *AttestationService) UseCases {
        return UseCases{
            .allocator = allocator,
            .service = service,
        };
    }

    /// Create a KYC/AML identity verification attestation
    pub fn createKycAttestation(
        self: *UseCases,
        schema_id: [32]u8,
        attester_id: [20]u8,
        recipient: [20]u8,
        expiration: u64,
        private_key: [32]u8,
        name: []const u8,
        id_number: []const u8,
        dob: []const u8,
        address: []const u8,
        nationality: []const u8,
    ) !*Attestation {
        // Create JSON data for the attestation
        var data_buffer = std.ArrayList(u8).init(self.allocator);
        defer data_buffer.deinit();

        try std.json.stringify(
            struct {
                name: []const u8,
                id_number: []const u8,
                dob: []const u8,
                address: []const u8,
                nationality: []const u8,
            }{
                .name = name,
                .id_number = id_number,
                .dob = dob,
                .address = address,
                .nationality = nationality,
            },
            .{},
            data_buffer.writer(),
        );

        // Create the attestation
        return try self.service.createAttestation(
            schema_id,
            attester_id,
            recipient,
            expiration,
            data_buffer.items,
            private_key,
            false, // is_private
        );
    }

    /// Create an educational qualification attestation
    pub fn createEducationAttestation(
        self: *UseCases,
        schema_id: [32]u8,
        attester_id: [20]u8,
        recipient: [20]u8,
        expiration: u64,
        private_key: [32]u8,
        institution: []const u8,
        degree: []const u8,
        field: []const u8,
        graduation_date: []const u8,
        gpa: f32,
    ) !*Attestation {
        // Create JSON data for the attestation
        var data_buffer = std.ArrayList(u8).init(self.allocator);
        defer data_buffer.deinit();

        try std.json.stringify(
            struct {
                institution: []const u8,
                degree: []const u8,
                field: []const u8,
                graduation_date: []const u8,
                gpa: f32,
            }{
                .institution = institution,
                .degree = degree,
                .field = field,
                .graduation_date = graduation_date,
                .gpa = gpa,
            },
            .{},
            data_buffer.writer(),
        );

        // Create the attestation
        return try self.service.createAttestation(
            schema_id,
            attester_id,
            recipient,
            expiration,
            data_buffer.items,
            private_key,
            false, // is_private
        );
    }

    /// Create an age verification attestation
    pub fn createAgeAttestation(
        self: *UseCases,
        schema_id: [32]u8,
        attester_id: [20]u8,
        recipient: [20]u8,
        expiration: u64,
        private_key: [32]u8,
        birth_date: []const u8,
        minimum_age: u8,
        is_over_age: bool,
    ) !*Attestation {
        // Create JSON data for the attestation
        var data_buffer = std.ArrayList(u8).init(self.allocator);
        defer data_buffer.deinit();

        try std.json.stringify(
            struct {
                birth_date: []const u8,
                minimum_age: u8,
                is_over_age: bool,
            }{
                .birth_date = birth_date,
                .minimum_age = minimum_age,
                .is_over_age = is_over_age,
            },
            .{},
            data_buffer.writer(),
        );

        // Create the attestation
        return try self.service.createAttestation(
            schema_id,
            attester_id,
            recipient,
            expiration,
            data_buffer.items,
            private_key,
            false, // is_private
        );
    }

    /// Create a residence verification attestation
    pub fn createResidenceAttestation(
        self: *UseCases,
        schema_id: [32]u8,
        attester_id: [20]u8,
        recipient: [20]u8,
        expiration: u64,
        private_key: [32]u8,
        address: []const u8,
        city: []const u8,
        state: []const u8,
        country: []const u8,
        residency_duration: u32,
    ) !*Attestation {
        // Create JSON data for the attestation
        var data_buffer = std.ArrayList(u8).init(self.allocator);
        defer data_buffer.deinit();

        try std.json.stringify(
            struct {
                address: []const u8,
                city: []const u8,
                state: []const u8,
                country: []const u8,
                residency_duration: u32,
            }{
                .address = address,
                .city = city,
                .state = state,
                .country = country,
                .residency_duration = residency_duration,
            },
            .{},
            data_buffer.writer(),
        );

        // Create the attestation
        return try self.service.createAttestation(
            schema_id,
            attester_id,
            recipient,
            expiration,
            data_buffer.items,
            private_key,
            false, // is_private
        );
    }

    /// Create a real estate ownership attestation
    pub fn createRealEstateAttestation(
        self: *UseCases,
        schema_id: [32]u8,
        attester_id: [20]u8,
        recipient: [20]u8,
        expiration: u64,
        private_key: [32]u8,
        property_address: []const u8,
        property_id: []const u8,
        ownership_percentage: f32,
        purchase_date: []const u8,
        estimated_value: u64,
    ) !*Attestation {
        // Create JSON data for the attestation
        var data_buffer = std.ArrayList(u8).init(self.allocator);
        defer data_buffer.deinit();

        try std.json.stringify(
            struct {
                property_address: []const u8,
                property_id: []const u8,
                ownership_percentage: f32,
                purchase_date: []const u8,
                estimated_value: u64,
            }{
                .property_address = property_address,
                .property_id = property_id,
                .ownership_percentage = ownership_percentage,
                .purchase_date = purchase_date,
                .estimated_value = estimated_value,
            },
            .{},
            data_buffer.writer(),
        );

        // Create the attestation
        return try self.service.createAttestation(
            schema_id,
            attester_id,
            recipient,
            expiration,
            data_buffer.items,
            private_key,
            false, // is_private
        );
    }

    /// Create an intellectual property attestation
    pub fn createIpAttestation(
        self: *UseCases,
        schema_id: [32]u8,
        attester_id: [20]u8,
        recipient: [20]u8,
        expiration: u64,
        private_key: [32]u8,
        ip_type: []const u8,
        title: []const u8,
        registration_number: []const u8,
        registration_date: []const u8,
        jurisdiction: []const u8,
    ) !*Attestation {
        // Create JSON data for the attestation
        var data_buffer = std.ArrayList(u8).init(self.allocator);
        defer data_buffer.deinit();

        try std.json.stringify(
            struct {
                ip_type: []const u8,
                title: []const u8,
                registration_number: []const u8,
                registration_date: []const u8,
                jurisdiction: []const u8,
            }{
                .ip_type = ip_type,
                .title = title,
                .registration_number = registration_number,
                .registration_date = registration_date,
                .jurisdiction = jurisdiction,
            },
            .{},
            data_buffer.writer(),
        );

        // Create the attestation
        return try self.service.createAttestation(
            schema_id,
            attester_id,
            recipient,
            expiration,
            data_buffer.items,
            private_key,
            false, // is_private
        );
    }

    /// Create a digital asset ownership attestation
    pub fn createDigitalAssetAttestation(
        self: *UseCases,
        schema_id: [32]u8,
        attester_id: [20]u8,
        recipient: [20]u8,
        expiration: u64,
        private_key: [32]u8,
        asset_type: []const u8,
        asset_id: []const u8,
        quantity: f64,
        wallet_address: []const u8,
    ) !*Attestation {
        // Create JSON data for the attestation
        var data_buffer = std.ArrayList(u8).init(self.allocator);
        defer data_buffer.deinit();

        try std.json.stringify(
            struct {
                asset_type: []const u8,
                asset_id: []const u8,
                quantity: f64,
                wallet_address: []const u8,
            }{
                .asset_type = asset_type,
                .asset_id = asset_id,
                .quantity = quantity,
                .wallet_address = wallet_address,
            },
            .{},
            data_buffer.writer(),
        );

        // Create the attestation
        return try self.service.createAttestation(
            schema_id,
            attester_id,
            recipient,
            expiration,
            data_buffer.items,
            private_key,
            false, // is_private
        );
    }

    /// Create a game achievement attestation
    pub fn createGameAchievementAttestation(
        self: *UseCases,
        schema_id: [32]u8,
        attester_id: [20]u8,
        recipient: [20]u8,
        expiration: u64,
        private_key: [32]u8,
        game_name: []const u8,
        achievement_name: []const u8,
        achieved_date: []const u8,
        points: u32,
    ) !*Attestation {
        // Create JSON data for the attestation
        var data_buffer = std.ArrayList(u8).init(self.allocator);
        defer data_buffer.deinit();

        try std.json.stringify(
            struct {
                game_name: []const u8,
                achievement_name: []const u8,
                achieved_date: []const u8,
                points: u32,
            }{
                .game_name = game_name,
                .achievement_name = achievement_name,
                .achieved_date = achieved_date,
                .points = points,
            },
            .{},
            data_buffer.writer(),
        );

        // Create the attestation
        return try self.service.createAttestation(
            schema_id,
            attester_id,
            recipient,
            expiration,
            data_buffer.items,
            private_key,
            false, // is_private
        );
    }

    /// Create a community participation attestation
    pub fn createCommunityParticipationAttestation(
        self: *UseCases,
        schema_id: [32]u8,
        attester_id: [20]u8,
        recipient: [20]u8,
        expiration: u64,
        private_key: [32]u8,
        organization: []const u8,
        role: []const u8,
        participation_start: []const u8,
        participation_end: []const u8,
        contribution_hours: u32,
    ) !*Attestation {
        // Create JSON data for the attestation
        var data_buffer = std.ArrayList(u8).init(self.allocator);
        defer data_buffer.deinit();

        try std.json.stringify(
            struct {
                organization: []const u8,
                role: []const u8,
                participation_start: []const u8,
                participation_end: []const u8,
                contribution_hours: u32,
            }{
                .organization = organization,
                .role = role,
                .participation_start = participation_start,
                .participation_end = participation_end,
                .contribution_hours = contribution_hours,
            },
            .{},
            data_buffer.writer(),
        );

        // Create the attestation
        return try self.service.createAttestation(
            schema_id,
            attester_id,
            recipient,
            expiration,
            data_buffer.items,
            private_key,
            false, // is_private
        );
    }
};

// Test functions
test "use cases module initialization" {
    const allocator = std.testing.allocator;
    var service = AttestationService.init(allocator);
    defer service.deinit();

    const use_cases = UseCases.init(allocator, &service);
    _ = use_cases;
}

test "KYC attestation creation" {
    const allocator = std.testing.allocator;
    var service = AttestationService.init(allocator);
    defer service.deinit();

    // Create schema
    var schema = try Schema.init(
        allocator,
        "KYC Schema",
        "KYC verification schema",
        "{}",
        [_]u8{1} ** 20,
    );
    defer schema.deinit();
    try service.registerSchema(schema);

    // Create attester
    var attester = try Attester.init(
        allocator,
        "KYC Authority",
        [_]u8{2} ** 20,
    );
    defer attester.deinit();
    try service.registerAttester(attester);

    const use_cases = UseCases.init(allocator, &service);
    
    const private_key = [_]u8{3} ** 32;
    const attestation = try use_cases.createKycAttestation(
        schema.id,
        attester.id,
        [_]u8{4} ** 20, // recipient
        0, // Never expires
        private_key,
        "John Doe",
        "ID123456",
        "1990-01-01",
        "123 Main St",
        "US",
    );
    
    try std.testing.expect(attestation != null);
}