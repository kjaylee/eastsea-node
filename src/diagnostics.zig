const std = @import("std");
const builtin = @import("builtin");

/// REQ-112: 실행 진단 리포트 (HW/OS 요약)
/// UT-112-01: generateReport

pub fn generateReport(allocator: std.mem.Allocator) ![]u8 {
    const os_name = @tagName(builtin.os.tag);
    const arch_name = @tagName(builtin.cpu.arch);
    const endian_name = @tagName(builtin.cpu.arch.endian());

    return std.fmt.allocPrint(allocator,
        \\=== Eastsea Node 진단 리포트 ===
        \\OS: {s}
        \\Arch: {s}
        \\Endian: {s}
        \\Page Size: {d}
        \\Timestamp: {d}
        \\================================
    , .{
        os_name,
        arch_name,
        endian_name,
        @as(usize, 16384), // page size (typical ARM64)
        std.time.timestamp(),
    });
}

// Tests
test "UT-112-01: generateReport" {
    const allocator = std.testing.allocator;
    const report = try generateReport(allocator);
    defer allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "진단 리포트") != null);
    try std.testing.expect(report.len > 50);
}
