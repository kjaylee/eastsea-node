const std = @import("std");
const fs = std.fs;

/// REQ-010: 영속성 보존 (서비스 재시작 간 상태 보존)
/// UT-010-01: saveState — 상태 영속화
/// UT-010-02: loadState — 상태 복원
/// UT-010-03: cleanState — 상태 정리/제거

pub const NodeState = struct {
    block_height: u64 = 0,
    peer_count: u32 = 0,
    last_checkpoint: i64 = 0,
    wallet_count: u32 = 0,
};

pub fn saveState(allocator: std.mem.Allocator, path: []const u8, state: NodeState) !void {
    const json = try std.fmt.allocPrint(allocator,
        \\{{"block_height":{d},"peer_count":{d},"last_checkpoint":{d},"wallet_count":{d}}}
    , .{ state.block_height, state.peer_count, state.last_checkpoint, state.wallet_count });
    defer allocator.free(json);

    const file = try fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(json);
}

pub fn loadState(allocator: std.mem.Allocator, path: []const u8) !NodeState {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();
    const data = try file.readToEndAlloc(allocator, 4096);
    defer allocator.free(data);

    var state = NodeState{};
    if (findNum(data, "block_height")) |v| state.block_height = @intCast(v);
    if (findNum(data, "peer_count")) |v| state.peer_count = @intCast(v);
    if (findNum(data, "last_checkpoint")) |v| state.last_checkpoint = v;
    if (findNum(data, "wallet_count")) |v| state.wallet_count = @intCast(v);
    return state;
}

pub fn cleanState(path: []const u8) !void {
    try fs.cwd().deleteFile(path);
}

fn findNum(data: []const u8, key: []const u8) ?i64 {
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

// Tests
test "UT-010-01: saveState" {
    const allocator = std.testing.allocator;
    const path = "/tmp/eastsea_state_test.json";
    try saveState(allocator, path, .{ .block_height = 42, .peer_count = 5, .last_checkpoint = 12345, .wallet_count = 2 });
    defer fs.cwd().deleteFile(path) catch {};

    const state = try loadState(allocator, path);
    try std.testing.expect(state.block_height == 42);
    try std.testing.expect(state.peer_count == 5);
}

test "UT-010-02: loadState 복원" {
    const allocator = std.testing.allocator;
    const path = "/tmp/eastsea_state_test2.json";
    try saveState(allocator, path, .{ .block_height = 100, .wallet_count = 3 });
    defer fs.cwd().deleteFile(path) catch {};

    const state = try loadState(allocator, path);
    try std.testing.expect(state.block_height == 100);
    try std.testing.expect(state.wallet_count == 3);
}

test "UT-010-03: cleanState" {
    const allocator = std.testing.allocator;
    const path = "/tmp/eastsea_state_clean.json";
    try saveState(allocator, path, .{});
    try cleanState(path);
    // 삭제 확인
    const result = fs.cwd().openFile(path, .{});
    try std.testing.expect(result == error.FileNotFound);
}
