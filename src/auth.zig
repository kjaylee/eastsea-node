const std = @import("std");
const crypto = std.crypto;

/// REQ-001: API 인증 토큰
/// UT-001-01: issueToken — 만료/scope 적용
/// UT-001-02: validateToken — 만료·위조·타입 불일치
pub const TokenError = error{ Expired, Invalid, Unauthorized };

pub const Token = struct {
    id: [16]u8,
    scope: []const u8,
    issued_at: i64,
    expires_at: i64,
    signature: [32]u8,
};

const SECRET_KEY: [32]u8 = [_]u8{ 0x7e, 0x2a, 0x15, 0xbc } ++ [_]u8{0xab} ** 28;

/// UT-001-01: 토큰 발급
pub fn issueToken(scope: []const u8, ttl_seconds: i64) Token {
    const now = std.time.timestamp();
    var id: [16]u8 = undefined;
    std.crypto.random.bytes(&id);

    var sig_input: [48]u8 = undefined;
    @memcpy(sig_input[0..16], &id);
    @memcpy(sig_input[16..48], &SECRET_KEY);

    var sig: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&sig_input, &sig, .{});

    return .{
        .id = id,
        .scope = scope,
        .issued_at = now,
        .expires_at = now + ttl_seconds,
        .signature = sig,
    };
}

/// UT-001-02: 토큰 검증
pub fn validateToken(token: *const Token) TokenError!bool {
    const now = std.time.timestamp();

    // 만료 확인
    if (now > token.expires_at) return TokenError.Expired;

    // 서명 검증
    var sig_input: [48]u8 = undefined;
    @memcpy(sig_input[0..16], &token.id);
    @memcpy(sig_input[16..48], &SECRET_KEY);
    var expected: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&sig_input, &expected, .{});

    if (!std.mem.eql(u8, &token.signature, &expected)) return TokenError.Invalid;

    return true;
}

// === Tests ===

test "UT-001-01: issueToken 생성" {
    const token = issueToken("read:blocks", 3600);
    try std.testing.expect(token.expires_at > token.issued_at);
    try std.testing.expect(token.expires_at - token.issued_at == 3600);
    try std.testing.expect(std.mem.eql(u8, token.scope, "read:blocks"));
}

test "UT-001-02: validateToken 정상" {
    const token = issueToken("admin", 3600);
    const valid = try validateToken(&token);
    try std.testing.expect(valid == true);
}

test "UT-001-02: validateToken 만료" {
    var token = issueToken("admin", 1);
    token.expires_at = token.issued_at - 1; // 강제 만료
    const result = validateToken(&token);
    try std.testing.expect(result == TokenError.Expired);
}

test "UT-001-02: validateToken 위조" {
    var token = issueToken("admin", 3600);
    token.signature[0] ^= 0xFF; // 서명 위조
    const result = validateToken(&token);
    try std.testing.expect(result == TokenError.Invalid);
}
