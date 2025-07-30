const std = @import("std");
const bootstrap = @import("src/network/bootstrap.zig");

test "Bootstrap node config" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var config = try bootstrap.BootstrapNodeConfig.init(allocator, "127.0.0.1", 8000);
    defer config.deinit(allocator);
    
    try testing.expect(std.mem.eql(u8, config.address, "127.0.0.1"));
    try testing.expect(config.port == 8000);
}

test "Bootstrap message serialization" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var original_msg = try bootstrap.BootstrapMessage.init(allocator, .bootstrap_request, "127.0.0.1", 8000, "test payload");
    defer original_msg.deinit(allocator);
    
    const serialized = try original_msg.serialize(allocator);
    defer allocator.free(serialized);
    
    var deserialized_msg = try bootstrap.BootstrapMessage.deserialize(allocator, serialized);
    defer deserialized_msg.deinit(allocator);
    
    try testing.expect(deserialized_msg.type == .bootstrap_request);
    try testing.expect(std.mem.eql(u8, deserialized_msg.sender_address, "127.0.0.1"));
    try testing.expect(deserialized_msg.sender_port == 8000);
    try testing.expect(std.mem.eql(u8, deserialized_msg.payload, "test payload"));
}