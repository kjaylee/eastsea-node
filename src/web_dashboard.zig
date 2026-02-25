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
                \\{"status":"running","version":"0.1.0","port":8001}
            );
        } else if (std.mem.startsWith(u8, request, "GET /favicon")) {
            self.sendResponse(conn.stream, "204 No Content", "text/plain", "");
        } else if (std.mem.startsWith(u8, request, "POST ")) {
            // JSON-RPC
            if (self.rpc_handler) |handler| {
                // body 추출
                if (std.mem.indexOf(u8, request, "\r\n\r\n")) |body_start| {
                    const body = request[body_start + 4 ..];
                    const result = handler(body, self.allocator) catch {
                        self.sendResponse(conn.stream, "500 Internal Server Error", "application/json",
                            \\{"error":"internal error"}
                        );
                        return;
                    };
                    defer self.allocator.free(result);
                    self.sendJsonResponse(conn.stream, result);
                } else {
                    self.sendResponse(conn.stream, "400 Bad Request", "text/plain", "No body");
                }
            } else {
                self.sendResponse(conn.stream, "200 OK", "application/json",
                    \\{"jsonrpc":"2.0","result":"ok","id":1}
                );
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
};
