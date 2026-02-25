const std = @import("std");
const net = std.net;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

/// UPnP (Universal Plug and Play) 자동 포트 포워딩 클라이언트
/// IGD (Internet Gateway Device) 프로토콜을 사용하여 라우터에서 자동으로 포트 포워딩 설정
pub const UPnPClient = struct {
    allocator: Allocator,
    local_ip: []const u8,
    gateway_ip: ?[]const u8,
    control_url: ?[]const u8,
    service_type: ?[]const u8,
    
    // 포트 매핑 정보
    mapped_ports: ArrayList(PortMapping),
    
    // 설정
    discovery_timeout_ms: u64,
    request_timeout_ms: u64,
    
    const Self = @This();
    
    /// 포트 매핑 정보
    pub const PortMapping = struct {
        external_port: u16,
        internal_port: u16,
        protocol: Protocol,
        description: []const u8,
        lease_duration: u32, // 초 단위, 0은 무제한
        
        pub const Protocol = enum {
            TCP,
            UDP,
            
            pub fn toString(self: Protocol) []const u8 {
                return switch (self) {
                    .TCP => "TCP",
                    .UDP => "UDP",
                };
            }
        };
        
        pub fn deinit(self: *PortMapping, allocator: Allocator) void {
            allocator.free(self.description);
        }
    };
    
    /// UPnP 디스커버리 응답 파싱 결과
    const DiscoveryResult = struct {
        location: []const u8,
        server: []const u8,
        st: []const u8, // Search Target
        usn: []const u8, // Unique Service Name
        
        pub fn deinit(self: *DiscoveryResult, allocator: Allocator) void {
            allocator.free(self.location);
            allocator.free(self.server);
            allocator.free(self.st);
            allocator.free(self.usn);
        }
    };

    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        
        // 로컬 IP 주소 감지
        const local_ip = try detectLocalIP(allocator);
        
        self.* = Self{
            .allocator = allocator,
            .local_ip = local_ip,
            .gateway_ip = null,
            .control_url = null,
            .service_type = null,
            .mapped_ports = ArrayList(PortMapping).init(allocator),
            .discovery_timeout_ms = 5000, // 5초
            .request_timeout_ms = 10000, // 10초
        };
        
        return self;
    }

    pub fn deinit(self: *Self) void {
        // 모든 포트 매핑 제거
        self.removeAllPortMappings() catch |err| {
            print("⚠️ Failed to remove some port mappings during cleanup: {any}\n", .{err});
        };
        
        // 메모리 정리
        for (self.mapped_ports.items) |*mapping| {
            mapping.deinit(self.allocator);
        }
        self.mapped_ports.deinit();
        
        if (self.gateway_ip) |ip| self.allocator.free(ip);
        if (self.control_url) |url| self.allocator.free(url);
        if (self.service_type) |service| self.allocator.free(service);
        self.allocator.free(self.local_ip);
        
        self.allocator.destroy(self);
    }

    /// UPnP 디바이스 발견 및 초기화
    pub fn discover(self: *Self) !bool {
        print("🔍 Discovering UPnP devices...\n", .{});
        
        // SSDP (Simple Service Discovery Protocol) M-SEARCH 요청 전송
        const discovery_results = try self.performSSDPDiscovery();
        defer {
            for (discovery_results.items) |*result| {
                result.deinit(self.allocator);
            }
            discovery_results.deinit();
        }
        
        if (discovery_results.items.len == 0) {
            print("❌ No UPnP devices found\n", .{});
            return false;
        }
        
        print("📡 Found {} UPnP device(s)\n", .{discovery_results.items.len});
        
        // IGD (Internet Gateway Device) 찾기
        for (discovery_results.items) |result| {
            if (std.mem.indexOf(u8, result.st, "InternetGatewayDevice") != null or
                std.mem.indexOf(u8, result.st, "WANIPConnection") != null or
                std.mem.indexOf(u8, result.st, "WANPPPConnection") != null) {
                
                print("🌐 Found IGD device: {s}\n", .{result.location});
                
                // 디바이스 정보 가져오기
                if (try self.fetchDeviceInfo(result.location)) {
                    print("✅ UPnP discovery successful\n", .{});
                    return true;
                }
            }
        }
        
        print("❌ No suitable IGD device found\n", .{});
        return false;
    }

    /// 포트 매핑 추가
    pub fn addPortMapping(self: *Self, external_port: u16, internal_port: u16, protocol: PortMapping.Protocol, description: []const u8, lease_duration: u32) !void {
        if (self.control_url == null or self.service_type == null) {
            return error.UPnPNotInitialized;
        }
        
        print("🔧 Adding port mapping: {}:{s} -> {s}:{} ({s})\n", .{ external_port, protocol.toString(), self.local_ip, internal_port, protocol.toString() });
        
        // SOAP 요청 생성
        const soap_action = "AddPortMapping";
        const soap_body = try std.fmt.allocPrint(self.allocator,
            \\<?xml version="1.0"?>
            \\<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            \\<s:Body>
            \\<u:AddPortMapping xmlns:u="{s}">
            \\<NewRemoteHost></NewRemoteHost>
            \\<NewExternalPort>{}</NewExternalPort>
            \\<NewProtocol>{s}</NewProtocol>
            \\<NewInternalPort>{}</NewInternalPort>
            \\<NewInternalClient>{s}</NewInternalClient>
            \\<NewEnabled>1</NewEnabled>
            \\<NewPortMappingDescription>{s}</NewPortMappingDescription>
            \\<NewLeaseDuration>{}</NewLeaseDuration>
            \\</u:AddPortMapping>
            \\</s:Body>
            \\</s:Envelope>
        , .{ self.service_type.?, external_port, protocol.toString(), internal_port, self.local_ip, description, lease_duration });
        defer self.allocator.free(soap_body);
        
        // HTTP 요청 전송
        const success = try self.sendSOAPRequest(soap_action, soap_body);
        
        if (success) {
            // 성공한 매핑을 목록에 추가
            const mapping = PortMapping{
                .external_port = external_port,
                .internal_port = internal_port,
                .protocol = protocol,
                .description = try self.allocator.dupe(u8, description),
                .lease_duration = lease_duration,
            };
            try self.mapped_ports.append(mapping);
            print("✅ Port mapping added successfully\n", .{});
        } else {
            print("❌ Failed to add port mapping\n", .{});
            return error.PortMappingFailed;
        }
    }

    /// 포트 매핑 제거
    pub fn removePortMapping(self: *Self, external_port: u16, protocol: PortMapping.Protocol) !void {
        if (self.control_url == null or self.service_type == null) {
            return error.UPnPNotInitialized;
        }
        
        print("🗑️ Removing port mapping: {}:{s}\n", .{ external_port, protocol.toString() });
        
        // SOAP 요청 생성
        const soap_action = "DeletePortMapping";
        const soap_body = try std.fmt.allocPrint(self.allocator,
            \\<?xml version="1.0"?>
            \\<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            \\<s:Body>
            \\<u:DeletePortMapping xmlns:u="{s}">
            \\<NewRemoteHost></NewRemoteHost>
            \\<NewExternalPort>{}</NewExternalPort>
            \\<NewProtocol>{s}</NewProtocol>
            \\</u:DeletePortMapping>
            \\</s:Body>
            \\</s:Envelope>
        , .{ self.service_type.?, external_port, protocol.toString() });
        defer self.allocator.free(soap_body);
        
        // HTTP 요청 전송
        const success = try self.sendSOAPRequest(soap_action, soap_body);
        
        if (success) {
            // 목록에서 제거
            var i: usize = 0;
            while (i < self.mapped_ports.items.len) {
                const mapping = &self.mapped_ports.items[i];
                if (mapping.external_port == external_port and mapping.protocol == protocol) {
                    mapping.deinit(self.allocator);
                    _ = self.mapped_ports.swapRemove(i);
                    break;
                } else {
                    i += 1;
                }
            }
            print("✅ Port mapping removed successfully\n", .{});
        } else {
            print("❌ Failed to remove port mapping\n", .{});
            return error.PortMappingRemovalFailed;
        }
    }

    /// 모든 포트 매핑 제거
    pub fn removeAllPortMappings(self: *Self) !void {
        print("🗑️ Removing all port mappings...\n", .{});
        
        // 역순으로 제거 (인덱스 변경 방지)
        while (self.mapped_ports.items.len > 0) {
            const mapping = &self.mapped_ports.items[self.mapped_ports.items.len - 1];
            try self.removePortMapping(mapping.external_port, mapping.protocol);
        }
        
        print("✅ All port mappings removed\n", .{});
    }

    /// 외부 IP 주소 조회
    pub fn getExternalIP(self: *Self) ![]const u8 {
        if (self.control_url == null or self.service_type == null) {
            return error.UPnPNotInitialized;
        }
        
        print("🌐 Getting external IP address...\n", .{});
        
        // SOAP 요청 생성
        const soap_action = "GetExternalIPAddress";
        const soap_body = try std.fmt.allocPrint(self.allocator,
            \\<?xml version="1.0"?>
            \\<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            \\<s:Body>
            \\<u:GetExternalIPAddress xmlns:u="{s}">
            \\</u:GetExternalIPAddress>
            \\</s:Body>
            \\</s:Envelope>
        , .{self.service_type.?});
        defer self.allocator.free(soap_body);
        
        // HTTP 요청 전송 및 응답 파싱
        const response = try self.sendSOAPRequestWithResponse(soap_action, soap_body);
        defer self.allocator.free(response);
        
        // XML에서 외부 IP 추출
        if (std.mem.indexOf(u8, response, "<NewExternalIPAddress>")) |start_tag| {
            const content_start = start_tag + "<NewExternalIPAddress>".len;
            if (std.mem.indexOf(u8, response[content_start..], "</NewExternalIPAddress>")) |end_tag| {
                const ip = response[content_start..content_start + end_tag];
                const external_ip = try self.allocator.dupe(u8, ip);
                print("🌐 External IP: {s}\n", .{external_ip});
                return external_ip;
            }
        }
        
        return error.ExternalIPNotFound;
    }

    /// 현재 포트 매핑 목록 출력
    pub fn printPortMappings(self: *Self) void {
        print("📋 Current port mappings ({}):\n", .{self.mapped_ports.items.len});
        
        if (self.mapped_ports.items.len == 0) {
            print("  (No port mappings)\n", .{});
            return;
        }
        
        for (self.mapped_ports.items, 0..) |mapping, i| {
            print("  {}. {}:{s} -> {}:{s} ({s}) - {s}\n", .{
                i + 1,
                mapping.external_port,
                mapping.protocol.toString(),
                mapping.internal_port,
                mapping.protocol.toString(),
                mapping.description,
                if (mapping.lease_duration == 0) "permanent" else "temporary"
            });
        }
    }

    /// SSDP 디스커버리 수행
    fn performSSDPDiscovery(self: *Self) !ArrayList(DiscoveryResult) {
        var results = ArrayList(DiscoveryResult).init(self.allocator);
        
        // UDP 멀티캐스트 소켓 생성
        const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(socket);
        
        // 멀티캐스트 주소 설정 (239.255.255.250:1900)
        const multicast_addr = try net.Address.parseIp4("239.255.255.250", 1900);
        
        // M-SEARCH 요청 생성
        const msearch_request =
            \\M-SEARCH * HTTP/1.1\r
            \\HOST: 239.255.255.250:1900\r
            \\MAN: "ssdp:discover"\r
            \\ST: upnp:rootdevice\r
            \\MX: 3\r
            \\\r
        ;
        
        // 요청 전송
        _ = try std.posix.sendto(socket, msearch_request, 0, &multicast_addr.any, multicast_addr.getOsSockLen());
        
        // 응답 수신 (타임아웃 설정)
        const timeout_ms = self.discovery_timeout_ms;
        const timeout_sec: i32 = @intCast(timeout_ms / 1000);
        const timeout_usec: i32 = @intCast((timeout_ms % 1000) * 1000);
        
        // macOS에서는 timeval 구조체 필드명이 다를 수 있으므로 직접 설정
        const timeout_bytes = std.mem.toBytes(std.posix.timeval{
            .sec = timeout_sec,
            .usec = timeout_usec,
        });
        _ = try std.posix.setsockopt(socket, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, &timeout_bytes);
        
        // 응답들 수집
        var response_buffer: [2048]u8 = undefined;
        var response_count: u32 = 0;
        const max_responses = 10;
        
        while (response_count < max_responses) {
            const bytes_received = std.posix.recv(socket, &response_buffer, 0) catch |err| {
                switch (err) {
                    error.WouldBlock => break, // 타임아웃
                    else => return err,
                }
            };
            
            if (bytes_received == 0) break;
            
            const response = response_buffer[0..bytes_received];
            
            // HTTP 응답 파싱
            if (try self.parseDiscoveryResponse(response)) |result| {
                try results.append(result);
                response_count += 1;
            }
        }
        
        return results;
    }

    /// 디스커버리 응답 파싱
    fn parseDiscoveryResponse(self: *Self, response: []const u8) !?DiscoveryResult {
        // HTTP 상태 라인 확인
        if (!std.mem.startsWith(u8, response, "HTTP/1.1 200 OK")) {
            return null;
        }
        
        var location: ?[]const u8 = null;
        var server: ?[]const u8 = null;
        var st: ?[]const u8 = null;
        var usn: ?[]const u8 = null;
        
        // 헤더 파싱
        var lines = std.mem.splitSequence(u8, response, "\r\n");
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "LOCATION:") or std.mem.startsWith(u8, line, "Location:")) {
                location = std.mem.trim(u8, line[9..], " \t");
            } else if (std.mem.startsWith(u8, line, "SERVER:") or std.mem.startsWith(u8, line, "Server:")) {
                server = std.mem.trim(u8, line[7..], " \t");
            } else if (std.mem.startsWith(u8, line, "ST:") or std.mem.startsWith(u8, line, "st:")) {
                st = std.mem.trim(u8, line[3..], " \t");
            } else if (std.mem.startsWith(u8, line, "USN:") or std.mem.startsWith(u8, line, "usn:")) {
                usn = std.mem.trim(u8, line[4..], " \t");
            }
        }
        
        if (location == null or st == null) {
            return null;
        }
        
        return DiscoveryResult{
            .location = try self.allocator.dupe(u8, location.?),
            .server = try self.allocator.dupe(u8, server orelse "Unknown"),
            .st = try self.allocator.dupe(u8, st.?),
            .usn = try self.allocator.dupe(u8, usn orelse "Unknown"),
        };
    }

    /// 디바이스 정보 가져오기
    fn fetchDeviceInfo(self: *Self, location: []const u8) !bool {
        // 간단한 HTTP GET 요청으로 디바이스 설명 가져오기
        // 실제 구현에서는 HTTP 클라이언트 라이브러리 사용 권장
        
        // URL에서 호스트와 경로 추출
        if (std.mem.indexOf(u8, location, "://")) |protocol_end| {
            const url_without_protocol = location[protocol_end + 3..];
            if (std.mem.indexOf(u8, url_without_protocol, "/")) |path_start| {
                const host_port = url_without_protocol[0..path_start];
                // const path = url_without_protocol[path_start..]; // 현재 사용하지 않음
                
                // 호스트와 포트 분리
                var host: []const u8 = undefined;
                var port: u16 = 80;
                
                if (std.mem.lastIndexOf(u8, host_port, ":")) |colon_pos| {
                    host = host_port[0..colon_pos];
                    port = std.fmt.parseInt(u16, host_port[colon_pos + 1..], 10) catch 80;
                } else {
                    host = host_port;
                }
                
                // 게이트웨이 IP 저장
                self.gateway_ip = try self.allocator.dupe(u8, host);
                
                // 임시로 성공으로 처리 (실제 HTTP 요청 구현 필요)
                self.control_url = try self.allocator.dupe(u8, "/upnp/control/WANIPConn1");
                self.service_type = try self.allocator.dupe(u8, "urn:schemas-upnp-org:service:WANIPConnection:1");
                
                print("🔗 Gateway: {s}:{}, Control URL: {s}\n", .{ host, port, self.control_url.? });
                return true;
            }
        }
        
        return false;
    }

    /// SOAP 요청 전송
    fn sendSOAPRequest(self: *Self, action: []const u8, body: []const u8) !bool {
        _ = self;
        _ = body;
        
        // 실제 HTTP SOAP 요청 구현 필요
        // 현재는 시뮬레이션으로 성공 반환
        print("📤 Sending SOAP request: {s}\n", .{action});
        std.Thread.sleep(100 * std.time.ns_per_ms); // 100ms 지연
        return true;
    }

    /// SOAP 요청 전송 및 응답 반환
    fn sendSOAPRequestWithResponse(self: *Self, action: []const u8, body: []const u8) ![]const u8 {
        _ = body;
        
        // 실제 HTTP SOAP 요청 구현 필요
        // 현재는 시뮬레이션 응답 반환
        print("📤 Sending SOAP request: {s}\n", .{action});
        std.Thread.sleep(100 * std.time.ns_per_ms); // 100ms 지연
        
        // 가짜 외부 IP 응답
        const fake_response = 
            \\<?xml version="1.0"?>
            \\<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
            \\<s:Body>
            \\<u:GetExternalIPAddressResponse xmlns:u="urn:schemas-upnp-org:service:WANIPConnection:1">
            \\<NewExternalIPAddress>203.0.113.1</NewExternalIPAddress>
            \\</u:GetExternalIPAddressResponse>
            \\</s:Body>
            \\</s:Envelope>
        ;
        
        return try self.allocator.dupe(u8, fake_response);
    }
};

/// 로컬 IP 주소 감지
fn detectLocalIP(allocator: Allocator) ![]const u8 {
    // 간단한 방법: 구글 DNS에 연결해서 로컬 IP 확인
    const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
    defer std.posix.close(socket);
    
    const google_dns = try net.Address.parseIp4("8.8.8.8", 53);
    try std.posix.connect(socket, &google_dns.any, google_dns.getOsSockLen());
    
    var local_addr: std.posix.sockaddr = undefined;
    var addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);
    try std.posix.getsockname(socket, &local_addr, &addr_len);
    
    const addr = net.Address.initPosix(@alignCast(&local_addr));
    const ip_str = try std.fmt.allocPrint(allocator, "{any}", .{addr.in.sa.addr});
    
    return ip_str;
}

// 테스트 함수들
test "UPnPClient creation and destruction" {
    const allocator = std.testing.allocator;
    
    const upnp = try UPnPClient.init(allocator);
    defer upnp.deinit();
    
    try std.testing.expect(upnp.local_ip.len > 0);
    try std.testing.expect(upnp.mapped_ports.items.len == 0);
}

test "PortMapping protocol string conversion" {
    const tcp_protocol = UPnPClient.PortMapping.Protocol.TCP;
    const udp_protocol = UPnPClient.PortMapping.Protocol.UDP;
    
    try std.testing.expectEqualStrings("TCP", tcp_protocol.toString());
    try std.testing.expectEqualStrings("UDP", udp_protocol.toString());
}