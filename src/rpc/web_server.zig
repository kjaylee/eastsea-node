const std = @import("std");
const net = std.net;
const http = std.http;
const blockchain = @import("../blockchain/blockchain.zig");
const network = @import("../network/node.zig");

/// Simple HTTP server for Eastsea node management UI
pub const WebServer = struct {
    allocator: std.mem.Allocator,
    server: net.Server,
    blockchain_ref: ?*blockchain.Blockchain,
    node_ref: ?*network.Node,
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
            .node_ref = null,
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
    
    pub fn setNode(self: *WebServer, node_ref: *network.Node) void {
        self.node_ref = node_ref;
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
        // Get actual data from the blockchain and node if available
        var peer_count: usize = 0;
        var block_height: u64 = 0;
        var nodeId: []const u8 = "N/A";
        
        if (self.node_ref) |node| {
            peer_count = node.getPeerCount();
            nodeId = node.address;
        }
        
        if (self.blockchain_ref) |chain| {
            block_height = chain.getHeight();
        }
        
        // In a real implementation, we would get actual data from the blockchain
        // For now, we'll return mock JSON data
        const json_data = try std.fmt.allocPrint(self.allocator, 
            "{{\n  \"peerCount\": {},\n  \"blockHeight\": {},\n  \"tps\": 124.5,\n  \"nodeId\": \"{s}\",\n  \"version\": \"0.1.0\",\n  \"uptime\": \"2h 15m\"\n}}",
            .{ peer_count, block_height, nodeId }
        );
        defer self.allocator.free(json_data);
        
        server.respond(json_data, .{
            .status = .ok,
            .contentType = "application/json",
        }) catch |err| {
            std.debug.print("Error serving status: {}\n", .{err});
            server.respond("Internal Server Error", .{.status = .internal_server_error}) catch {};
        };
    }

    fn serveBlocks(self: *WebServer, server: *http.Server) !void {
        // Get actual data from the blockchain if available
        var blocks_json = std.ArrayList(u8).init(self.allocator);
        defer blocks_json.deinit();
        
        try blocks_json.append('[');
        
        if (self.blockchain_ref) |chain| {
            const blocks = chain.chain.items;
            const count = if (blocks.len > 3) 3 else blocks.len;
            
            for (blocks[0..count], 0..) |block, i| {
                if (i > 0) {
                    try blocks_json.append(',');
                }
                
                const block_json = try std.fmt.allocPrint(self.allocator, 
                    "{{\n    \"height\": {},\n    \"hash\": \"{s}\",\n    \"timestamp\": \"2025-07-29 14:30:25\",\n    \"transactions\": {}\n  }}",
                    .{ block.index, if (block.hash.len > 0) block.hash[0..12] else "000000000000", block.transactions.items.len }
                );
                defer self.allocator.free(block_json);
                
                try blocks_json.appendSlice(block_json);
            }
        }
        
        try blocks_json.append(']');
        
        server.respond(blocks_json.items, .{
            .status = .ok,
            .contentType = "application/json",
        }) catch |err| {
            std.debug.print("Error serving blocks: {}\n", .{err});
            server.respond("Internal Server Error", .{.status = .internal_server_error}) catch {};
        };
    }

    fn serveTransactions(self: *WebServer, server: *http.Server) !void {
        // Get actual data from the blockchain if available
        var transactions_json = std.ArrayList(u8).init(self.allocator);
        defer transactions_json.deinit();
        
        try transactions_json.append('[');
        
        if (self.blockchain_ref) |chain| {
            // For simplicity, we'll just show the pending transactions
            for (chain.pending_transactions.items, 0..) |tx, i| {
                if (i > 0) {
                    try transactions_json.append(',');
                }
                
                const tx_json = try std.fmt.allocPrint(self.allocator, 
                    "{{\n    \"hash\": \"t1a2b3c4d5e6f7890abcdef1234567890abcdef1234567890abcdef\",\n    \"from\": \"{s}\",\n    \"to\": \"{s}\",\n    \"amount\": \"{}\",\n    \"timestamp\": \"2025-07-29 14:30:24\"\n  }}",
                    .{ tx.from, tx.to, tx.amount }
                );
                defer self.allocator.free(tx_json);
                
                try transactions_json.appendSlice(tx_json);
            }
        }
        
        try transactions_json.append(']');
        
        server.respond(transactions_json.items, .{
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
};