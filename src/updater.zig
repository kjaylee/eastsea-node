const std = @import("std");
const fs = std.fs;

/// REQ-102: 자동 업데이트/제거 지원
/// UT-102-01: updater.checkVersion — 버전 비교
/// UT-102-02: updater.prepareRollback — 롤백 준비

pub const Version = struct {
    major: u16,
    minor: u16,
    patch: u16,

    pub fn parse(str: []const u8) ?Version {
        var parts = std.mem.splitScalar(u8, str, '.');
        const major = std.fmt.parseUnsigned(u16, parts.next() orelse return null, 10) catch return null;
        const minor = std.fmt.parseUnsigned(u16, parts.next() orelse return null, 10) catch return null;
        const patch = std.fmt.parseUnsigned(u16, parts.next() orelse return null, 10) catch return null;
        return .{ .major = major, .minor = minor, .patch = patch };
    }

    pub fn isNewerThan(self: Version, other: Version) bool {
        if (self.major != other.major) return self.major > other.major;
        if (self.minor != other.minor) return self.minor > other.minor;
        return self.patch > other.patch;
    }

    pub fn eql(self: Version, other: Version) bool {
        return self.major == other.major and self.minor == other.minor and self.patch == other.patch;
    }
};

pub const CURRENT_VERSION = Version{ .major = 0, .minor = 1, .patch = 0 };

/// UT-102-01: 버전 비교
pub fn checkVersion(remote_version_str: []const u8) bool {
    const remote = Version.parse(remote_version_str) orelse return false;
    return remote.isNewerThan(CURRENT_VERSION);
}

/// UT-102-02: 롤백 준비
pub fn prepareRollback(allocator: std.mem.Allocator, data_dir: []const u8) ![]u8 {
    const backup_path = try std.fmt.allocPrint(allocator, "{s}/backup_v{d}.{d}.{d}", .{
        data_dir, CURRENT_VERSION.major, CURRENT_VERSION.minor, CURRENT_VERSION.patch,
    });
    std.debug.print("📦 롤백 백업 경로: {s}\n", .{backup_path});
    return backup_path;
}

// === Tests ===

test "UT-102-01: Version.parse" {
    const v = Version.parse("1.2.3").?;
    try std.testing.expect(v.major == 1 and v.minor == 2 and v.patch == 3);
}

test "UT-102-01: checkVersion 최신" {
    try std.testing.expect(checkVersion("1.0.0") == true);
}

test "UT-102-01: checkVersion 동일" {
    try std.testing.expect(checkVersion("0.1.0") == false);
}

test "UT-102-02: prepareRollback" {
    const allocator = std.testing.allocator;
    const path = try prepareRollback(allocator, "/tmp");
    defer allocator.free(path);
    try std.testing.expect(std.mem.indexOf(u8, path, "backup_v0.1.0") != null);
}
