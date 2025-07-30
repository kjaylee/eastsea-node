const std = @import("std");
const port_scanner = @import("src/network/port_scanner.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const scanner = try port_scanner.PortScanner.init(allocator, [4]u8{ 127, 0, 0, 1 }, 1, 2, &[_]u16{ 8000 });
    defer scanner.deinit();
    
    // This will likely fail since there's nothing running on port 8000
    // but it should compile and run without format string errors
    scanner.scan() catch |err| {
        std.debug.print("Scan failed as expected: {}\n", .{err});
    };
    
    std.debug.print("Test completed\n", .{});
}