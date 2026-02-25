const std = @import("std");

/// REQ-002: 역할 기반 권한 (RBAC)
/// UT-002-01: authorize — 역할별 접근 제어

pub const Role = enum { admin, operator, viewer, guest };

pub const Permission = struct {
    resource: []const u8,
    action: []const u8,
};

const role_permissions = struct {
    pub fn canAccess(role: Role, resource: []const u8, action: []const u8) bool {
        return switch (role) {
            .admin => true,
            .operator => !std.mem.eql(u8, action, "delete") and !std.mem.eql(u8, resource, "config"),
            .viewer => std.mem.eql(u8, action, "read"),
            .guest => std.mem.eql(u8, resource, "status") and std.mem.eql(u8, action, "read"),
        };
    }
};

pub fn authorize(role: Role, resource: []const u8, action: []const u8) bool {
    return role_permissions.canAccess(role, resource, action);
}

// Tests
test "UT-002-01: admin 전체 접근" {
    try std.testing.expect(authorize(.admin, "config", "delete") == true);
    try std.testing.expect(authorize(.admin, "blocks", "write") == true);
}

test "UT-002-01: operator 제한" {
    try std.testing.expect(authorize(.operator, "blocks", "write") == true);
    try std.testing.expect(authorize(.operator, "blocks", "delete") == false);
    try std.testing.expect(authorize(.operator, "config", "read") == false);
}

test "UT-002-01: viewer 읽기만" {
    try std.testing.expect(authorize(.viewer, "blocks", "read") == true);
    try std.testing.expect(authorize(.viewer, "blocks", "write") == false);
}

test "UT-002-01: guest status만" {
    try std.testing.expect(authorize(.guest, "status", "read") == true);
    try std.testing.expect(authorize(.guest, "blocks", "read") == false);
}
