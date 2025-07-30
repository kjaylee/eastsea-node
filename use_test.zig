const std = @import("std");
const port_scanner = @import("src/network/port_scanner.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const scanner = try port_scanner.PortScanner.init(allocator, [4]u8{ 192, 168, 1, 0 }, 1, 10, &[_]u16{ 8000, 8001 });
    defer scanner.deinit();
    
    std.debug.print("Port scanner initialized successfully\n", .{});
}