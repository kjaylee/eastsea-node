const std = @import("std");
const net = std.net;
const onboarding = @import("onboarding.zig");

/// 부트 시 진단 결과
pub const DiagnosticResult = struct {
    passed: bool,
    message: []const u8,
    suggestion: []const u8,
};

/// 포트 진단 보고서
pub const PortDiagnostics = struct {
    node_port_ok: bool,
    rpc_port_ok: bool,
    quic_port_ok: bool,
    suggested_node_port: u16,
    suggested_rpc_port: u16,
    suggested_quic_port: u16,
    conflicts: u8,
};

/// UT-111-01: 포트 충돌 진단
/// 시작 시 전체 포트 세트(node/rpc/quic)에 대해 충돌 감지 및 대체 제안
pub fn checkPortConflict(node_port: u16, rpc_port: u16, quic_port: u16) PortDiagnostics {
    const node_ok = onboarding.isPortAvailable(node_port);
    const rpc_ok = onboarding.isPortAvailable(rpc_port);
    const quic_ok = onboarding.isPortAvailable(quic_port);

    var conflicts: u8 = 0;
    if (!node_ok) conflicts += 1;
    if (!rpc_ok) conflicts += 1;
    if (!quic_ok) conflicts += 1;

    const suggested_node = if (node_ok) node_port else onboarding.pickHealthyPort(node_port);
    const suggested_rpc = if (rpc_ok) rpc_port else onboarding.pickHealthyPort(rpc_port);
    const suggested_quic = if (quic_ok) quic_port else onboarding.pickHealthyPort(quic_port);

    return .{
        .node_port_ok = node_ok,
        .rpc_port_ok = rpc_ok,
        .quic_port_ok = quic_ok,
        .suggested_node_port = suggested_node,
        .suggested_rpc_port = suggested_rpc,
        .suggested_quic_port = suggested_quic,
        .conflicts = conflicts,
    };
}

/// UT-111-02: 권한 검사
/// 데이터 경로 쓰기 가능 여부 및 리슨 포트 바인딩 가능 여부 판별
pub const PrivilegeCheck = struct {
    can_write_data: bool,
    can_bind_port: bool,
    needs_elevated: bool,
    message: []const u8,
};

pub fn checkPrivileges(data_dir: []const u8, port: u16) PrivilegeCheck {
    // 데이터 경로 쓰기 검사
    const can_write = blk: {
        // 경로 존재 확인
        std.fs.cwd().access(data_dir, .{}) catch {
            // 존재하지 않으면 생성 시도
            std.fs.cwd().makePath(data_dir) catch {
                break :blk false;
            };
            // 생성 성공 시 삭제 (검사만)
            std.fs.cwd().deleteDir(data_dir) catch {};
            break :blk true;
        };
        break :blk true;
    };

    // 포트 바인딩 검사
    const can_bind = onboarding.isPortAvailable(port);

    // 1024 미만 포트는 root 필요
    const needs_elevated = port < 1024 and !can_bind;

    const message = if (!can_write and needs_elevated)
        "데이터 경로 쓰기 불가 + 관리자 권한 필요"
    else if (!can_write)
        "데이터 경로에 쓰기 권한이 없습니다"
    else if (needs_elevated)
        "포트 바인딩에 관리자 권한이 필요합니다"
    else
        "권한 검사 통과";

    return .{
        .can_write_data = can_write,
        .can_bind_port = can_bind,
        .needs_elevated = needs_elevated,
        .message = message,
    };
}

/// 전체 부트 진단 수행 (포트 + 권한)
pub fn runBootDiagnostics(node_port: u16, rpc_port: u16, quic_port: u16, data_dir: []const u8) void {
    std.debug.print("\n🔍 부트 진단 시작...\n", .{});
    std.debug.print("==========================================\n", .{});

    // 포트 진단
    const port_diag = checkPortConflict(node_port, rpc_port, quic_port);

    if (port_diag.conflicts == 0) {
        std.debug.print("✅ 포트 충돌 없음 (node={d}, rpc={d}, quic={d})\n", .{ node_port, rpc_port, quic_port });
    } else {
        std.debug.print("⚠️  포트 충돌 {d}건 감지:\n", .{port_diag.conflicts});
        if (!port_diag.node_port_ok) {
            std.debug.print("   node: {d} → {d}\n", .{ node_port, port_diag.suggested_node_port });
        }
        if (!port_diag.rpc_port_ok) {
            std.debug.print("   rpc:  {d} → {d}\n", .{ rpc_port, port_diag.suggested_rpc_port });
        }
        if (!port_diag.quic_port_ok) {
            std.debug.print("   quic: {d} → {d}\n", .{ quic_port, port_diag.suggested_quic_port });
        }
    }

    // 권한 진단
    const priv_check = checkPrivileges(data_dir, node_port);
    if (priv_check.can_write_data and priv_check.can_bind_port) {
        std.debug.print("✅ {s}\n", .{priv_check.message});
    } else {
        std.debug.print("⚠️  {s}\n", .{priv_check.message});
        if (priv_check.needs_elevated) {
            std.debug.print("   → sudo 또는 1024 이상 포트 사용 권장\n", .{});
        }
    }

    std.debug.print("==========================================\n\n", .{});
}

// ============================================================
// Unit Tests (UT-111-01, UT-111-02)
// ============================================================

test "UT-111-01: checkPortConflict 기본 포트 진단" {
    const diag = checkPortConflict(49200, 49201, 49202);
    // 높은 포트는 보통 사용 가능
    try std.testing.expect(diag.suggested_node_port >= 49200);
    try std.testing.expect(diag.suggested_rpc_port >= 49201);
    try std.testing.expect(diag.suggested_quic_port >= 49202);
}

test "UT-111-01: checkPortConflict 충돌 수 계산" {
    const diag = checkPortConflict(49300, 49301, 49302);
    // conflicts는 0~3 사이
    try std.testing.expect(diag.conflicts <= 3);
    // ok 플래그와 conflicts 일치 검증
    var expected_conflicts: u8 = 0;
    if (!diag.node_port_ok) expected_conflicts += 1;
    if (!diag.rpc_port_ok) expected_conflicts += 1;
    if (!diag.quic_port_ok) expected_conflicts += 1;
    try std.testing.expect(diag.conflicts == expected_conflicts);
}

test "UT-111-01: checkPortConflict 대체 포트 제안" {
    // 사용 가능한 포트에 대해 제안 포트 = 원래 포트
    const diag = checkPortConflict(49400, 49401, 49402);
    if (diag.node_port_ok) {
        try std.testing.expect(diag.suggested_node_port == 49400);
    } else {
        // 충돌 시 대체 포트는 원래보다 크거나 같아야 함
        try std.testing.expect(diag.suggested_node_port >= 49400);
    }
}

test "UT-111-02: checkPrivileges 쓰기 권한 검사" {
    // /tmp는 보통 쓰기 가능
    const check = checkPrivileges("/tmp/eastsea_priv_test", 49500);
    try std.testing.expect(check.can_write_data == true);
    try std.testing.expect(check.message.len > 0);
}

test "UT-111-02: checkPrivileges 관리자 권한 판정" {
    const check = checkPrivileges("/tmp", 49501);
    // 1024 이상 포트이므로 elevated 불필요
    try std.testing.expect(check.needs_elevated == false);
}

test "UT-111-02: checkPrivileges 메시지 매핑" {
    const check = checkPrivileges("/tmp", 49502);
    // 정상 상태면 "권한 검사 통과" 메시지
    if (check.can_write_data and check.can_bind_port) {
        try std.testing.expect(std.mem.eql(u8, check.message, "권한 검사 통과"));
    }
}
