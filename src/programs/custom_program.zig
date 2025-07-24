const std = @import("std");
const Program = @import("program.zig").Program;
const ProgramResult = @import("program.zig").ProgramResult;
const Instruction = @import("program.zig").Instruction;
const AccountData = @import("program.zig").AccountData;

/// Helper function to add formatted log messages without memory leaks
fn addFormattedLog(result: *ProgramResult, allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    const formatted_msg = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(formatted_msg);
    try result.addLog(formatted_msg);
}

/// 사용자 정의 프로그램 인터페이스
pub const CustomProgram = struct {
    id: [32]u8,
    name: []const u8,
    code: []const u8, // 프로그램 바이트코드 또는 소스코드
    entry_point: *const fn (
        allocator: std.mem.Allocator,
        instruction: *const Instruction,
        accounts: *std.AutoHashMap([32]u8, AccountData),
        result: *ProgramResult,
    ) anyerror!void,
    
    const Self = @This();
    
    pub fn init(
        id: [32]u8,
        name: []const u8,
        code: []const u8,
        entry_point: *const fn (
            allocator: std.mem.Allocator,
            instruction: *const Instruction,
            accounts: *std.AutoHashMap([32]u8, AccountData),
            result: *ProgramResult,
        ) anyerror!void,
    ) CustomProgram {
        return CustomProgram{
            .id = id,
            .name = name,
            .code = code,
            .entry_point = entry_point,
        };
    }
    
    /// 사용자 정의 프로그램 실행
    pub fn execute(
        self: *const Self,
        allocator: std.mem.Allocator,
        instruction: *const Instruction,
        accounts: *std.AutoHashMap([32]u8, AccountData),
    ) !ProgramResult {
        var result = ProgramResult.init(allocator);
        
        // 프로그램 ID 확인
        if (!std.mem.eql(u8, &self.id, &instruction.program_id)) {
            try result.setError("Program ID mismatch");
            return result;
        }
        
        try result.addLog("Custom program execution started");
        
        // 사용자 정의 프로그램 실행
        self.entry_point(allocator, instruction, accounts, &result) catch |err| {
            const error_msg = switch (err) {
                error.OutOfMemory => "Out of memory",
                error.InvalidInstruction => "Invalid instruction",
                error.AccountNotFound => "Account not found",
                error.InsufficientFunds => "Insufficient funds",
                error.Unauthorized => "Unauthorized access",
                else => "Unknown error",
            };
            try result.setError(error_msg);
            return result;
        };
        
        try result.addLog("Custom program execution completed");
        return result;
    }
    
    /// Program 구조체로 변환
    pub fn toProgram(self: *const Self) Program {
        return Program.init(self.id, self.name);
    }
};

/// 사용자 정의 프로그램 레지스트리
pub const CustomProgramRegistry = struct {
    allocator: std.mem.Allocator,
    programs: std.AutoHashMap([32]u8, CustomProgram),
    
    pub fn init(allocator: std.mem.Allocator) CustomProgramRegistry {
        return CustomProgramRegistry{
            .allocator = allocator,
            .programs = std.AutoHashMap([32]u8, CustomProgram).init(allocator),
        };
    }
    
    pub fn deinit(self: *CustomProgramRegistry) void {
        self.programs.deinit();
    }
    
    /// 사용자 정의 프로그램 등록
    pub fn registerProgram(self: *CustomProgramRegistry, program: CustomProgram) !void {
        try self.programs.put(program.id, program);
    }
    
    /// 프로그램 조회
    pub fn getProgram(self: *const CustomProgramRegistry, program_id: [32]u8) ?CustomProgram {
        return self.programs.get(program_id);
    }
    
    /// 프로그램 실행
    pub fn executeProgram(
        self: *const CustomProgramRegistry,
        program_id: [32]u8,
        instruction: *const Instruction,
        accounts: *std.AutoHashMap([32]u8, AccountData),
    ) !ProgramResult {
        const program = self.programs.get(program_id) orelse {
            var result = ProgramResult.init(self.allocator);
            try result.setError("Custom program not found");
            return result;
        };
        
        return try program.execute(self.allocator, instruction, accounts);
    }
    
    /// 등록된 프로그램 목록
    pub fn listPrograms(self: *const CustomProgramRegistry) void {
        std.debug.print("\n📋 Custom Programs Registry\n", .{});
        std.debug.print("============================\n", .{});
        std.debug.print("Total programs: {d}\n", .{self.programs.count()});
        
        var iterator = self.programs.iterator();
        while (iterator.next()) |entry| {
            const program = entry.value_ptr;
            std.debug.print("  - {s} (ID: ", .{program.name});
            for (program.id[0..4]) |byte| {
                std.debug.print("{x:0>2}", .{byte});
            }
            std.debug.print("...)\n", .{});
        }
        std.debug.print("\n", .{});
    }
};

/// 예제 사용자 정의 프로그램들

/// 카운터 프로그램 예제
pub fn counterProgramEntryPoint(
    allocator: std.mem.Allocator,
    instruction: *const Instruction,
    accounts: *std.AutoHashMap([32]u8, AccountData),
    result: *ProgramResult,
) !void {
    _ = allocator;
    _ = accounts;
    
    try result.addLog("Counter program started");
    
    if (instruction.data.len == 0) {
        try result.setError("Counter program requires instruction data");
        return;
    }
    
    const command = instruction.data[0];
    
    switch (command) {
        0 => { // Initialize counter
            try result.addLog("Initializing counter to 0");
            try result.addLog("Counter initialized successfully");
        },
        1 => { // Increment counter
            try result.addLog("Incrementing counter");
            // 실제로는 계정 데이터에서 카운터 값을 읽고 증가시켜야 함
            try result.addLog("Counter incremented to 1");
        },
        2 => { // Decrement counter
            try result.addLog("Decrementing counter");
            try result.addLog("Counter decremented to 0");
        },
        3 => { // Get counter value
            try result.addLog("Getting counter value");
            try result.addLog("Current counter value: 0");
        },
        else => {
            try result.setError("Unknown counter command");
        },
    }
}

/// 계산기 프로그램 예제
pub fn calculatorProgramEntryPoint(
    allocator: std.mem.Allocator,
    instruction: *const Instruction,
    accounts: *std.AutoHashMap([32]u8, AccountData),
    result: *ProgramResult,
) !void {
    _ = accounts;
    
    try result.addLog("Calculator program started");
    
    if (instruction.data.len < 3) {
        try result.setError("Calculator requires at least 3 bytes of data (operation, operand1, operand2)");
        return;
    }
    
    const operation = instruction.data[0];
    const operand1 = instruction.data[1];
    const operand2 = instruction.data[2];
    
    const result_value = switch (operation) {
        0 => operand1 + operand2, // Addition
        1 => operand1 - operand2, // Subtraction
        2 => operand1 * operand2, // Multiplication
        3 => if (operand2 != 0) operand1 / operand2 else {
            try result.setError("Division by zero");
            return;
        }, // Division
        else => {
            try result.setError("Unknown operation");
            return;
        },
    };
    
    const operation_name = switch (operation) {
        0 => "Addition",
        1 => "Subtraction", 
        2 => "Multiplication",
        3 => "Division",
        else => unreachable,
    };
    
    try addFormattedLog(result, allocator, "{s}: {d} op {d} = {d}", .{ operation_name, operand1, operand2, result_value });
    try result.addLog("Calculation completed successfully");
}

/// 투표 프로그램 예제
pub fn votingProgramEntryPoint(
    allocator: std.mem.Allocator,
    instruction: *const Instruction,
    accounts: *std.AutoHashMap([32]u8, AccountData),
    result: *ProgramResult,
) !void {
    _ = accounts;
    
    try result.addLog("Voting program started");
    
    if (instruction.data.len == 0) {
        try result.setError("Voting program requires instruction data");
        return;
    }
    
    const command = instruction.data[0];
    
    switch (command) {
        0 => { // Create proposal
            try result.addLog("Creating new proposal");
            if (instruction.data.len < 2) {
                try result.setError("Create proposal requires proposal ID");
                return;
            }
            const proposal_id = instruction.data[1];
            try addFormattedLog(result, allocator, "Proposal {d} created successfully", .{proposal_id});
        },
        1 => { // Cast vote
            try result.addLog("Casting vote");
            if (instruction.data.len < 3) {
                try result.setError("Cast vote requires proposal ID and vote choice");
                return;
            }
            const proposal_id = instruction.data[1];
            const vote_choice = instruction.data[2]; // 0 = No, 1 = Yes
            const vote_text = if (vote_choice == 1) "Yes" else "No";
            try addFormattedLog(result, allocator, "Vote cast: {s} for proposal {d}", .{ vote_text, proposal_id });
        },
        2 => { // Get results
            try result.addLog("Getting voting results");
            if (instruction.data.len < 2) {
                try result.setError("Get results requires proposal ID");
                return;
            }
            const proposal_id = instruction.data[1];
            // 실제로는 계정 데이터에서 투표 결과를 읽어야 함
            try addFormattedLog(result, allocator, "Proposal {d} results: Yes: 5, No: 3", .{proposal_id});
        },
        else => {
            try result.setError("Unknown voting command");
        },
    }
}

/// 간단한 토큰 스왑 프로그램 예제
pub fn tokenSwapProgramEntryPoint(
    allocator: std.mem.Allocator,
    instruction: *const Instruction,
    accounts: *std.AutoHashMap([32]u8, AccountData),
    result: *ProgramResult,
) !void {
    _ = accounts;
    
    try result.addLog("Token Swap program started");
    
    if (instruction.data.len == 0) {
        try result.setError("Token swap program requires instruction data");
        return;
    }
    
    const command = instruction.data[0];
    
    switch (command) {
        0 => { // Initialize swap pool
            try result.addLog("Initializing token swap pool");
            try result.addLog("Swap pool initialized with 1000 Token A and 1000 Token B");
        },
        1 => { // Swap Token A for Token B
            try result.addLog("Swapping Token A for Token B");
            if (instruction.data.len < 2) {
                try result.setError("Swap requires amount");
                return;
            }
            const amount = instruction.data[1];
            // 간단한 1:1 스왑 비율
            try addFormattedLog(result, allocator, "Swapped {d} Token A for {d} Token B", .{ amount, amount });
        },
        2 => { // Swap Token B for Token A
            try result.addLog("Swapping Token B for Token A");
            if (instruction.data.len < 2) {
                try result.setError("Swap requires amount");
                return;
            }
            const amount = instruction.data[1];
            try addFormattedLog(result, allocator, "Swapped {d} Token B for {d} Token A", .{ amount, amount });
        },
        3 => { // Get pool info
            try result.addLog("Getting pool information");
            try result.addLog("Pool reserves: 950 Token A, 1050 Token B");
        },
        else => {
            try result.setError("Unknown swap command");
        },
    }
}

// 테스트 함수들
test "Custom program creation and execution" {
    const allocator = std.testing.allocator;
    
    var registry = CustomProgramRegistry.init(allocator);
    defer registry.deinit();
    
    // 카운터 프로그램 등록
    var counter_id = [_]u8{0} ** 32;
    counter_id[0] = 10;
    
    const counter_program = CustomProgram.init(
        counter_id,
        "counter",
        "counter program bytecode",
        counterProgramEntryPoint,
    );
    
    try registry.registerProgram(counter_program);
    
    // 프로그램 실행 테스트
    const accounts = [_]Instruction.AccountMeta{};
    const data = [_]u8{0}; // Initialize command
    const instruction = Instruction.init(counter_id, &accounts, &data);
    
    var dummy_accounts = std.AutoHashMap([32]u8, AccountData).init(allocator);
    defer dummy_accounts.deinit();
    
    var result = try registry.executeProgram(counter_id, &instruction, &dummy_accounts);
    defer result.deinit();
    
    try std.testing.expect(result.success);
    try std.testing.expect(result.logs.items.len > 0);
}

test "Calculator program" {
    const allocator = std.testing.allocator;
    
    var registry = CustomProgramRegistry.init(allocator);
    defer registry.deinit();
    
    // 계산기 프로그램 등록
    var calc_id = [_]u8{0} ** 32;
    calc_id[0] = 11;
    
    const calc_program = CustomProgram.init(
        calc_id,
        "calculator",
        "calculator program bytecode",
        calculatorProgramEntryPoint,
    );
    
    try registry.registerProgram(calc_program);
    
    // 덧셈 테스트
    const accounts = [_]Instruction.AccountMeta{};
    const data = [_]u8{ 0, 5, 3 }; // Addition: 5 + 3
    const instruction = Instruction.init(calc_id, &accounts, &data);
    
    var dummy_accounts = std.AutoHashMap([32]u8, AccountData).init(allocator);
    defer dummy_accounts.deinit();
    
    var result = try registry.executeProgram(calc_id, &instruction, &dummy_accounts);
    defer result.deinit();
    
    try std.testing.expect(result.success);
    try std.testing.expect(result.logs.items.len > 0);
}