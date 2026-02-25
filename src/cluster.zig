const std = @import("std");

/// REQ-122: 노드 클러스터 관리
/// UT-122-01: clusterInfo — 클러스터 상태 조회
pub const ClusterNode = struct {
    id: [32]u8,
    address: []const u8,
    role: []const u8,
    is_active: bool,
};

pub const ClusterInfo = struct {
    total_nodes: u32,
    active_nodes: u32,
    validators: u32,
};

pub fn getClusterInfo(nodes_count: u32, active: u32, validators: u32) ClusterInfo {
    return .{ .total_nodes = nodes_count, .active_nodes = active, .validators = validators };
}

// Tests
test "UT-122-01: clusterInfo" {
    const info = getClusterInfo(10, 8, 3);
    try std.testing.expect(info.total_nodes == 10);
    try std.testing.expect(info.active_nodes == 8);
    try std.testing.expect(info.validators == 3);
}
