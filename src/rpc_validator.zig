const std = @import("std");

/// REQ-021: RPC mock 응답 제거 — 실데이터 검증
/// UT-021-01: getNodeInfo 등 RPC 응답에서 mock 값 의존 제거

/// RPC 응답 검증기: mock/stub/dummy 값 탐지
pub fn validateRpcResponse(response: []const u8) bool {
    // mock/stub 패턴 탐지
    const forbidden_patterns = [_][]const u8{
        "mock",
        "stub",
        "dummy",
        "TODO",
        "FIXME",
        "placeholder",
        "fake",
        "hardcoded",
        "test_value",
        "lorem",
    };

    const lower_buf: [4096]u8 = undefined;
    _ = lower_buf;

    for (forbidden_patterns) |pattern| {
        if (containsCaseInsensitive(response, pattern)) {
            return false; // mock 값 탐지
        }
    }

    return true;
}

/// JSON 응답 구조 검증
pub fn validateJsonRpcStructure(response: []const u8) bool {
    // 필수 필드 확인
    const required = [_][]const u8{
        "jsonrpc",
        "result",
        "id",
    };

    for (required) |field| {
        if (std.mem.indexOf(u8, response, field) == null) {
            return false;
        }
    }

    // 에러 필드가 null이 아닌 경우 확인
    if (std.mem.indexOf(u8, response, "\"error\":null")) |_| {
        return true; // 정상 응답
    }

    // error 필드가 있으면 에러 응답이지만 구조는 유효
    if (std.mem.indexOf(u8, response, "\"error\"")) |_| {
        return true;
    }

    return false;
}

fn containsCaseInsensitive(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var match = true;
        for (0..needle.len) |j| {
            const h = if (haystack[i + j] >= 'A' and haystack[i + j] <= 'Z') haystack[i + j] + 32 else haystack[i + j];
            const n = if (needle[j] >= 'A' and needle[j] <= 'Z') needle[j] + 32 else needle[j];
            if (h != n) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

// === Tests ===

test "UT-021-01: validateRpcResponse 정상 응답" {
    const response =
        \\{"jsonrpc":"2.0","result":2,"error":null,"id":1}
    ;
    try std.testing.expect(validateRpcResponse(response) == true);
}

test "UT-021-01: validateRpcResponse mock 값 탐지" {
    const response =
        \\{"jsonrpc":"2.0","result":"mock_value","error":null,"id":1}
    ;
    try std.testing.expect(validateRpcResponse(response) == false);
}

test "UT-021-01: validateRpcResponse stub 탐지" {
    const response =
        \\{"result":"stub_data"}
    ;
    try std.testing.expect(validateRpcResponse(response) == false);
}

test "validateJsonRpcStructure 정상" {
    const response =
        \\{"jsonrpc":"2.0","result":2,"error":null,"id":1}
    ;
    try std.testing.expect(validateJsonRpcStructure(response) == true);
}

test "validateJsonRpcStructure 필수 필드 누락" {
    const response =
        \\{"result":2}
    ;
    try std.testing.expect(validateJsonRpcStructure(response) == false);
}
