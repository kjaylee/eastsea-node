const std = @import("std");
const WebServer = @import("rpc/web_server.zig").WebServer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Get port from command line args or use default
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    const port = if (args.len > 1) 
        std.fmt.parseInt(u16, args[1], 10) catch 8080
    else 
        8080;
    
    std.debug.print("🚀 Starting Eastsea Web Server on port {}\n", .{port});
    
    // Create and start web server
    var server = try WebServer.init(allocator, port);
    defer server.deinit();
    
    // Start server (this will block)
    try server.start();
}