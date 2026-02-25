const std = @import("std");
const fs = std.fs;

/// REQ-120: 업데이트 메커니즘
/// UT-120-01: downloadUpdate — 다운로드 시뮬레이션
/// UT-120-02: verifyChecksum — 무결성 검증
/// UT-120-03: atomicSwap — 원자적 바이너리 교체

pub fn downloadUpdate(allocator: std.mem.Allocator, version: []const u8) ![]u8 {
    const url = try std.fmt.allocPrint(allocator, "https://releases.eastsea.xyz/v{s}/eastsea", .{version});
    std.debug.print("📥 다운로드 시뮬레이션: {s}\n", .{url});
    return url;
}

pub fn verifyChecksum(data: []const u8, expected_hash: [32]u8) bool {
    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &actual, .{});
    return std.mem.eql(u8, &actual, &expected_hash);
}

pub fn atomicSwap(allocator: std.mem.Allocator, src: []const u8, dst: []const u8) !void {
    const backup = try std.fmt.allocPrint(allocator, "{s}.bak", .{dst});
    defer allocator.free(backup);
    // 시뮬레이션: 실제 파일 이동은 하지 않음
    std.debug.print("🔄 원자적 교체: {s} → {s} (백업: {s})\n", .{ src, dst, backup });
}

// Tests
test "UT-120-01: downloadUpdate URL" {
    const allocator = std.testing.allocator;
    const url = try downloadUpdate(allocator, "1.0.0");
    defer allocator.free(url);
    try std.testing.expect(std.mem.indexOf(u8, url, "1.0.0") != null);
}

test "UT-120-02: verifyChecksum 정상" {
    const data = "test data";
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
    try std.testing.expect(verifyChecksum(data, hash) == true);
}

test "UT-120-02: verifyChecksum 실패" {
    const data = "test data";
    const bad_hash: [32]u8 = [_]u8{0} ** 32;
    try std.testing.expect(verifyChecksum(data, bad_hash) == false);
}

test "UT-120-03: atomicSwap 실행" {
    const allocator = std.testing.allocator;
    try atomicSwap(allocator, "/tmp/new", "/tmp/old");
}
