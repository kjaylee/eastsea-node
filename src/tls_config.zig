const std = @import("std");

/// REQ-040: TLS/비밀 관리
/// UT-040-01: validateConfig — 비밀 누출 없이 설정 직렬화
/// UT-040-02: rotate — 비밀 키 회전, 로그 마스킹

pub const TlsConfig = struct {
    enabled: bool = false,
    cert_path: []const u8 = "",
    key_path: []const u8 = "",
    ca_path: []const u8 = "",
    min_version: []const u8 = "1.2",
};

pub const SecretStore = struct {
    api_key: [32]u8,
    tls_key_hash: [32]u8,
    rotation_count: u32 = 0,
    last_rotation: i64 = 0,
};

/// UT-040-01: 설정 직렬화 시 비밀 마스킹
pub fn validateConfig(allocator: std.mem.Allocator, config: TlsConfig) ![]u8 {
    // 비밀 키 경로를 마스킹하여 출력
    const masked_key = if (config.key_path.len > 0) "***MASKED***" else "(none)";

    return std.fmt.allocPrint(allocator,
        \\{{
        \\  "tls_enabled": {s},
        \\  "cert_path": "{s}",
        \\  "key_path": "{s}",
        \\  "min_version": "{s}"
        \\}}
    , .{
        if (config.enabled) "true" else "false",
        if (config.cert_path.len > 0) config.cert_path else "(none)",
        masked_key,
        config.min_version,
    });
}

/// UT-040-02: 비밀 키 회전
pub fn rotate(store: *SecretStore) void {
    std.crypto.random.bytes(&store.api_key);
    store.rotation_count += 1;
    store.last_rotation = std.time.timestamp();

    // 로그 출력 시 마스킹
    std.debug.print("🔄 비밀 키 회전 #{d} (마스킹됨: ****{x}{x})\n", .{
        store.rotation_count,
        store.api_key[30],
        store.api_key[31],
    });
}

/// 마스킹된 로그 문자열 생성
pub fn maskSecret(secret: []const u8) [8]u8 {
    var masked: [8]u8 = "****    ".*;
    if (secret.len >= 4) {
        const hex_chars = "0123456789abcdef";
        masked[4] = hex_chars[secret[secret.len - 2] >> 4];
        masked[5] = hex_chars[secret[secret.len - 2] & 0xf];
        masked[6] = hex_chars[secret[secret.len - 1] >> 4];
        masked[7] = hex_chars[secret[secret.len - 1] & 0xf];
    }
    return masked;
}

// === Tests ===

test "UT-040-01: validateConfig 마스킹" {
    const allocator = std.testing.allocator;
    const config = TlsConfig{
        .enabled = true,
        .cert_path = "/etc/ssl/cert.pem",
        .key_path = "/etc/ssl/key.pem",
    };

    const json = try validateConfig(allocator, config);
    defer allocator.free(json);

    // key_path가 마스킹되어야 함
    try std.testing.expect(std.mem.indexOf(u8, json, "***MASKED***") != null);
    // 실제 키 경로가 포함되면 안 됨
    try std.testing.expect(std.mem.indexOf(u8, json, "key.pem") == null);
}

test "UT-040-01: validateConfig 비활성" {
    const allocator = std.testing.allocator;
    const config = TlsConfig{};

    const json = try validateConfig(allocator, config);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "false") != null);
}

test "UT-040-02: rotate 키 변경" {
    var store = SecretStore{
        .api_key = [_]u8{0} ** 32,
        .tls_key_hash = [_]u8{0} ** 32,
    };

    const old_key = store.api_key;
    rotate(&store);

    // 키가 변경되어야 함 (매우 높은 확률)
    try std.testing.expect(!std.mem.eql(u8, &store.api_key, &old_key));
    try std.testing.expect(store.rotation_count == 1);
    try std.testing.expect(store.last_rotation > 0);
}

test "UT-040-02: rotate 연속 회전" {
    var store = SecretStore{
        .api_key = [_]u8{0} ** 32,
        .tls_key_hash = [_]u8{0} ** 32,
    };

    rotate(&store);
    rotate(&store);
    rotate(&store);

    try std.testing.expect(store.rotation_count == 3);
}

test "maskSecret 마스킹" {
    const secret = [_]u8{ 0x01, 0x02, 0xab, 0xcd };
    const masked = maskSecret(&secret);
    // 앞 4자는 ****
    try std.testing.expect(std.mem.eql(u8, masked[0..4], "****"));
}
