const std = @import("std");
const blockchain = @import("../blockchain/blockchain.zig");
const network = @import("../network/node.zig");

pub const RpcMethod = enum {
    getBlockHeight,
    getBalance,
    sendTransaction,
    getBlock,
    getTransaction,
    getPeers,
    getNodeInfo,
    
    pub fn fromString(method: []const u8) ?RpcMethod {
        if (std.mem.eql(u8, method, "getBlockHeight")) return .getBlockHeight;
        if (std.mem.eql(u8, method, "getBalance")) return .getBalance;
        if (std.mem.eql(u8, method, "sendTransaction")) return .sendTransaction;
        if (std.mem.eql(u8, method, "getBlock")) return .getBlock;
        if (std.mem.eql(u8, method, "getTransaction")) return .getTransaction;
        if (std.mem.eql(u8, method, "getPeers")) return .getPeers;
        if (std.mem.eql(u8, method, "getNodeInfo")) return .getNodeInfo;
        return null;
    }
};

pub const RpcRequest = struct {
    jsonrpc: []const u8,
    method: []const u8,
    params: ?std.json.Value,
    id: ?std.json.Value,
};

pub const RpcResponse = struct {
    jsonrpc: []const u8 = "2.0",
    result: ?std.json.Value = null,
    @"error": ?RpcError = null,
    id: ?std.json.Value = null,
    
    // Helper method to clean up allocated memory in result
    pub fn deinit(self: *RpcResponse, allocator: std.mem.Allocator) void {
        if (self.result) |*result| {
            self.deinitJsonValue(result, allocator);
        }
    }
    
    fn deinitJsonValue(self: *RpcResponse, value: *std.json.Value, allocator: std.mem.Allocator) void {
        switch (value.*) {
            .string => |str| allocator.free(str),
            .array => |*arr| {
                for (arr.items) |*item| {
                    self.deinitJsonValue(item, allocator);
                }
                arr.deinit();
            },
            .object => |*obj| {
                var iterator = obj.iterator();
                while (iterator.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    self.deinitJsonValue(entry.value_ptr, allocator);
                }
                obj.deinit();
            },
            else => {},
        }
    }
};

pub const RpcError = struct {
    code: i32,
    message: []const u8,
    data: ?std.json.Value = null,
};

pub const RpcServer = struct {
    allocator: std.mem.Allocator,
    blockchain_ref: *blockchain.Blockchain,
    node_ref: *network.Node,
    port: u16,
    is_running: bool,
    
    pub fn init(
        allocator: std.mem.Allocator, 
        blockchain_ref: *blockchain.Blockchain, 
        node_ref: *network.Node,
        port: u16
    ) RpcServer {
        return RpcServer{
            .allocator = allocator,
            .blockchain_ref = blockchain_ref,
            .node_ref = node_ref,
            .port = port,
            .is_running = false,
        };
    }
    
    pub fn start(self: *RpcServer) !void {
        self.is_running = true;
        std.debug.print("🚀 RPC Server started on port {}\n", .{self.port});
        std.debug.print("📡 Available methods:\n", .{});
        std.debug.print("  - getBlockHeight\n", .{});
        std.debug.print("  - getBalance\n", .{});
        std.debug.print("  - sendTransaction\n", .{});
        std.debug.print("  - getBlock\n", .{});
        std.debug.print("  - getTransaction\n", .{});
        std.debug.print("  - getPeers\n", .{});
        std.debug.print("  - getNodeInfo\n", .{});
    }
    
    pub fn stop(self: *RpcServer) void {
        self.is_running = false;
        std.debug.print("🛑 RPC Server stopped\n", .{});
    }
    
    pub fn handleRequest(self: *RpcServer, request_json: []const u8) ![]u8 {
        var parsed = std.json.parseFromSlice(RpcRequest, self.allocator, request_json, .{}) catch {
            const error_response = RpcResponse{
                .@"error" = RpcError{
                    .code = -32700,
                    .message = "Parse error",
                },
            };
            return try std.json.stringifyAlloc(self.allocator, error_response, .{});
        };
        defer parsed.deinit();
        
        const request = parsed.value;
        
        // Validate JSON-RPC version
        if (!std.mem.eql(u8, request.jsonrpc, "2.0")) {
            const error_response = RpcResponse{
                .@"error" = RpcError{
                    .code = -32600,
                    .message = "Invalid Request",
                },
                .id = request.id,
            };
            return try std.json.stringifyAlloc(self.allocator, error_response, .{});
        }
        
        const method = RpcMethod.fromString(request.method) orelse {
            const error_response = RpcResponse{
                .@"error" = RpcError{
                    .code = -32601,
                    .message = "Method not found",
                },
                .id = request.id,
            };
            return try std.json.stringifyAlloc(self.allocator, error_response, .{});
        };
        
        const result = try self.executeMethod(method, request.params);
        
        var response = RpcResponse{
            .result = result,
            .id = request.id,
        };
        
        const response_json = try std.json.stringifyAlloc(self.allocator, response, .{});
        
        // Clean up the response result to prevent memory leaks
        response.deinit(self.allocator);
        
        return response_json;
    }
    
    fn executeMethod(self: *RpcServer, method: RpcMethod, params: ?std.json.Value) !std.json.Value {
        switch (method) {
            .getBlockHeight => {
                const height = self.blockchain_ref.getHeight();
                return std.json.Value{ .integer = @intCast(height) };
            },
            
            .getBalance => {
                // For demo purposes, return a mock balance
                // In real implementation, this would query account state
                return std.json.Value{ .integer = 1000 };
            },
            
            .sendTransaction => {
                if (params == null) {
                    return error.InvalidParams;
                }
                
                // For demo, just add a mock transaction
                const tx = blockchain.Transaction{
                    .from = "rpc_user",
                    .to = "destination",
                    .amount = 50,
                    .timestamp = std.time.timestamp(),
                };
                
                try self.blockchain_ref.addTransaction(tx);
                
                // Use a static string to avoid memory allocation
                const tx_hash = "mock_tx_hash_12345678901234567890123456789012345678901234567890";
                
                return std.json.Value{ .string = try self.allocator.dupe(u8, tx_hash) };
            },
            
            .getBlock => {
                if (params == null) {
                    return error.InvalidParams;
                }
                
                // Return simple mock block data without complex object allocation
                return std.json.Value{ .string = try self.allocator.dupe(u8, "mock_block_data") };
            },
            
            .getTransaction => {
                if (params == null) {
                    return error.InvalidParams;
                }
                
                // Return simple mock transaction data
                return std.json.Value{ .string = try self.allocator.dupe(u8, "mock_transaction_data") };
            },
            
            .getPeers => {
                // Return simple array count instead of complex object
                const peer_count = self.node_ref.getPeerCount();
                return std.json.Value{ .integer = @intCast(peer_count) };
            },
            
            .getNodeInfo => {
                // Return simple node info as string instead of complex object
                const node_info_str = try std.fmt.allocPrint(
                    self.allocator,
                    "{{\"address\":\"{s}\",\"port\":{},\"peer_count\":{},\"is_running\":{},\"blockchain_height\":{}}}",
                    .{ self.node_ref.address, self.node_ref.port, self.node_ref.getPeerCount(), self.node_ref.is_running, self.blockchain_ref.getHeight() }
                );
                return std.json.Value{ .string = node_info_str };
            },
        }
    }
    
    pub fn processRequest(self: *RpcServer, method: []const u8, params: []const u8) ![]u8 {
        const request_template = 
            \\{{"jsonrpc": "2.0", "method": "{s}", "params": {s}, "id": 1}}
        ;
        
        const request_json = try std.fmt.allocPrint(self.allocator, request_template, .{ method, params });
        defer self.allocator.free(request_json);
        
        return try self.handleRequest(request_json);
    }
    
    pub fn isRunning(self: *const RpcServer) bool {
        return self.is_running;
    }
};

// Helper function to create a simple RPC client for testing
pub const RpcClient = struct {
    allocator: std.mem.Allocator,
    server_address: []const u8,
    server_port: u16,
    
    pub fn init(allocator: std.mem.Allocator, address: []const u8, port: u16) RpcClient {
        return RpcClient{
            .allocator = allocator,
            .server_address = address,
            .server_port = port,
        };
    }
    
    pub fn call(self: *RpcClient, method: []const u8, params: ?[]const u8) ![]u8 {
        const params_str = params orelse "null";
        
        const request = try std.fmt.allocPrint(
            self.allocator,
            \\{{"jsonrpc": "2.0", "method": "{s}", "params": {s}, "id": 1}}
            ,
            .{ method, params_str }
        );
        defer self.allocator.free(request);
        
        // In a real implementation, this would make an HTTP request
        std.debug.print("📞 RPC Call: {s}\n", .{request});
        
        // Mock response for demo
        const response = try std.fmt.allocPrint(
            self.allocator,
            \\{{"jsonrpc": "2.0", "result": "mock_result", "id": 1}}
            ,
            .{}
        );
        
        return response;
    }
};

test "rpc method parsing" {
    const method = RpcMethod.fromString("getBlockHeight");
    try std.testing.expect(method == .getBlockHeight);
    
    const invalid = RpcMethod.fromString("invalidMethod");
    try std.testing.expect(invalid == null);
}

test "rpc server creation" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var chain = try blockchain.Blockchain.init(allocator);
    defer chain.deinit();
    
    var node = network.Node.init(allocator, "127.0.0.1", 8000);
    defer node.deinit();
    
    var server = RpcServer.init(allocator, &chain, &node, 8545);
    
    try testing.expect(!server.isRunning());
    try server.start();
    try testing.expect(server.isRunning());
    
    server.stop();
    try testing.expect(!server.isRunning());
}