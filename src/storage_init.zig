const std = @import("std");
const fs = std.fs;

/// REQ-110: 첫 실행 시 내장 기본값 기반 영속성 저장소 초기화
/// 스키마 자동 생성, 마이그레이션 관리

pub const StorageError = error{
    InitFailed,
    MigrationFailed,
    CorruptedData,
    DiskFull,
};

/// 스키마 버전 관리
pub const CURRENT_SCHEMA_VERSION: u32 = 1;

/// 저장소 메타데이터
pub const StorageMeta = struct {
    schema_version: u32 = CURRENT_SCHEMA_VERSION,
    created_at: i64 = 0,
    last_migration: i64 = 0,
    node_id: [32]u8 = [_]u8{0} ** 32,
};

/// UT-110-01: 신규 설치 시 스키마 자동 생성
/// 저장소가 없으면 기본 디렉토리 구조 + 메타데이터 생성
pub fn autoInitStorage(allocator: std.mem.Allocator, data_dir: []const u8) !StorageMeta {
    const meta_path = try std.fmt.allocPrint(allocator, "{s}/meta.json", .{data_dir});
    defer allocator.free(meta_path);

    // 기존 메타데이터 확인
    if (fs.cwd().openFile(meta_path, .{})) |file| {
        defer file.close();
        const content = try file.readToEndAlloc(allocator, 4096);
        defer allocator.free(content);

        std.debug.print("✅ 기존 저장소 로드: {s}\n", .{data_dir});
        return parseMeta(content);
    } else |_| {
        // 신규 초기화
        std.debug.print("📦 신규 저장소 초기화: {s}\n", .{data_dir});

        // 디렉토리 구조 생성
        const dirs = [_][]const u8{
            "blocks",
            "state",
            "peers",
            "logs",
            "wallet",
        };

        for (dirs) |sub| {
            const sub_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ data_dir, sub });
            defer allocator.free(sub_path);
            fs.cwd().makePath(sub_path) catch |err| {
                std.debug.print("⚠️  디렉토리 생성 실패: {s} ({})\n", .{ sub_path, err });
            };
        }

        // 메타데이터 생성
        var meta = StorageMeta{
            .created_at = std.time.timestamp(),
            .last_migration = std.time.timestamp(),
        };
        std.crypto.random.bytes(&meta.node_id);

        // 메타데이터 저장
        try saveMeta(allocator, meta_path, meta);
        std.debug.print("✅ 저장소 초기화 완료 (v{d})\n", .{meta.schema_version});

        return meta;
    }
}

/// UT-110-02: 마이그레이션 (중단/복구 흐름)
/// 스키마 버전이 낮으면 순차 마이그레이션 실행
pub fn migrateOnce(allocator: std.mem.Allocator, data_dir: []const u8) !bool {
    const meta_path = try std.fmt.allocPrint(allocator, "{s}/meta.json", .{data_dir});
    defer allocator.free(meta_path);

    // 잠금 파일로 중복 마이그레이션 방지
    const lock_path = try std.fmt.allocPrint(allocator, "{s}/.migration_lock", .{data_dir});
    defer allocator.free(lock_path);

    // 잠금 확인
    if (fs.cwd().access(lock_path, .{})) |_| {
        std.debug.print("⚠️  마이그레이션 잠금 파일 존재 — 이전 마이그레이션 중단 복구\n", .{});
        // 잠금 해제 (복구)
        fs.cwd().deleteFile(lock_path) catch {};
    } else |_| {}

    // 메타데이터 로드
    const file = fs.cwd().openFile(meta_path, .{}) catch {
        std.debug.print("⚠️  메타데이터 없음 — autoInitStorage 먼저 실행 필요\n", .{});
        return false;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 4096);
    defer allocator.free(content);

    var meta = parseMeta(content);

    if (meta.schema_version >= CURRENT_SCHEMA_VERSION) {
        std.debug.print("✅ 스키마 최신 (v{d})\n", .{meta.schema_version});
        return false; // 마이그레이션 불필요
    }

    // 잠금 파일 생성
    const lock_file = try fs.cwd().createFile(lock_path, .{});
    lock_file.close();

    // 마이그레이션 실행
    std.debug.print("🔄 마이그레이션: v{d} → v{d}\n", .{ meta.schema_version, CURRENT_SCHEMA_VERSION });

    meta.schema_version = CURRENT_SCHEMA_VERSION;
    meta.last_migration = std.time.timestamp();

    try saveMeta(allocator, meta_path, meta);

    // 잠금 해제
    fs.cwd().deleteFile(lock_path) catch {};

    std.debug.print("✅ 마이그레이션 완료\n", .{});
    return true;
}

// === 내부 함수 ===

fn saveMeta(allocator: std.mem.Allocator, path: []const u8, meta: StorageMeta) !void {
    const json = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "schema_version": {d},
        \\  "created_at": {d},
        \\  "last_migration": {d}
        \\}}
    , .{ meta.schema_version, meta.created_at, meta.last_migration });
    defer allocator.free(json);

    const file = try fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(json);
}

fn parseMeta(data: []const u8) StorageMeta {
    var meta = StorageMeta{};

    if (findNumber(data, "schema_version")) |v| meta.schema_version = @intCast(v);
    if (findNumber(data, "created_at")) |v| meta.created_at = v;
    if (findNumber(data, "last_migration")) |v| meta.last_migration = v;

    return meta;
}

fn findNumber(data: []const u8, key: []const u8) ?i64 {
    if (std.mem.indexOf(u8, data, key)) |kp| {
        var pos = kp + key.len;
        while (pos < data.len and data[pos] != ':') : (pos += 1) {}
        if (pos >= data.len) return null;
        pos += 1;
        while (pos < data.len and data[pos] == ' ') : (pos += 1) {}
        var end = pos;
        while (end < data.len and (data[end] >= '0' and data[end] <= '9')) : (end += 1) {}
        if (end > pos) return std.fmt.parseInt(i64, data[pos..end], 10) catch null;
    }
    return null;
}

// ============================================================
// Tests
// ============================================================

test "UT-110-01: autoInitStorage 신규 생성" {
    const allocator = std.testing.allocator;
    const test_dir = "/tmp/eastsea_storage_test";
    fs.cwd().deleteTree(test_dir) catch {};
    fs.cwd().makePath(test_dir) catch {};

    const meta = try autoInitStorage(allocator, test_dir);
    try std.testing.expect(meta.schema_version == CURRENT_SCHEMA_VERSION);
    try std.testing.expect(meta.created_at > 0);

    // 디렉토리 구조 확인
    fs.cwd().access("/tmp/eastsea_storage_test/blocks", .{}) catch {
        try std.testing.expect(false);
    };

    fs.cwd().deleteTree(test_dir) catch {};
}

test "UT-110-01: autoInitStorage 기존 로드" {
    const allocator = std.testing.allocator;
    const test_dir = "/tmp/eastsea_storage_test2";
    fs.cwd().deleteTree(test_dir) catch {};
    fs.cwd().makePath(test_dir) catch {};

    // 첫 생성
    const meta1 = try autoInitStorage(allocator, test_dir);
    // 재로드
    const meta2 = try autoInitStorage(allocator, test_dir);
    try std.testing.expect(meta2.schema_version == meta1.schema_version);

    fs.cwd().deleteTree(test_dir) catch {};
}

test "UT-110-02: migrateOnce 최신 스키마" {
    const allocator = std.testing.allocator;
    const test_dir = "/tmp/eastsea_migrate_test";
    fs.cwd().deleteTree(test_dir) catch {};
    fs.cwd().makePath(test_dir) catch {};

    _ = try autoInitStorage(allocator, test_dir);
    const migrated = try migrateOnce(allocator, test_dir);
    try std.testing.expect(migrated == false); // 이미 최신

    fs.cwd().deleteTree(test_dir) catch {};
}

test "UT-110-02: migrateOnce 메타 없음" {
    const allocator = std.testing.allocator;
    const test_dir = "/tmp/eastsea_migrate_test2";
    fs.cwd().deleteTree(test_dir) catch {};
    fs.cwd().makePath(test_dir) catch {};

    const result = try migrateOnce(allocator, test_dir);
    try std.testing.expect(result == false);

    fs.cwd().deleteTree(test_dir) catch {};
}
