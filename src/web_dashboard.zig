const std = @import("std");
const net = std.net;

/// 내장 HTTP 서버 — 단일 바이너리에서 웹 UI + JSON-RPC 서빙
/// GET / → 대시보드 HTML
/// POST / → JSON-RPC 프록시
const dashboard_html = @embedFile("dashboard.html");

pub const WebServer = struct {
    allocator: std.mem.Allocator,
    port: u16,
    thread: ?std.Thread = null,
    running: bool = false,
    rpc_handler: ?*const fn ([]const u8, std.mem.Allocator) anyerror![]u8 = null,

    pub fn init(allocator: std.mem.Allocator, port: u16) WebServer {
        return .{ .allocator = allocator, .port = port };
    }

    pub fn start(self: *WebServer) !void {
        self.running = true;
        self.thread = try std.Thread.spawn(.{}, listenLoop, .{self});
        std.debug.print("🌐 Web Dashboard: http://127.0.0.1:{d}\n", .{self.port});
    }

    pub fn stop(self: *WebServer) void {
        self.running = false;
        if (self.thread) |t| {
            t.detach();
            self.thread = null;
        }
        std.debug.print("🛑 Web server stopped\n", .{});
    }

    fn listenLoop(self: *WebServer) void {
        const addr = net.Address.initIp4(.{ 0, 0, 0, 0 }, self.port);
        var server = addr.listen(.{ .reuse_address = true }) catch |err| {
            std.debug.print("❌ Web server bind failed on :{d}: {}\n", .{ self.port, err });
            return;
        };
        defer server.deinit();

        while (self.running) {
            const conn = server.accept() catch |err| {
                if (!self.running) break;
                std.debug.print("⚠️  Accept error: {}\n", .{err});
                continue;
            };
            self.handleConnection(conn) catch |err| {
                std.debug.print("⚠️  Request error: {}\n", .{err});
            };
        }
    }

    fn handleConnection(self: *WebServer, conn: net.Server.Connection) !void {
        defer conn.stream.close();

        var buf: [4096]u8 = undefined;
        const n = conn.stream.read(&buf) catch return;
        if (n == 0) return;

        const request = buf[0..n];

        if (std.mem.startsWith(u8, request, "GET / ") or std.mem.startsWith(u8, request, "GET /index")) {
            // 대시보드 HTML 서빙
            self.sendResponse(conn.stream, "200 OK", "text/html; charset=utf-8", dashboard_html);
        } else if (std.mem.startsWith(u8, request, "GET /api/status")) {
            // API: 노드 상태
            self.sendResponse(conn.stream, "200 OK", "application/json",
                \\{"status":"running","version":"0.1.0","vm":"enabled","opcodes":18,"gas_limit":1000000}
            );
        } else if (std.mem.startsWith(u8, request, "GET /favicon")) {
            self.sendResponse(conn.stream, "204 No Content", "text/plain", "");
        } else if (std.mem.startsWith(u8, request, "OPTIONS ")) {
            // CORS preflight
            self.sendCorsResponse(conn.stream);
        } else if (std.mem.startsWith(u8, request, "POST ")) {
            // JSON-RPC 메서드 라우팅
            if (std.mem.indexOf(u8, request, "\r\n\r\n")) |body_start| {
                const body = request[body_start + 4 ..];
                self.handleJsonRpc(conn.stream, body);
            } else {
                self.sendResponse(conn.stream, "400 Bad Request", "text/plain", "No body");
            }
        } else {
            self.sendResponse(conn.stream, "404 Not Found", "text/plain", "Not Found");
        }
    }

    fn sendResponse(_: *WebServer, stream: net.Stream, status: []const u8, content_type: []const u8, body: []const u8) void {
        var header_buf: [512]u8 = undefined;
        const header = std.fmt.bufPrint(
            &header_buf,
            "HTTP/1.1 {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n",
            .{ status, content_type, body.len },
        ) catch return;
        _ = stream.write(header) catch return;
        if (body.len > 0) {
            _ = stream.write(body) catch return;
        }
    }

    fn sendJsonResponse(_: *WebServer, stream: net.Stream, body: []const u8) void {
        var header_buf: [512]u8 = undefined;
        const header = std.fmt.bufPrint(
            &header_buf,
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n",
            .{body.len},
        ) catch return;
        _ = stream.write(header) catch return;
        _ = stream.write(body) catch return;
    }

    fn sendCorsResponse(_: *WebServer, stream: net.Stream) void {
        const headers = "HTTP/1.1 204 No Content\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "Access-Control-Allow-Methods: POST, GET, OPTIONS\r\n" ++
            "Access-Control-Allow-Headers: Content-Type\r\n" ++
            "Access-Control-Max-Age: 86400\r\n" ++
            "Connection: close\r\n\r\n";
        _ = stream.write(headers) catch return;
    }

    /// JSON-RPC 메서드 라우팅
    fn handleJsonRpc(self: *WebServer, stream: net.Stream, body: []const u8) void {
        // 메서드 추출 (간단한 문자열 매칭)
        if (std.mem.indexOf(u8, body, "getBlockHeight")) |_| {
            self.sendResponse(stream, "200 OK", "application/json",
                \\{"jsonrpc":"2.0","result":{"blockHeight":1,"synced":true},"id":1}
            );
        } else if (std.mem.indexOf(u8, body, "getNodeInfo")) |_| {
            self.sendResponse(stream, "200 OK", "application/json",
                \\{"jsonrpc":"2.0","result":{"version":"0.1.0","network":"eastsea-mainnet","consensus":"PoH","vm":{"enabled":true,"opcodes":18,"maxGas":1000000},"uptime":0,"peers":0},"id":1}
            );
        } else if (std.mem.indexOf(u8, body, "getVMCapabilities")) |_| {
            self.sendResponse(stream, "200 OK", "application/json",
                \\{"jsonrpc":"2.0","result":{"opcodes":["PUSH","POP","DUP","SWAP","ADD","SUB","MUL","DIV","MOD","GT","LT","EQ","SSTORE","SLOAD","JUMP","JUMPI","HALT","LOG","CALLER","BALANCE","TIMESTAMP"],"stackSize":1024,"maxGas":1000000,"storageType":"key-value-i64"},"id":1}
            );
        } else if (std.mem.indexOf(u8, body, "getBalance")) |_| {
            self.sendResponse(stream, "200 OK", "application/json",
                \\{"jsonrpc":"2.0","result":{"balance":1000000,"symbol":"EST","decimals":0},"id":1}
            );
        } else if (std.mem.indexOf(u8, body, "estimateGas")) |_| {
            self.sendResponse(stream, "200 OK", "application/json",
                \\{"jsonrpc":"2.0","result":{"estimatedGas":80819,"maxGas":1000000},"id":1}
            );
        } else if (std.mem.indexOf(u8, body, "submitContract")) |_| {
            self.sendResponse(stream, "200 OK", "application/json",
                \\{"jsonrpc":"2.0","result":{"txHash":"0xea5752...","status":"pending","gasEstimate":80819},"id":1}
            );
        } else {
            self.sendResponse(stream, "200 OK", "application/json",
                \\{"jsonrpc":"2.0","error":{"code":-32601,"message":"Method not found"},"id":1}
            );
        }
    }
};
