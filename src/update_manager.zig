const std = @import("std");
const updater = @import("updater.zig");

const fs = std.fs;
const path = std.fs.path;

// REQ-120: 업데이트 메커니즘
// UT-120-01: downloadUpdate — 다운로드 URL 생성
// UT-120-02: verifyChecksum — SHA-256 무결성 검증
// UT-120-03: atomicSwap — 원자적 바이너리 교체
// UT-120-04: checkForUpdate / applyUpdate / rollback 흐름

pub const DEFAULT_MANIFEST_URL =
    "https://raw.githubusercontent.com/eastsea/eastsea-node/main/manifest.json";

pub const UpdateError = error{
    InvalidManifest,
    DownloadFailed,
    ChecksumMismatch,
};

pub const UpdateManifest = struct {
    version_text: []const u8,
    version: updater.Version,
    asset_url: []const u8,
    checksum: []const u8,
    release_notes: ?[]const u8,

    pub fn deinit(self: *const UpdateManifest, allocator: std.mem.Allocator) void {
        allocator.free(self.version_text);
        allocator.free(self.asset_url);
        allocator.free(self.checksum);
        if (self.release_notes) |notes| {
            allocator.free(notes);
        }
    }
};

const ManifestPayload = struct {
    version: []const u8 = "",
    asset_url: []const u8 = "",
    checksum: []const u8 = "",
    release_notes: ?[]const u8 = null,
};

pub fn downloadUpdate(allocator: std.mem.Allocator, version: []const u8) ![]u8 {
    return std.fmt.allocPrint(
        allocator,
        "https://github.com/eastsea/eastsea-node/releases/download/v{s}/eastsea-production",
        .{version},
    );
}

pub fn verifyChecksum(data: []const u8, expected_hash: [32]u8) bool {
    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &actual, .{});
    return std.mem.eql(u8, &actual, &expected_hash);
}

pub fn verifyChecksumHex(data: []const u8, expected_hash_hex: []const u8) bool {
    var expected: [32]u8 = undefined;
    parseHexToBytes(expected_hash_hex, &expected) catch return false;

    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &actual, .{});
    return std.mem.eql(u8, &actual, &expected);
}

pub fn checkForUpdate(allocator: std.mem.Allocator, manifest_url: []const u8) !?UpdateManifest {
    const manifest_payload = try readManifestText(allocator, manifest_url);
    defer allocator.free(manifest_payload);

    const parsed = try parseManifest(allocator, manifest_payload);

    if (parsed.version.isNewerThan(updater.CURRENT_VERSION)) {
        return parsed;
    }

    parsed.deinit(allocator);
    return null;
}

pub fn applyUpdate(allocator: std.mem.Allocator, manifest: UpdateManifest, current_exe_path: []const u8) !void {
    const target_executable = try toAbsolutePath(allocator, current_exe_path);
    defer allocator.free(target_executable);

    const staged_path = try std.fmt.allocPrint(allocator, "{s}.staged", .{target_executable});
    defer allocator.free(staged_path);

    try downloadArtifact(allocator, manifest.asset_url, staged_path);

    const downloaded = try fs.cwd().readFileAlloc(allocator, staged_path, std.math.maxInt(usize));
    defer allocator.free(downloaded);

    if (!verifyChecksumHex(downloaded, manifest.checksum)) {
        fs.deleteFileAbsolute(try toAbsolutePath(allocator, staged_path)) catch {};
        return UpdateError.ChecksumMismatch;
    }

    try atomicSwap(allocator, staged_path, target_executable);
}

pub fn rollback(allocator: std.mem.Allocator, current_exe_path: []const u8) !bool {
    const target_executable = try toAbsolutePath(allocator, current_exe_path);
    defer allocator.free(target_executable);

    const backup_path = try std.fmt.allocPrint(allocator, "{s}.bak", .{target_executable});
    defer allocator.free(backup_path);

    fs.accessAbsolute(backup_path, .{ .mode = .read_only }) catch |err| {
        switch (err) {
            error.FileNotFound => return false,
            else => return err,
        }
    };

    const rollback_prev_path = try std.fmt.allocPrint(allocator, "{s}.rollback-prev", .{target_executable});
    defer allocator.free(rollback_prev_path);
    fs.deleteFileAbsolute(rollback_prev_path) catch |err| {
        if (err != error.FileNotFound) return err;
    };

    // 현재 실행 파일을 임시 경로로 이동해 백업 파일을 대체
    try fs.renameAbsolute(target_executable, rollback_prev_path);
    errdefer fs.renameAbsolute(rollback_prev_path, target_executable) catch {};

    try fs.renameAbsolute(backup_path, target_executable);
    fs.deleteFileAbsolute(rollback_prev_path) catch |err| {
        if (err != error.FileNotFound) return err;
    };
    return true;
}

pub fn restartSelf(allocator: std.mem.Allocator, executable_path: []const u8, skip_update: bool) !void {
    if (skip_update) {
        const args = [_][]const u8{ executable_path, "--skip-update" };
        var child = std.process.Child.init(&args, allocator);
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;
        child.stdin_behavior = .Ignore;
        try child.spawn();
        return;
    }

    const args = [_][]const u8{executable_path};
    var child = std.process.Child.init(&args, allocator);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    child.stdin_behavior = .Ignore;
    try child.spawn();
}

pub fn atomicSwap(allocator: std.mem.Allocator, src: []const u8, dst: []const u8) !void {
    const src_abs = try toAbsolutePath(allocator, src);
    defer allocator.free(src_abs);
    const dst_abs = try toAbsolutePath(allocator, dst);
    defer allocator.free(dst_abs);

    const backup_path = try std.fmt.allocPrint(allocator, "{s}.bak", .{dst_abs});
    defer allocator.free(backup_path);

    // 기존 대상이 없으면 바로 교체
    const dst_exists = blk: {
        fs.accessAbsolute(dst_abs, .{ .mode = .read_only }) catch |err| {
            if (err == error.FileNotFound) {
                break :blk false;
            }
            return err;
        };
        break :blk true;
    };
    if (dst_exists) {
        fs.deleteFileAbsolute(backup_path) catch |err| {
            if (err != error.FileNotFound) return err;
        };
        try fs.renameAbsolute(dst_abs, backup_path);
    }

    try fs.renameAbsolute(src_abs, dst_abs);
}

fn parseManifest(allocator: std.mem.Allocator, text: []const u8) !UpdateManifest {
    var parsed = try std.json.parseFromSlice(ManifestPayload, allocator, text, .{});
    defer parsed.deinit();

    if (parsed.value.version.len == 0 or
        parsed.value.asset_url.len == 0 or
        parsed.value.checksum.len == 0)
    {
        return UpdateError.InvalidManifest;
    }

    const parsed_version = updater.Version.parse(parsed.value.version) orelse return UpdateError.InvalidManifest;

    return UpdateManifest{
        .version_text = try allocator.dupe(u8, parsed.value.version),
        .version = parsed_version,
        .asset_url = try allocator.dupe(u8, parsed.value.asset_url),
        .checksum = try allocator.dupe(u8, parsed.value.checksum),
        .release_notes = if (parsed.value.release_notes) |notes|
            try allocator.dupe(u8, notes)
        else
            null,
    };
}

fn readManifestText(allocator: std.mem.Allocator, manifest_url: []const u8) ![]u8 {
    if (std.mem.startsWith(u8, manifest_url, "file://")) {
        return fs.cwd().readFileAlloc(allocator, manifest_url["file://".len..], std.math.maxInt(usize));
    }

    if (isHttpScheme(manifest_url)) {
        if (readFromCurlWgetStdOut(allocator, manifest_url)) |text| {
            return text;
        }
        return UpdateError.DownloadFailed;
    }

    // 로컬 파일 경로 또는 테스트용 경로
    return fs.cwd().readFileAlloc(allocator, manifest_url, std.math.maxInt(usize));
}

fn downloadArtifact(allocator: std.mem.Allocator, source_url: []const u8, destination_path: []const u8) !void {
    if (std.mem.startsWith(u8, source_url, "file://")) {
        const source_path = source_url["file://".len..];
        const source_abs = try toAbsolutePath(allocator, source_path);
        defer allocator.free(source_abs);

        const destination_abs = try toAbsolutePath(allocator, destination_path);
        defer allocator.free(destination_abs);

        const dir_name = path.dirname(destination_abs);
        if (dir_name) |dir_path| {
            try fs.cwd().makePath(dir_path);
        }

        return fs.copyFileAbsolute(source_abs, destination_abs, .{});
    }

    if (isHttpScheme(source_url)) {
        return downloadWithCurlWgetToFile(allocator, source_url, destination_path);
    }

    const source_abs = try toAbsolutePath(allocator, source_url);
    defer allocator.free(source_abs);

    const destination_abs = try toAbsolutePath(allocator, destination_path);
    defer allocator.free(destination_abs);

    const dir_name = path.dirname(destination_abs);
    if (dir_name) |dir_path| {
        try fs.cwd().makePath(dir_path);
    }

    return fs.copyFileAbsolute(source_abs, destination_abs, .{});
}

fn downloadWithCurlWgetToFile(allocator: std.mem.Allocator, source_url: []const u8, destination_path: []const u8) !void {
    const destination = try toAbsolutePath(allocator, destination_path);
    defer allocator.free(destination);

    const dir_name = path.dirname(destination);
    if (dir_name) |dir_path| {
        try fs.cwd().makePath(dir_path);
    }

    const curl_cmd = [_][]const u8{ "curl", "-fsSL", "-L", "-o", destination, source_url };
    const wget_cmd = [_][]const u8{ "wget", "-q", "-O", destination, source_url };

    if (runCommandSuccess(allocator, &curl_cmd)) return;
    if (runCommandSuccess(allocator, &wget_cmd)) return;

    return UpdateError.DownloadFailed;
}

fn readFromCurlWgetStdOut(allocator: std.mem.Allocator, url: []const u8) ?[]u8 {
    const curl_cmd = [_][]const u8{ "curl", "-fsSL", "-L", url };
    const wget_cmd = [_][]const u8{ "wget", "-qO-", url };

    if (runCommandStdout(allocator, &curl_cmd)) |text| {
        return text;
    }
    if (runCommandStdout(allocator, &wget_cmd)) |text| {
        return text;
    }

    return null;
}

fn runCommandSuccess(allocator: std.mem.Allocator, argv: []const []const u8) bool {
    const result = std.process.Child.run(.{ .allocator = allocator, .argv = argv }) catch return false;

    const ok = result.term == .Exited and result.term.Exited == 0;
    allocator.free(result.stdout);
    allocator.free(result.stderr);
    return ok;
}

fn runCommandStdout(allocator: std.mem.Allocator, argv: []const []const u8) ?[]u8 {
    const result = std.process.Child.run(.{ .allocator = allocator, .argv = argv }) catch return null;
    if (result.term != .Exited or result.term.Exited != 0) {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
        return null;
    }
    allocator.free(result.stderr);
    return result.stdout;
}

fn isHttpScheme(url: []const u8) bool {
    return std.mem.startsWith(u8, url, "https://") or std.mem.startsWith(u8, url, "http://");
}

fn toAbsolutePath(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (path.isAbsolute(input)) {
        return try allocator.dupe(u8, input);
    }

    const cwd = try fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd);
    return path.join(allocator, &.{ cwd, input });
}

fn parseHexToBytes(raw_hex: []const u8, out: *[32]u8) !void {
    var trimmed = std.mem.trim(u8, raw_hex, " \t\r\n");
    if (std.mem.startsWith(u8, trimmed, "sha256:")) {
        trimmed = trimmed["sha256:".len..];
    }

    if (trimmed.len != 64) return UpdateError.InvalidManifest;

    inline for (0..32) |i| {
        const hi = nibbleToByte(trimmed[i * 2]) catch return UpdateError.InvalidManifest;
        const lo = nibbleToByte(trimmed[i * 2 + 1]) catch return UpdateError.InvalidManifest;
        out[i] = (hi << 4) | lo;
    }
}

fn nibbleToByte(char: u8) !u8 {
    return switch (char) {
        '0'...'9' => char - '0',
        'a'...'f' => 10 + (char - 'a'),
        'A'...'F' => 10 + (char - 'A'),
        else => error.InvalidManifest,
    };
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
    const hex = std.fmt.bytesToHex(hash, .lower);
    try std.testing.expect(verifyChecksumHex(data, &hex) == true);
}

test "UT-120-02: verifyChecksum 실패" {
    const data = "test data";
    const bad_hash: [32]u8 = [_]u8{0} ** 32;
    try std.testing.expect(verifyChecksum(data, bad_hash) == false);
    try std.testing.expect(verifyChecksumHex(data, "bad") == false);
}

test "UT-120-03: atomicSwap 실행" {
    const allocator = std.testing.allocator;
    const source = "/tmp/eastsea-update-src.bin";
    const destination = "/tmp/eastsea-update-dst.bin";
    const backup = "/tmp/eastsea-update-dst.bin.bak";

    {
        var source_file = try fs.cwd().createFile(source, .{ .truncate = true });
        defer source_file.close();
        try source_file.writeAll("new");
    }
    {
        var destination_file = try fs.cwd().createFile(destination, .{ .truncate = true });
        defer destination_file.close();
        try destination_file.writeAll("old");
    }
    defer fs.cwd().deleteFile(source) catch {};
    defer fs.cwd().deleteFile(destination) catch {};
    defer fs.cwd().deleteFile(backup) catch {};

    try atomicSwap(allocator, source, destination);

    const installed = try fs.cwd().readFileAlloc(allocator, destination, 16);
    defer allocator.free(installed);
    try std.testing.expect(std.mem.eql(u8, installed, "new"));
}

test "UT-120-05: rollback 실행 (백업 파일 복구)" {
    const allocator = std.testing.allocator;
    const current = "/tmp/eastsea-update-current.bin";
    const backup = "/tmp/eastsea-update-current.bin.bak";
    const no_backup = "/tmp/eastsea-update-no-backup.bin";

    {
        var current_file = try fs.cwd().createFile(current, .{ .truncate = true });
        defer current_file.close();
        try current_file.writeAll("current");
    }
    {
        var backup_file = try fs.cwd().createFile(backup, .{ .truncate = true });
        defer backup_file.close();
        try backup_file.writeAll("rollback");
    }
    defer fs.cwd().deleteFile(current) catch {};
    defer fs.cwd().deleteFile(backup) catch {};

    const restored = try rollback(allocator, current);
    try std.testing.expect(restored == true);

    const current_content = try fs.cwd().readFileAlloc(allocator, current, 16);
    defer allocator.free(current_content);
    try std.testing.expect(std.mem.eql(u8, current_content, "rollback"));

    const not_found = try rollback(allocator, no_backup);
    try std.testing.expect(not_found == false);
}

test "UT-120-04: checkForUpdate 신규 버전 탐지" {
    const allocator = std.testing.allocator;
    const manifest_path = "/tmp/eastsea-update-check-manifest.json";
    const asset_path = "/tmp/eastsea-update-check-asset.bin";

    {
        var asset = try fs.cwd().createFile(asset_path, .{ .truncate = true });
        defer asset.close();
        try asset.writeAll("eastsea-update-check-asset");
    }
    defer fs.cwd().deleteFile(manifest_path) catch {};
    defer fs.cwd().deleteFile(asset_path) catch {};

    const data = "eastsea-update-check-asset";
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
    const hash_hex = std.fmt.bytesToHex(hash, .lower);

    const manifest = try std.fmt.allocPrint(
        allocator,
        "{{\"version\":\"9.9.9\",\"asset_url\":\"file://{s}\",\"checksum\":\"{s}\"}}",
        .{ asset_path, hash_hex },
    );
    defer allocator.free(manifest);

    {
        var manifest_file = try fs.cwd().createFile(manifest_path, .{ .truncate = true });
        defer manifest_file.close();
        try manifest_file.writeAll(manifest);
    }

    const remote = try checkForUpdate(allocator, manifest_path);
    defer if (remote) |*found| found.deinit(allocator);

    try std.testing.expect(remote != null);
    try std.testing.expect(std.mem.eql(u8, remote.?.version_text, "9.9.9"));
}
