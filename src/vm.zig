const std = @import("std");

/// Eastsea VM — 스택 기반 스마트 컨트랙트 가상 머신
/// EVM 호환 개념, 단순화 구현

// ============================================================
// 옵코드 정의
// ============================================================
pub const OpCode = enum(u8) {
    // 스택 조작
    PUSH = 0x01,
    POP = 0x02,
    DUP = 0x03,
    SWAP = 0x04,

    // 산술
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    MOD = 0x14,
    GT = 0x15,
    LT = 0x16,
    EQ = 0x17,

    // 스토리지
    SSTORE = 0x20, // key, value → storage
    SLOAD = 0x21, // key → value

    // 흐름 제어
    JUMP = 0x30,
    JUMPI = 0x31, // 조건부 점프
    HALT = 0x3F,

    // 시스템
    LOG = 0x40, // 이벤트 발생
    CALLER = 0x41, // 호출자 주소
    BALANCE = 0x42,
    TIMESTAMP = 0x43,

    pub fn gasPrice(self: OpCode) u64 {
        return switch (self) {
            .PUSH, .POP, .DUP, .SWAP => 3,
            .ADD, .SUB, .MUL, .DIV, .MOD => 5,
            .GT, .LT, .EQ => 3,
            .SSTORE => 20000,
            .SLOAD => 200,
            .JUMP, .JUMPI => 8,
            .HALT => 0,
            .LOG => 375,
            .CALLER, .BALANCE, .TIMESTAMP => 2,
        };
    }

    pub fn fromByte(byte: u8) ?OpCode {
        return std.meta.intToEnum(OpCode, byte) catch null;
    }
};

// ============================================================
// VM 상태
// ============================================================
pub const VM_STACK_SIZE = 1024;
pub const VM_MAX_GAS = 1_000_000;

pub const ExecutionResult = struct {
    success: bool,
    gas_used: u64,
    return_value: i64,
    logs: std.array_list.Managed(LogEntry),

    pub fn deinit(self: *ExecutionResult) void {
        for (self.logs.items) |*entry| {
            entry.deinit();
        }
        self.logs.deinit();
    }
};

pub const LogEntry = struct {
    topic: i64,
    value: i64,
    allocator: ?std.mem.Allocator = null,

    pub fn deinit(self: *LogEntry) void {
        _ = self;
    }
};

pub const Contract = struct {
    bytecode: []const u8,
    storage: std.AutoHashMap(i64, i64),
    balance: i64,
    creator: []const u8,

    pub fn init(allocator: std.mem.Allocator, bytecode: []const u8, creator: []const u8) Contract {
        return .{
            .bytecode = bytecode,
            .storage = std.AutoHashMap(i64, i64).init(allocator),
            .balance = 0,
            .creator = creator,
        };
    }

    pub fn deinit(self: *Contract) void {
        self.storage.deinit();
    }
};

// ============================================================
// 가상 머신
// ============================================================
pub const VM = struct {
    stack: [VM_STACK_SIZE]i64,
    sp: usize, // 스택 포인터
    pc: usize, // 프로그램 카운터
    gas_remaining: u64,
    gas_used: u64,
    storage: *std.AutoHashMap(i64, i64),
    allocator: std.mem.Allocator,
    caller: []const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        storage: *std.AutoHashMap(i64, i64),
        caller: []const u8,
        gas_limit: u64,
    ) VM {
        return .{
            .stack = [_]i64{0} ** VM_STACK_SIZE,
            .sp = 0,
            .pc = 0,
            .gas_remaining = gas_limit,
            .gas_used = 0,
            .storage = storage,
            .allocator = allocator,
            .caller = caller,
        };
    }

    /// 바이트코드 실행
    pub fn execute(self: *VM, bytecode: []const u8) !ExecutionResult {
        var logs = std.array_list.Managed(LogEntry).init(self.allocator);
        errdefer logs.deinit();

        while (self.pc < bytecode.len) {
            const opcode_byte = bytecode[self.pc];
            const opcode = OpCode.fromByte(opcode_byte) orelse {
                return ExecutionResult{
                    .success = false,
                    .gas_used = self.gas_used,
                    .return_value = 0,
                    .logs = logs,
                };
            };

            // Gas 확인
            const gas_cost = opcode.gasPrice();
            if (self.gas_remaining < gas_cost) {
                return ExecutionResult{
                    .success = false,
                    .gas_used = self.gas_used,
                    .return_value = 0,
                    .logs = logs,
                };
            }
            self.gas_remaining -= gas_cost;
            self.gas_used += gas_cost;
            self.pc += 1;

            switch (opcode) {
                .PUSH => {
                    if (self.pc + 8 > bytecode.len) break;
                    const value = std.mem.readInt(i64, bytecode[self.pc..][0..8], .big);
                    try self.push(value);
                    self.pc += 8;
                },
                .POP => {
                    _ = try self.pop();
                },
                .DUP => {
                    const val = try self.peek();
                    try self.push(val);
                },
                .SWAP => {
                    if (self.sp < 2) return error.StackUnderflow;
                    const tmp = self.stack[self.sp - 1];
                    self.stack[self.sp - 1] = self.stack[self.sp - 2];
                    self.stack[self.sp - 2] = tmp;
                },

                // 산술
                .ADD => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(a +% b);
                },
                .SUB => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(a -% b);
                },
                .MUL => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(a *% b);
                },
                .DIV => {
                    const b = try self.pop();
                    const a = try self.pop();
                    if (b == 0) {
                        try self.push(0);
                    } else {
                        try self.push(@divTrunc(a, b));
                    }
                },
                .MOD => {
                    const b = try self.pop();
                    const a = try self.pop();
                    if (b == 0) {
                        try self.push(0);
                    } else {
                        try self.push(@mod(a, b));
                    }
                },
                .GT => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(if (a > b) @as(i64, 1) else @as(i64, 0));
                },
                .LT => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(if (a < b) @as(i64, 1) else @as(i64, 0));
                },
                .EQ => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(if (a == b) @as(i64, 1) else @as(i64, 0));
                },

                // 스토리지
                .SSTORE => {
                    const value = try self.pop();
                    const key = try self.pop();
                    try self.storage.put(key, value);
                },
                .SLOAD => {
                    const key = try self.pop();
                    const value = self.storage.get(key) orelse 0;
                    try self.push(value);
                },

                // 흐름 제어
                .JUMP => {
                    const dest = try self.pop();
                    if (dest < 0 or @as(usize, @intCast(dest)) >= bytecode.len) {
                        return error.InvalidJump;
                    }
                    self.pc = @intCast(dest);
                },
                .JUMPI => {
                    const cond = try self.pop();
                    const dest = try self.pop();
                    if (cond != 0) {
                        if (dest < 0 or @as(usize, @intCast(dest)) >= bytecode.len) {
                            return error.InvalidJump;
                        }
                        self.pc = @intCast(dest);
                    }
                },
                .HALT => {
                    const ret = if (self.sp > 0) try self.pop() else @as(i64, 0);
                    return ExecutionResult{
                        .success = true,
                        .gas_used = self.gas_used,
                        .return_value = ret,
                        .logs = logs,
                    };
                },

                // 시스템
                .LOG => {
                    const value = try self.pop();
                    const topic = try self.pop();
                    try logs.append(LogEntry{ .topic = topic, .value = value });
                },
                .CALLER => {
                    // 호출자 주소의 해시를 i64로 변환
                    var hash: u64 = 0;
                    for (self.caller) |c| {
                        hash = hash *% 31 +% c;
                    }
                    try self.push(@bitCast(hash));
                },
                .BALANCE => {
                    try self.push(1000); // 기본 잔액
                },
                .TIMESTAMP => {
                    try self.push(std.time.timestamp());
                },
            }
        }

        return ExecutionResult{
            .success = true,
            .gas_used = self.gas_used,
            .return_value = if (self.sp > 0) self.stack[self.sp - 1] else 0,
            .logs = logs,
        };
    }

    fn push(self: *VM, value: i64) !void {
        if (self.sp >= VM_STACK_SIZE) return error.StackOverflow;
        self.stack[self.sp] = value;
        self.sp += 1;
    }

    fn pop(self: *VM) !i64 {
        if (self.sp == 0) return error.StackUnderflow;
        self.sp -= 1;
        return self.stack[self.sp];
    }

    fn peek(self: *VM) !i64 {
        if (self.sp == 0) return error.StackUnderflow;
        return self.stack[self.sp - 1];
    }
};

// ============================================================
// 바이트코드 어셈블러 (편의 함수)
// ============================================================
pub const Assembler = struct {
    code: std.array_list.Managed(u8),

    pub fn init(allocator: std.mem.Allocator) Assembler {
        return .{ .code = std.array_list.Managed(u8).init(allocator) };
    }

    pub fn deinit(self: *Assembler) void {
        self.code.deinit();
    }

    pub fn push(self: *Assembler, value: i64) !void {
        try self.code.append(@intFromEnum(OpCode.PUSH));
        const bytes = std.mem.toBytes(std.mem.nativeTo(i64, value, .big));
        try self.code.appendSlice(&bytes);
    }

    pub fn op(self: *Assembler, opcode: OpCode) !void {
        try self.code.append(@intFromEnum(opcode));
    }

    pub fn build(self: *const Assembler) []const u8 {
        return self.code.items;
    }
};

// ============================================================
// 테스트
// ============================================================
test "VM: PUSH + ADD" {
    const allocator = std.testing.allocator;
    var storage = std.AutoHashMap(i64, i64).init(allocator);
    defer storage.deinit();

    var asm_ = Assembler.init(allocator);
    defer asm_.deinit();
    try asm_.push(10);
    try asm_.push(20);
    try asm_.op(.ADD);
    try asm_.op(.HALT);

    var vm = VM.init(allocator, &storage, "test_caller", VM_MAX_GAS);
    var result = try vm.execute(asm_.build());
    defer result.deinit();

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(i64, 30), result.return_value);
}

test "VM: PUSH + MUL + SUB" {
    const allocator = std.testing.allocator;
    var storage = std.AutoHashMap(i64, i64).init(allocator);
    defer storage.deinit();

    var asm_ = Assembler.init(allocator);
    defer asm_.deinit();
    try asm_.push(5);
    try asm_.push(6);
    try asm_.op(.MUL); // 30
    try asm_.push(10);
    try asm_.op(.SUB); // 30 - 10 = 20
    try asm_.op(.HALT);

    var vm = VM.init(allocator, &storage, "test", VM_MAX_GAS);
    var result = try vm.execute(asm_.build());
    defer result.deinit();

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(i64, 20), result.return_value);
}

test "VM: SSTORE + SLOAD" {
    const allocator = std.testing.allocator;
    var storage = std.AutoHashMap(i64, i64).init(allocator);
    defer storage.deinit();

    var asm_ = Assembler.init(allocator);
    defer asm_.deinit();
    try asm_.push(42); // key
    try asm_.push(999); // value
    try asm_.op(.SSTORE); // storage[42] = 999
    try asm_.push(42); // key
    try asm_.op(.SLOAD); // push storage[42]
    try asm_.op(.HALT);

    var vm = VM.init(allocator, &storage, "test", VM_MAX_GAS);
    var result = try vm.execute(asm_.build());
    defer result.deinit();

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(i64, 999), result.return_value);
}

test "VM: 비교 연산 GT/EQ" {
    const allocator = std.testing.allocator;
    var storage = std.AutoHashMap(i64, i64).init(allocator);
    defer storage.deinit();

    var asm_ = Assembler.init(allocator);
    defer asm_.deinit();
    try asm_.push(100);
    try asm_.push(50);
    try asm_.op(.GT); // 100 > 50 → 1
    try asm_.op(.HALT);

    var vm = VM.init(allocator, &storage, "test", VM_MAX_GAS);
    var result = try vm.execute(asm_.build());
    defer result.deinit();

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(i64, 1), result.return_value);
}

test "VM: LOG 이벤트" {
    const allocator = std.testing.allocator;
    var storage = std.AutoHashMap(i64, i64).init(allocator);
    defer storage.deinit();

    var asm_ = Assembler.init(allocator);
    defer asm_.deinit();
    try asm_.push(1); // topic
    try asm_.push(42); // value
    try asm_.op(.LOG);
    try asm_.push(0);
    try asm_.op(.HALT);

    var vm = VM.init(allocator, &storage, "test", VM_MAX_GAS);
    var result = try vm.execute(asm_.build());
    defer result.deinit();

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(usize, 1), result.logs.items.len);
    try std.testing.expectEqual(@as(i64, 1), result.logs.items[0].topic);
    try std.testing.expectEqual(@as(i64, 42), result.logs.items[0].value);
}

test "VM: Gas 소진" {
    const allocator = std.testing.allocator;
    var storage = std.AutoHashMap(i64, i64).init(allocator);
    defer storage.deinit();

    var asm_ = Assembler.init(allocator);
    defer asm_.deinit();
    try asm_.push(1);
    try asm_.push(2);
    try asm_.op(.ADD);
    try asm_.op(.HALT);

    // Gas를 아주 적게 설정 (PUSH 3 + PUSH 3 = 6, 총 필요 11)
    var vm = VM.init(allocator, &storage, "test", 5);
    var result = try vm.execute(asm_.build());
    defer result.deinit();

    try std.testing.expect(!result.success); // Gas 부족
}

test "VM: DUP + SWAP" {
    const allocator = std.testing.allocator;
    var storage = std.AutoHashMap(i64, i64).init(allocator);
    defer storage.deinit();

    var asm_ = Assembler.init(allocator);
    defer asm_.deinit();
    try asm_.push(7);
    try asm_.op(.DUP); // 7, 7
    try asm_.op(.ADD); // 14
    try asm_.op(.HALT);

    var vm = VM.init(allocator, &storage, "test", VM_MAX_GAS);
    var result = try vm.execute(asm_.build());
    defer result.deinit();

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(i64, 14), result.return_value);
}

test "VM: ERC20 토큰 시뮬레이션" {
    const allocator = std.testing.allocator;
    var storage = std.AutoHashMap(i64, i64).init(allocator);
    defer storage.deinit();

    // 토큰 총 발행량 = 1_000_000
    // storage[0] = total supply
    // storage[1] = owner balance
    var asm_ = Assembler.init(allocator);
    defer asm_.deinit();

    // Total supply 설정
    try asm_.push(0); // key: total_supply
    try asm_.push(1_000_000); // value
    try asm_.op(.SSTORE);

    // Owner 잔액 설정
    try asm_.push(1); // key: owner_balance
    try asm_.push(1_000_000); // value (전량 보유)
    try asm_.op(.SSTORE);

    // Transfer: owner → user (100 토큰)
    // owner 잔액 읽기
    try asm_.push(1);
    try asm_.op(.SLOAD); // 1_000_000

    try asm_.push(100);
    try asm_.op(.SUB); // 999_900

    // owner 잔액 저장
    try asm_.push(1);
    try asm_.op(.SWAP);
    try asm_.op(.SSTORE);

    // user 잔액 설정
    try asm_.push(2); // key: user_balance
    try asm_.push(100);
    try asm_.op(.SSTORE);

    // Transfer 이벤트 로그
    try asm_.push(0xEE); // topic: Transfer
    try asm_.push(100); // amount
    try asm_.op(.LOG);

    // 최종: owner 잔액 반환
    try asm_.push(1);
    try asm_.op(.SLOAD);
    try asm_.op(.HALT);

    var vm = VM.init(allocator, &storage, "owner_addr", VM_MAX_GAS);
    var result = try vm.execute(asm_.build());
    defer result.deinit();

    try std.testing.expect(result.success);
    try std.testing.expectEqual(@as(i64, 999_900), result.return_value);
    try std.testing.expectEqual(@as(i64, 100), storage.get(2).?); // user balance
    try std.testing.expectEqual(@as(usize, 1), result.logs.items.len);
}
