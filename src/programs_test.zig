const std = @import("std");
const print = std.debug.print;

const Program = @import("programs/program.zig").Program;
const ProgramExecutor = @import("programs/program.zig").ProgramExecutor;
const Instruction = @import("programs/program.zig").Instruction;
const AccountData = @import("programs/program.zig").AccountData;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 명령행 인수 파싱
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        print("Usage: {s} <test_mode>\n", .{args[0]});
        print("Test modes:\n", .{});
        print("  basic     - Basic program execution test\n", .{});
        print("  system    - System program test\n", .{});
        print("  token     - Token program test\n", .{});
        print("  hello     - Hello World program test\n", .{});
        print("  all       - Run all tests\n", .{});
        print("\nExample: {s} basic\n", .{args[0]});
        return;
    }

    const test_mode = args[1];

    print("🚀 Starting Smart Contract (Programs) Test\n", .{});
    print("==========================================\n", .{});
    print("Test mode: {s}\n", .{test_mode});
    print("\n", .{});

    if (std.mem.eql(u8, test_mode, "basic")) {
        try runBasicTest(allocator);
    } else if (std.mem.eql(u8, test_mode, "system")) {
        try runSystemProgramTest(allocator);
    } else if (std.mem.eql(u8, test_mode, "token")) {
        try runTokenProgramTest(allocator);
    } else if (std.mem.eql(u8, test_mode, "hello")) {
        try runHelloWorldTest(allocator);
    } else if (std.mem.eql(u8, test_mode, "all")) {
        try runAllTests(allocator);
    } else {
        print("❌ Unknown test mode: {s}\n", .{test_mode});
        return;
    }
}

/// 기본 프로그램 실행 테스트
fn runBasicTest(allocator: std.mem.Allocator) !void {
    print("🔧 Running Basic Program Test\n", .{});
    print("=============================\n", .{});

    var executor = ProgramExecutor.init(allocator);
    defer executor.deinit();

    // 시스템 프로그램들 등록
    try executor.registerSystemPrograms();

    print("✅ System programs registered\n", .{});
    executor.printStatus();

    print("✅ Basic test completed successfully!\n", .{});
}

/// 시스템 프로그램 테스트
fn runSystemProgramTest(allocator: std.mem.Allocator) !void {
    print("🏛️ Running System Program Test\n", .{});
    print("===============================\n", .{});

    var executor = ProgramExecutor.init(allocator);
    defer executor.deinit();

    try executor.registerSystemPrograms();

    // 계정 생성 테스트
    print("📝 Testing account creation...\n", .{});
    
    const system_program_id = [_]u8{0} ** 32;
    const from_account = [_]u8{1} ** 32;
    const to_account = [_]u8{2} ** 32;

    var accounts = [_]Instruction.AccountMeta{
        .{ .pubkey = from_account, .is_signer = true, .is_writable = true },
        .{ .pubkey = to_account, .is_signer = false, .is_writable = true },
    };

    const create_data = [_]u8{0}; // Create account command
    const create_instruction = Instruction.init(system_program_id, accounts[0..], create_data[0..]);

    var create_result = try executor.executeInstruction(&create_instruction);
    defer create_result.deinit();

    if (create_result.success) {
        print("✅ Account creation test passed\n", .{});
        for (create_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Account creation test failed\n", .{});
        if (create_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    // 전송 테스트
    print("\n💸 Testing transfer...\n", .{});
    
    const transfer_data = [_]u8{1}; // Transfer command
    const transfer_instruction = Instruction.init(system_program_id, accounts[0..], transfer_data[0..]);

    var transfer_result = try executor.executeInstruction(&transfer_instruction);
    defer transfer_result.deinit();

    if (transfer_result.success) {
        print("✅ Transfer test passed\n", .{});
        for (transfer_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Transfer test failed\n", .{});
        if (transfer_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    print("\n✅ System program test completed!\n", .{});
}

/// 토큰 프로그램 테스트
fn runTokenProgramTest(allocator: std.mem.Allocator) !void {
    print("🪙 Running Token Program Test\n", .{});
    print("=============================\n", .{});

    var executor = ProgramExecutor.init(allocator);
    defer executor.deinit();

    try executor.registerSystemPrograms();

    var token_program_id = [_]u8{0} ** 32;
    token_program_id[0] = 1;

    const mint_account = [_]u8{3} ** 32;
    const token_account = [_]u8{4} ** 32;

    // 토큰 민트 초기화 테스트
    print("🏭 Testing token mint initialization...\n", .{});
    
    var mint_accounts = [_]Instruction.AccountMeta{
        .{ .pubkey = mint_account, .is_signer = true, .is_writable = true },
    };

    const init_mint_data = [_]u8{0}; // Initialize mint command
    const init_mint_instruction = Instruction.init(token_program_id, mint_accounts[0..], init_mint_data[0..]);

    var mint_result = try executor.executeInstruction(&init_mint_instruction);
    defer mint_result.deinit();

    if (mint_result.success) {
        print("✅ Token mint initialization passed\n", .{});
        for (mint_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Token mint initialization failed\n", .{});
        if (mint_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    // 토큰 계정 초기화 테스트
    print("\n🏦 Testing token account initialization...\n", .{});
    
    var account_accounts = [_]Instruction.AccountMeta{
        .{ .pubkey = token_account, .is_signer = true, .is_writable = true },
        .{ .pubkey = mint_account, .is_signer = false, .is_writable = false },
    };

    const init_account_data = [_]u8{1}; // Initialize account command
    const init_account_instruction = Instruction.init(token_program_id, account_accounts[0..], init_account_data[0..]);

    var account_result = try executor.executeInstruction(&init_account_instruction);
    defer account_result.deinit();

    if (account_result.success) {
        print("✅ Token account initialization passed\n", .{});
        for (account_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Token account initialization failed\n", .{});
        if (account_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    // 토큰 발행 테스트
    print("\n💰 Testing token minting...\n", .{});
    
    const mint_to_data = [_]u8{2}; // Mint to command
    const mint_to_instruction = Instruction.init(token_program_id, account_accounts[0..], mint_to_data[0..]);

    var mint_to_result = try executor.executeInstruction(&mint_to_instruction);
    defer mint_to_result.deinit();

    if (mint_to_result.success) {
        print("✅ Token minting passed\n", .{});
        for (mint_to_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Token minting failed\n", .{});
        if (mint_to_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    print("\n✅ Token program test completed!\n", .{});
}

/// Hello World 프로그램 테스트
fn runHelloWorldTest(allocator: std.mem.Allocator) !void {
    print("👋 Running Hello World Program Test\n", .{});
    print("===================================\n", .{});

    var executor = ProgramExecutor.init(allocator);
    defer executor.deinit();

    try executor.registerSystemPrograms();

    var hello_program_id = [_]u8{0} ** 32;
    hello_program_id[0] = 2;

    var accounts = [_]Instruction.AccountMeta{};
    const data = [_]u8{};
    const instruction = Instruction.init(hello_program_id, accounts[0..], data[0..]);

    var result = try executor.executeInstruction(&instruction);
    defer result.deinit();

    if (result.success) {
        print("✅ Hello World program executed successfully!\n", .{});
        print("📄 Program output:\n", .{});
        for (result.logs.items) |log| {
            print("   {s}\n", .{log});
        }
    } else {
        print("❌ Hello World program failed\n", .{});
        if (result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    print("\n✅ Hello World test completed!\n", .{});
}

/// 모든 테스트 실행
fn runAllTests(allocator: std.mem.Allocator) !void {
    print("🎯 Running All Program Tests\n", .{});
    print("============================\n", .{});

    print("\n1️⃣ Basic Test\n", .{});
    print("-------------\n", .{});
    try runBasicTest(allocator);

    print("\n2️⃣ System Program Test\n", .{});
    print("----------------------\n", .{});
    try runSystemProgramTest(allocator);

    print("\n3️⃣ Token Program Test\n", .{});
    print("---------------------\n", .{});
    try runTokenProgramTest(allocator);

    print("\n4️⃣ Hello World Test\n", .{});
    print("-------------------\n", .{});
    try runHelloWorldTest(allocator);

    print("\n🎉 All tests completed successfully!\n", .{});
    print("=====================================\n", .{});
}

/// 성능 벤치마크
fn runPerformanceBenchmark(allocator: std.mem.Allocator) !void {
    print("⚡ Running Performance Benchmark\n", .{});
    print("================================\n", .{});

    var executor = ProgramExecutor.init(allocator);
    defer executor.deinit();

    try executor.registerSystemPrograms();

    const iterations = 1000;
    var hello_program_id = [_]u8{0} ** 32;
    hello_program_id[0] = 2;

    var accounts = [_]Instruction.AccountMeta{};
    const data = [_]u8{};
    const instruction = Instruction.init(hello_program_id, accounts[0..], data[0..]);

    print("🏃 Running {d} program executions...\n", .{iterations});

    const start_time = std.time.milliTimestamp();

    for (0..iterations) |i| {
        var result = try executor.executeInstruction(&instruction);
        result.deinit();

        if ((i + 1) % 100 == 0) {
            print("Progress: {d}/{d}...\n", .{ i + 1, iterations });
        }
    }

    const end_time = std.time.milliTimestamp();
    const duration = end_time - start_time;

    print("\n📊 Benchmark Results\n", .{});
    print("====================\n", .{});
    print("Total executions: {d}\n", .{iterations});
    print("Total time: {d}ms\n", .{duration});
    print("Average time per execution: {d:.2}ms\n", .{@as(f64, @floatFromInt(duration)) / @as(f64, @floatFromInt(iterations))});
    print("Executions per second: {d:.0}\n", .{@as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(duration)) / 1000.0)});
}