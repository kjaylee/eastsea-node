const std = @import("std");
const net = std.net;
const http = std.http;
const blockchain = @import("../blockchain/blockchain.zig");

/// Simple HTTP server for Eastsea node management UI
pub const WebServer = struct {
    allocator: std.mem.Allocator,
    server: net.Server,
    blockchain_ref: ?*blockchain.Blockchain,
    running: bool,
    // For demo purposes, we'll embed the HTML content
    html_content: []const u8,

    pub fn init(allocator: std.mem.Allocator, port: u16) !WebServer {
        const address = try net.Address.parseIp4("127.0.0.1", port);
        const server = try address.listen(.{ .reuse_address = true });
        
        // Embedded HTML content for the web UI
        const html_content = @embedFile("index.html");
        
        return WebServer{
            .allocator = allocator,
            .server = server,
            .blockchain_ref = null,
            .running = false,
            .html_content = html_content,
        };
    }

    pub fn deinit(self: *WebServer) void {
        if (self.running) {
            self.stop();
        }
        // Properly close the server
        self.server.close();
    }

    pub fn setBlockchain(self: *WebServer, blockchain_ref: *blockchain.Blockchain) void {
        self.blockchain_ref = blockchain_ref;
    }

    pub fn start(self: *WebServer) !void {
        self.running = true;
        std.debug.print("🌐 Web server started on http://127.0.0.1:{}\n", .{self.server.listen_address.in.getPort()});
        
        while (self.running) {
            // Accept connection
            var connection = try self.server.accept();
            defer connection.stream.close();
            
            // Create HTTP server instance
            var header_buffer: [4096]u8 = undefined;
            var server = http.Server.init(connection, &header_buffer);
            
            // Handle HTTP request
            const request = try server.receiveHead();
            
            // Route handling
            if (request.head.method == .GET) {
                if (std.mem.eql(u8, request.head.target, "/") or std.mem.eql(u8, request.head.target, "/index.html")) {
                    try self.serveFile(&server, self.html_content, "text/html; charset=utf-8");
                } else if (std.mem.eql(u8, request.head.target, "/api/status")) {
                    try self.serveStatus(&server);
                } else if (std.mem.eql(u8, request.head.target, "/api/blocks")) {
                    try self.serveBlocks(&server);
                } else if (std.mem.eql(u8, request.head.target, "/api/transactions")) {
                    try self.serveTransactions(&server);
                } else {
                    try self.serve404(&server);
                }
            } else {
                try self.serve404(&server);
            }
            
            // Send response
            try server.send();
        }
    }

    pub fn stop(self: *WebServer) void {
        self.running = false;
        std.debug.print("🛑 Web server stopped\n", .{});
    }

    fn serveFile(self: *WebServer, server: *http.Server, content: []const u8, content_type: []const u8) !void {
        _ = self;
        server.respond(content, .{
            .status = .ok,
            .contentType = content_type,
        }) catch |err| {
            std.debug.print("Error serving file: {}\n", .{err});
            server.respond("Internal Server Error", .{.status = .internal_server_error}) catch {};
        };
    }

    fn serveStatus(self: *WebServer, server: *http.Server) !void {
        _ = self;
        // In a real implementation, we would get actual data from the blockchain
        // For now, we'll return mock JSON data
        const json_data = "{\n  \"peerCount\": 12,\n  \"blockHeight\": 1245,\n  \"tps\": 124.5,\n  \"nodeId\": \"node_7f8e3a9b4c5d6e2f1a0b8c9d7e6f5a4b3c2d1e0f\",\n  \"version\": \"0.1.0\",\n  \"uptime\": \"2h 15m\"\n}";
        
        server.respond(json_data, .{
            .status = .ok,
            .contentType = "application/json",
        }) catch |err| {
            std.debug.print("Error serving status: {}\n", .{err});
            server.respond("Internal Server Error", .{.status = .internal_server_error}) catch {};
        };
    }

    fn serveBlocks(self: *WebServer, server: *http.Server) !void {
        _ = self;
        // In a real implementation, we would get actual data from the blockchain
        // For now, we'll return mock JSON data
        const json_data = "[\n  {\n    \"height\": 1245,\n    \"hash\": \"a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef12\",\n    \"timestamp\": \"2025-07-29 14:30:25\",\n    \"transactions\": 42\n  },\n  {\n    \"height\": 1244,\n    \"hash\": \"f0e9d8c7b6a594837261504321098765432109876543210987654321\",\n    \"timestamp\": \"2025-07-29 14:30:18\",\n    \"transactions\": 38\n  },\n  {\n    \"height\": 1243,\n    \"hash\": \"1029384756aebfcd0987654321fedcba987654321098765432109876\",\n    \"timestamp\": \"2025-07-29 14:30:12\",\n    \"transactions\": 51\n  }\n]";
        
        server.respond(json_data, .{
            .status = .ok,
            .contentType = "application/json",
        }) catch |err| {
            std.debug.print("Error serving blocks: {}\n", .{err});
            server.respond("Internal Server Error", .{.status = .internal_server_error}) catch {};
        };
    }

    fn serveTransactions(self: *WebServer, server: *http.Server) !void {
        _ = self;
        // In a real implementation, we would get actual data from the blockchain
        // For now, we'll return mock JSON data
        const json_data = "[\n  {\n    \"hash\": \"t1a2b3c4d5e6f7890abcdef1234567890abcdef1234567890abcdef\",\n    \"from\": \"acc_1234\",\n    \"to\": \"acc_5678\",\n    \"amount\": \"12.5\",\n    \"timestamp\": \"2025-07-29 14:30:24\"\n  },\n  {\n    \"hash\": \"t2b3c4d5e6f7890a1bcdef234567890abcdef1234567890abcdef12\",\n    \"from\": \"acc_9012\",\n    \"to\": \"acc_3456\",\n    \"amount\": \"8.75\",\n    \"timestamp\": \"2025-07-29 14:30:22\"\n  }\n]";
        
        server.respond(json_data, .{
            .status = .ok,
            .contentType = "application/json",
        }) catch |err| {
            std.debug.print("Error serving transactions: {}\n", .{err});
            server.respond("Internal Server Error", .{.status = .internal_server_error}) catch {};
        };
    }

    fn serve404(self: *WebServer, server: *http.Server) !void {
        _ = self;
        server.respond("Not Found", .{.status = .not_found}) catch {};
    }
}