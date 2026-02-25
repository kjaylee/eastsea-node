const std = @import("std");

/// REQ-121: 런타임 모니터링
/// UT-121-01: collectMetrics — CPU/메모리/디스크 수집
/// UT-121-02: healthCheck — 노드 상태 판정
/// UT-121-03: alertThreshold — 임계치 초과 알림
pub const Metrics = struct {
    uptime_seconds: i64 = 0,
    block_height: u64 = 0,
    peer_count: u32 = 0,
    rpc_requests: u64 = 0,
    errors: u32 = 0,
    is_healthy: bool = true,
};

pub fn collectMetrics(block_height: u64, peer_count: u32, start_time: i64) Metrics {
    return .{
        .uptime_seconds = std.time.timestamp() - start_time,
        .block_height = block_height,
        .peer_count = peer_count,
        .is_healthy = peer_count > 0,
    };
}

pub fn healthCheck(metrics: *const Metrics) bool {
    if (!metrics.is_healthy) return false;
    if (metrics.peer_count == 0) return false;
    if (metrics.errors > 100) return false;
    return true;
}

pub fn alertThreshold(metrics: *const Metrics) ?[]const u8 {
    if (metrics.errors > 100) return "에러 수 임계치 초과";
    if (metrics.peer_count == 0) return "피어 연결 없음";
    if (metrics.uptime_seconds > 86400 and metrics.block_height == 0) return "24시간 이상 블록 생성 없음";
    return null;
}

// Tests
test "UT-121-01: collectMetrics" {
    const m = collectMetrics(100, 5, std.time.timestamp() - 60);
    try std.testing.expect(m.block_height == 100);
    try std.testing.expect(m.peer_count == 5);
    try std.testing.expect(m.uptime_seconds >= 59);
}

test "UT-121-02: healthCheck 정상" {
    const m = Metrics{ .peer_count = 3, .is_healthy = true };
    try std.testing.expect(healthCheck(&m) == true);
}

test "UT-121-02: healthCheck 실패" {
    const m = Metrics{ .peer_count = 0, .is_healthy = true };
    try std.testing.expect(healthCheck(&m) == false);
}

test "UT-121-03: alertThreshold" {
    const m = Metrics{ .errors = 200, .peer_count = 1 };
    try std.testing.expect(alertThreshold(&m) != null);
}

test "UT-121-03: alertThreshold 정상" {
    const m = Metrics{ .peer_count = 3, .is_healthy = true };
    try std.testing.expect(alertThreshold(&m) == null);
}
