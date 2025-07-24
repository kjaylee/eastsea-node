const std = @import("std");

/// 프로그램 실행 결과
pub const ProgramResult = struct {
    success: bool,
    error_message: ?[]const u8,
    logs: std.ArrayList([]const u8),
    
    pub fn init(allocator: std.mem.Allocator) ProgramResult {
        return ProgramResult{
            .success = true,
            .error_message = null,
            .logs = std.ArrayList([]const u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *ProgramResult) void {
        for (self.logs.items) |log| {
            self.logs.allocator.free(log);
        }
        self.logs.deinit();
        if (self.error_message) |msg| {
            self.logs.allocator.free(msg);
        }
    }
    
    pub fn addLog(self: *ProgramResult, message: []const u8) !void {
        const owned_message = try self.logs.allocator.dupe(u8, message);
        try self.logs.append(owned_message);
    }
    
    pub fn setError(self: *ProgramResult, message: []const u8) !void {
        self.success = false;
        self.error_message = try self.logs.allocator.dupe(u8, message);
    }
};

/// 프로그램 계정 데이터
pub const AccountData = struct {
    data: []u8,
    owner: [32]u8, // 프로그램 ID
    lamports: u64, // 잔액
    executable: bool,
    
    pub fn init(allocator: std.mem.Allocator, size: usize, owner: [32]u8) !AccountData {
        return AccountData{
            .data = try allocator.alloc(u8, size),
            .owner = owner,
            .lamports = 0,
            .executable = false,
        };
    }
    
    pub fn deinit(self: *AccountData, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

/// 프로그램 명령어
pub const Instruction = struct {
    program_id: [32]u8,
    accounts: []AccountMeta,
    data: []const u8,
    
    pub const AccountMeta = struct {
        pubkey: [32]u8,
        is_signer: bool,
        is_writable: bool,
    };
    
    pub fn init(program_id: [32]u8, accounts: []AccountMeta, data: []const u8) Instruction {
        return Instruction{
            .program_id = program_id,
            .accounts = accounts,
            .data = data,
        };
    }
};

/// 프로그램 인터페이스
pub const Program = struct {
    id: [32]u8,
    name: []const u8,
    executable: bool,
    
    const Self = @This();
    
    pub fn init(id: [32]u8, name: []const u8) Program {
        return Program{
            .id = id,
            .name = name,
            .executable = true,
        };
    }
    
    /// 프로그램 실행
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
        
        try result.addLog("Program execution started");
        
        // 프로그램별 실행 로직
        if (std.mem.eql(u8, self.name, "system")) {
            try self.executeSystemProgram(instruction, accounts, &result);
        } else if (std.mem.eql(u8, self.name, "token")) {
            try self.executeTokenProgram(instruction, accounts, &result);
        } else if (std.mem.eql(u8, self.name, "hello_world")) {
            try self.executeHelloWorldProgram(instruction, accounts, &result);
        } else {
            try result.setError("Unknown program");
            return result;
        }
        
        try result.addLog("Program execution completed");
        return result;
    }
    
    /// 시스템 프로그램 실행
    fn executeSystemProgram(
        self: *const Self,
        instruction: *const Instruction,
        accounts: *std.AutoHashMap([32]u8, AccountData),
        result: *ProgramResult,
    ) !void {
        _ = self;
        
        if (instruction.data.len == 0) {
            try result.setError("System program requires instruction data");
            return;
        }
        
        const command = instruction.data[0];
        
        switch (command) {
            0 => { // Create Account
                try result.addLog("Creating new account");
                if (instruction.accounts.len < 2) {
                    try result.setError("Create account requires 2 accounts");
                    return;
                }
                
                // const _from_account = instruction.accounts[0];
                const to_account = instruction.accounts[1];
                
                // 계정 생성 로직
                if (accounts.get(to_account.pubkey) != null) {
                    try result.setError("Account already exists");
                    return;
                }
                
                // 새 계정 생성 (실제로는 더 복잡한 로직 필요)
                try result.addLog("Account created successfully");
            },
            1 => { // Transfer
                try result.addLog("Transferring lamports");
                if (instruction.accounts.len < 2) {
                    try result.setError("Transfer requires 2 accounts");
                    return;
                }
                
                // 전송 로직 (실제로는 더 복잡한 로직 필요)
                try result.addLog("Transfer completed successfully");
            },
            else => {
                try result.setError("Unknown system program command");
            },
        }
    }
    
    /// 토큰 프로그램 실행
    fn executeTokenProgram(
        self: *const Self,
        instruction: *const Instruction,
        accounts: *std.AutoHashMap([32]u8, AccountData),
        result: *ProgramResult,
    ) !void {
        _ = self;
        _ = accounts;
        
        if (instruction.data.len == 0) {
            try result.setError("Token program requires instruction data");
            return;
        }
        
        const command = instruction.data[0];
        
        switch (command) {
            0 => { // Initialize Mint
                try result.addLog("Initializing token mint");
                // 토큰 민트 초기화 로직
                try result.addLog("Token mint initialized");
            },
            1 => { // Initialize Account
                try result.addLog("Initializing token account");
                // 토큰 계정 초기화 로직
                try result.addLog("Token account initialized");
            },
            2 => { // Mint To
                try result.addLog("Minting tokens");
                // 토큰 발행 로직
                try result.addLog("Tokens minted successfully");
            },
            3 => { // Transfer
                try result.addLog("Transferring tokens");
                // 토큰 전송 로직
                try result.addLog("Tokens transferred successfully");
            },
            else => {
                try result.setError("Unknown token program command");
            },
        }
    }
    
    /// Hello World 프로그램 실행 (예제)
    fn executeHelloWorldProgram(
        self: *const Self,
        instruction: *const Instruction,
        accounts: *std.AutoHashMap([32]u8, AccountData),
        result: *ProgramResult,
    ) !void {
        _ = self;
        _ = accounts;
        _ = instruction;
        
        try result.addLog("Hello, World from smart contract!");
        try result.addLog("This is a simple example program");
        
        // 간단한 카운터 예제
        try result.addLog("Incrementing counter...");
        try result.addLog("Counter incremented successfully");
    }
};

/// 프로그램 실행 환경
pub const ProgramExecutor = struct {
    allocator: std.mem.Allocator,
    programs: std.AutoHashMap([32]u8, Program),
    accounts: std.AutoHashMap([32]u8, AccountData),
    
    pub fn init(allocator: std.mem.Allocator) ProgramExecutor {
        return ProgramExecutor{
            .allocator = allocator,
            .programs = std.AutoHashMap([32]u8, Program).init(allocator),
            .accounts = std.AutoHashMap([32]u8, AccountData).init(allocator),
        };
    }
    
    pub fn deinit(self: *ProgramExecutor) void {
        // 계정 데이터 정리
        var account_iterator = self.accounts.iterator();
        while (account_iterator.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.accounts.deinit();
        self.programs.deinit();
    }
    
    /// 시스템 프로그램들 등록
    pub fn registerSystemPrograms(self: *ProgramExecutor) !void {
        // 시스템 프로그램
        const system_program_id = [_]u8{0} ** 32;
        const system_program = Program.init(system_program_id, "system");
        try self.programs.put(system_program_id, system_program);
        
        // 토큰 프로그램
        var token_program_id = [_]u8{0} ** 32;
        token_program_id[0] = 1;
        const token_program = Program.init(token_program_id, "token");
        try self.programs.put(token_program_id, token_program);
        
        // Hello World 프로그램 (예제)
        var hello_program_id = [_]u8{0} ** 32;
        hello_program_id[0] = 2;
        const hello_program = Program.init(hello_program_id, "hello_world");
        try self.programs.put(hello_program_id, hello_program);
    }
    
    /// 프로그램 등록
    pub fn registerProgram(self: *ProgramExecutor, program: Program) !void {
        try self.programs.put(program.id, program);
    }
    
    /// 계정 생성
    pub fn createAccount(self: *ProgramExecutor, pubkey: [32]u8, size: usize, owner: [32]u8) !void {
        const account_data = try AccountData.init(self.allocator, size, owner);
        try self.accounts.put(pubkey, account_data);
    }
    
    /// 명령어 실행
    pub fn executeInstruction(self: *ProgramExecutor, instruction: *const Instruction) !ProgramResult {
        const program = self.programs.get(instruction.program_id) orelse {
            var result = ProgramResult.init(self.allocator);
            try result.setError("Program not found");
            return result;
        };
        
        return try program.execute(self.allocator, instruction, &self.accounts);
    }
    
    /// 상태 출력
    pub fn printStatus(self: *const ProgramExecutor) void {
        std.debug.print("\n📊 Program Executor Status\n", .{});
        std.debug.print("==========================\n", .{});
        std.debug.print("Programs: {d}\n", .{self.programs.count()});
        std.debug.print("Accounts: {d}\n", .{self.accounts.count()});
        
        // 등록된 프로그램 목록
        std.debug.print("\n📋 Registered Programs:\n", .{});
        var program_iterator = self.programs.iterator();
        while (program_iterator.next()) |entry| {
            const program = entry.value_ptr;
            std.debug.print("  - {s} (ID: ", .{program.name});
            for (program.id[0..4]) |byte| {
                std.debug.print("{:02x}", .{byte});
            }
            std.debug.print("...)\n", .{});
        }
        std.debug.print("\n", .{});
    }
};

// 테스트 함수들
test "Program creation and execution" {
    const allocator = std.testing.allocator;
    
    var executor = ProgramExecutor.init(allocator);
    defer executor.deinit();
    
    try executor.registerSystemPrograms();
    
    // Hello World 프로그램 테스트
    var hello_program_id = [_]u8{0} ** 32;
    hello_program_id[0] = 2;
    
    const accounts = [_]Instruction.AccountMeta{};
    const data = [_]u8{};
    const instruction = Instruction.init(hello_program_id, &accounts, &data);
    
    var result = try executor.executeInstruction(&instruction);
    defer result.deinit();
    
    try std.testing.expect(result.success);
    try std.testing.expect(result.logs.items.len > 0);
}

test "System program transfer" {
    const allocator = std.testing.allocator;
    
    var executor = ProgramExecutor.init(allocator);
    defer executor.deinit();
    
    try executor.registerSystemPrograms();
    
    // 시스템 프로그램 테스트
    const system_program_id = [_]u8{0} ** 32;
    
    const from_account = [_]u8{1} ** 32;
    const to_account = [_]u8{2} ** 32;
    
    const accounts = [_]Instruction.AccountMeta{
        .{ .pubkey = from_account, .is_signer = true, .is_writable = true },
        .{ .pubkey = to_account, .is_signer = false, .is_writable = true },
    };
    
    const data = [_]u8{1}; // Transfer command
    const instruction = Instruction.init(system_program_id, &accounts, &data);
    
    var result = try executor.executeInstruction(&instruction);
    defer result.deinit();
    
    try std.testing.expect(result.success);
}