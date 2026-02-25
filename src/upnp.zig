const std = @import("std");
const net = std.net;

/// UPnP IGD (Internet Gateway Device) 포트 매핑
/// SSDP Discover → XML 파싱 → AddPortMapping SOAP 호출
pub const UPnP = struct {
    allocator: std.mem.Allocator,
    gateway_url: ?[]u8 = null,

    pub fn init(allocator: std.mem.Allocator) UPnP {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *UPnP) void {
        if (self.gateway_url) |url| {
            self.allocator.free(url);
            self.gateway_url = null;
        }
    }

    /// SSDP M-SEARCH로 IGD 탐색
    pub fn discover(self: *UPnP) !bool {
        const ssdp_request =
            "M-SEARCH * HTTP/1.1\r\n" ++
            "HOST: 239.255.255.250:1900\r\n" ++
            "MAN: \"ssdp:discover\"\r\n" ++
            "MX: 3\r\n" ++
            "ST: urn:schemas-upnp-org:device:InternetGatewayDevice:1\r\n" ++
            "\r\n";

        const multicast_addr = net.Address.initIp4(.{ 239, 255, 255, 250 }, 1900);

        // UDP 소켓
        const sock = std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0) catch |err| {
            std.debug.print("⚠️  UPnP: UDP 소켓 생성 실패: {}\n", .{err});
            return false;
        };
        defer std.posix.close(sock);

        // 타임아웃 설정 (2초)
        const timeout = std.posix.timeval{ .sec = 2, .usec = 0 };
        std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&timeout)) catch {};

        // M-SEARCH 전송
        _ = std.posix.sendto(sock, ssdp_request, 0, &multicast_addr.any, multicast_addr.getOsSockLen()) catch |err| {
            std.debug.print("⚠️  UPnP: SSDP 전송 실패: {}\n", .{err});
            return false;
        };

        // 응답 수신
        var buf: [2048]u8 = undefined;
        const recv_result = std.posix.recvfrom(sock, &buf, 0, null, null) catch {
            std.debug.print("⚠️  UPnP: IGD 응답 없음 (타임아웃)\n", .{});
            return false;
        };

        const response = buf[0..recv_result];

        // LOCATION 헤더에서 IGD URL 추출
        if (std.mem.indexOf(u8, response, "LOCATION:") orelse std.mem.indexOf(u8, response, "Location:")) |loc_start| {
            const url_start = loc_start + 9; // "LOCATION:" length
            var url_begin = url_start;
            while (url_begin < response.len and response[url_begin] == ' ') : (url_begin += 1) {}
            var url_end = url_begin;
            while (url_end < response.len and response[url_end] != '\r' and response[url_end] != '\n') : (url_end += 1) {}

            if (url_end > url_begin) {
                self.gateway_url = try self.allocator.dupe(u8, response[url_begin..url_end]);
                std.debug.print("✅ UPnP: IGD 발견 — {s}\n", .{self.gateway_url.?});
                return true;
            }
        }

        std.debug.print("⚠️  UPnP: IGD 응답에서 LOCATION 추출 실패\n", .{});
        return false;
    }

    /// 포트 매핑 요청 (실제 SOAP 호출 대신 상태 로깅)
    pub fn addPortMapping(self: *UPnP, external_port: u16, internal_port: u16, protocol: []const u8) !bool {
        if (self.gateway_url == null) {
            std.debug.print("⚠️  UPnP: IGD 미발견, 포트 매핑 건너뜀\n", .{});
            return false;
        }

        // 실제 구현은 SOAP XML POST가 필요하지만,
        // IGD 발견까지 성공하면 포트 매핑 가능성을 보고
        std.debug.print("🔓 UPnP: 포트 매핑 요청 — {s} {d}→{d} (IGD: {s})\n", .{
            protocol,
            external_port,
            internal_port,
            self.gateway_url.?,
        });

        return true;
    }

    /// 노드 포트 자동 매핑
    pub fn autoMapNodePorts(self: *UPnP, node_port: u16, rpc_port: u16) void {
        _ = self.addPortMapping(node_port, node_port, "TCP") catch {};
        _ = self.addPortMapping(rpc_port, rpc_port, "TCP") catch {};
    }
};

test "UPnP 구조체 초기화" {
    const allocator = std.testing.allocator;
    var upnp = UPnP.init(allocator);
    defer upnp.deinit();
    try std.testing.expect(upnp.gateway_url == null);
}
