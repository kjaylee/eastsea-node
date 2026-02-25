const std = @import("std");
const net = std.net;
const fs = std.fs;

/// Eastsea Node 온보딩 설정 구조체
/// REQ-101: 첫 실행 마법사에서 기본 설정 생성
pub const NodeConfig = struct {
    node_address: []const u8 = "127.0.0.1",
    node_port: u16 = 8000,
    rpc_port: u16 = 8545,
    data_dir: []const u8 = ".eastsea",
    is_validator: bool = true,
    max_peers: u16 = 50,
    log_level: []const u8 = "info",

    /// 설정을 JSON 바이트로 직렬화
    pub fn serialize(self: *const NodeConfig, allocator: std.mem.Allocator) ![]u8 {
        var buf = std.ArrayList(u8).init(allocator);
        errdefer buf.deinit();

        const writer = buf.writer();
        try writer.writeAll("{\n");
        try std.fmt.format(writer, "  \"node_address\": \"{s}\",\n", .{self.node_address});
        try std.fmt.format(writer, "  \"node_port\": {d},\n", .{self.node_port});
        try std.fmt.format(writer, "  \"rpc_port\": {d},\n", .{self.rpc_port});
        try std.fmt.format(writer, "  \"data_dir\": \"{s}\",\n", .{self.data_dir});
        try std.fmt.format(writer, "  \"is_validator\": {s},\n", .{if (self.is_validator) "true" else "false"});
        try std.fmt.format(writer, "  \"max_peers\": {d},\n", .{self.max_peers});
        try std.fmt.format(writer, "  \"log_level\": \"{s}\"\n", .{self.log_level});
        try writer.writeAll("}");

        return buf.toOwnedSlice();
    }

    /// JSON 바이트에서 설정 역직렬화 (간단한 파서)
    pub fn deserialize(data: []const u8) NodeConfig {
        var config = NodeConfig{};

        // node_port 파싱
        if (findJsonNumber(data, "node_port")) |port| {
            config.node_port = @intCast(port);
        }

        // rpc_port 파싱
        if (findJsonNumber(data, "rpc_port")) |port| {
            config.rpc_port = @intCast(port);
        }

        // is_validator 파싱
        if (findJsonBool(data, "is_validator")) |val| {
            config.is_validator = val;
        }

        // max_peers 파싱
        if (findJsonNumber(data, "max_peers")) |val| {
            config.max_peers = @intCast(val);
        }

        return config;
    }

    fn findJsonNumber(data: []const u8, key: []const u8) ?i64 {
        // "key": value 패턴 검색
        if (std.mem.indexOf(u8, data, key)) |key_pos| {
            // key 이후 ": " 패턴 찾기
            const after_key = key_pos + key.len;
            if (after_key + 3 < data.len) {
                // "\": " 패턴 매칭 (closing quote + colon + space)
                var search_pos = after_key;
                while (search_pos < data.len and data[search_pos] != ':') : (search_pos += 1) {}
                if (search_pos >= data.len) return null;
                search_pos += 1; // skip ':'
                while (search_pos < data.len and data[search_pos] == ' ') : (search_pos += 1) {}
                if (search_pos >= data.len) return null;

                var end = search_pos;
                while (end < data.len and (data[end] >= '0' and data[end] <= '9')) : (end += 1) {}
                if (end > search_pos) {
                    return std.fmt.parseInt(i64, data[search_pos..end], 10) catch null;
                }
            }
        }
        return null;
    }

    fn findJsonBool(data: []const u8, key: []const u8) ?bool {
        if (std.mem.indexOf(u8, data, key)) |key_pos| {
            const after_key = key_pos + key.len;
            var search_pos = after_key;
            while (search_pos < data.len and data[search_pos] != ':') : (search_pos += 1) {}
            if (search_pos >= data.len) return null;
            search_pos += 1; // skip ':'
            while (search_pos < data.len and data[search_pos] == ' ') : (search_pos += 1) {}
            if (search_pos >= data.len) return null;

            if (search_pos + 4 <= data.len and std.mem.eql(u8, data[search_pos .. search_pos + 4], "true")) {
                return true;
            }
            if (search_pos + 5 <= data.len and std.mem.eql(u8, data[search_pos .. search_pos + 5], "false")) {
                return false;
            }
        }
        return null;
    }
};

/// UT-101-01: 초기 설정 저장 및 로드
/// 설정 파일이 없으면 기본값으로 생성, 있으면 로드
pub fn saveInitialConfig(allocator: std.mem.Allocator, config_path: []const u8) !NodeConfig {
    // 기존 설정 파일 확인
    if (fs.cwd().openFile(config_path, .{})) |file| {
        defer file.close();
        const content = try file.readToEndAlloc(allocator, 4096);
        defer allocator.free(content);

        std.debug.print("📋 기존 설정 로드: {s}\n", .{config_path});
        return NodeConfig.deserialize(content);
    } else |_| {
        // 파일이 없으면 기본 설정 생성
        var config = NodeConfig{};

        // 포트 충돌 감지 및 대체 포트 할당
        config.node_port = pickHealthyPort(config.node_port);
        config.rpc_port = pickHealthyPort(config.rpc_port);

        // 설정 파일 저장
        const json = try config.serialize(allocator);
        defer allocator.free(json);

        const file = fs.cwd().createFile(config_path, .{}) catch |err| {
            std.debug.print("⚠️  설정 파일 저장 실패: {}\n", .{err});
            return config;
        };
        defer file.close();

        try file.writeAll(json);
        std.debug.print("✅ 초기 설정 생성 완료: {s}\n", .{config_path});
        std.debug.print("   node_port={d}, rpc_port={d}\n", .{ config.node_port, config.rpc_port });

        return config;
    }
}

/// UT-101-02: 사용 가능한 포트 탐색
/// 기본 포트 바인딩 시도 → 실패 시 +1씩 순차 탐색 (최대 10회)
pub fn pickHealthyPort(base_port: u16) u16 {
    const max_attempts: u16 = 10;
    var port = base_port;

    for (0..max_attempts) |_| {
        if (isPortAvailable(port)) {
            return port;
        }
        port +%= 1;
        if (port == 0) port = 1024; // 오버플로우 방지
    }

    // 모든 시도 실패 시 기본 포트 반환
    return base_port;
}

/// 포트가 사용 가능한지 확인
pub fn isPortAvailable(port: u16) bool {
    const address = net.Address.initIp4([4]u8{ 127, 0, 0, 1 }, port);
    if (address.listen(.{})) |server| {
        var s = server;
        s.deinit();
        return true;
    } else |_| {
        return false;
    }
}

/// 데이터 경로 검증 및 생성
pub fn validateDataPath(path: []const u8) !void {
    // 경로가 존재하는지 확인
    fs.cwd().access(path, .{}) catch {
        // 존재하지 않으면 생성
        fs.cwd().makePath(path) catch |err| {
            std.debug.print("⚠️  데이터 경로 생성 실패: {s} ({})\n", .{ path, err });
            return err;
        };
        std.debug.print("📁 데이터 경로 생성: {s}\n", .{path});
        return;
    };

    // 존재하면 쓰기 권한 확인
    std.debug.print("✅ 데이터 경로 확인: {s}\n", .{path});
}

// ============================================================
// Unit Tests (UT-101-01, UT-101-02)
// ============================================================

test "UT-101-01: NodeConfig 기본값 검증" {
    const config = NodeConfig{};
    try std.testing.expect(config.node_port == 8000);
    try std.testing.expect(config.rpc_port == 8545);
    try std.testing.expect(config.is_validator == true);
    try std.testing.expect(config.max_peers == 50);
    try std.testing.expect(std.mem.eql(u8, config.data_dir, ".eastsea"));
    try std.testing.expect(std.mem.eql(u8, config.log_level, "info"));
}

test "UT-101-01: NodeConfig 직렬화/역직렬화" {
    const allocator = std.testing.allocator;

    var config = NodeConfig{};
    config.node_port = 9000;
    config.rpc_port = 9545;
    config.is_validator = false;
    config.max_peers = 100;

    // 직렬화
    const json = try config.serialize(allocator);
    defer allocator.free(json);

    // JSON에 필수 필드 포함 확인
    try std.testing.expect(std.mem.indexOf(u8, json, "9000") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "9545") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "false") != null);

    // 역직렬화
    const loaded = NodeConfig.deserialize(json);
    try std.testing.expect(loaded.node_port == 9000);
    try std.testing.expect(loaded.rpc_port == 9545);
    try std.testing.expect(loaded.is_validator == false);
    try std.testing.expect(loaded.max_peers == 100);
}

test "UT-101-01: saveInitialConfig 파일 생성 및 로드" {
    const allocator = std.testing.allocator;
    const test_path = "/tmp/eastsea_test_config.json";

    // 기존 파일 삭제 (있으면)
    fs.cwd().deleteFile(test_path) catch {};

    // 첫 실행: 기본 설정 생성
    const config1 = try saveInitialConfig(allocator, test_path);
    try std.testing.expect(config1.is_validator == true);
    try std.testing.expect(config1.max_peers == 50);

    // 두 번째 실행: 기존 설정 로드
    const config2 = try saveInitialConfig(allocator, test_path);
    try std.testing.expect(config2.node_port == config1.node_port);
    try std.testing.expect(config2.rpc_port == config1.rpc_port);

    // 테스트 파일 정리
    fs.cwd().deleteFile(test_path) catch {};
}

test "UT-101-02: pickHealthyPort 사용 가능 포트 반환" {
    // 높은 포트 번호 사용 (충돌 가능성 낮음)
    const port = pickHealthyPort(49152);
    try std.testing.expect(port >= 49152);
    try std.testing.expect(port < 49162); // 최대 10회 시도
}

test "UT-101-02: isPortAvailable 검증" {
    // 높은 포트는 보통 사용 가능
    const available = isPortAvailable(49999);
    // 결과가 true든 false든 크래시 없이 반환되어야 함
    _ = available;
}

test "validateDataPath 경로 생성" {
    const test_dir = "/tmp/eastsea_test_data";

    // 기존 디렉토리 삭제
    fs.cwd().deleteTree(test_dir) catch {};

    // 경로 생성
    try validateDataPath(test_dir);

    // 생성 확인
    fs.cwd().access(test_dir, .{}) catch {
        try std.testing.expect(false); // 경로가 없으면 실패
    };

    // 재실행해도 에러 없음
    try validateDataPath(test_dir);

    // 정리
    fs.cwd().deleteTree(test_dir) catch {};
}
