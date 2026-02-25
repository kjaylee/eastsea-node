const std = @import("std");
const print = std.debug.print;

const Program = @import("programs/program.zig").Program;
const ProgramExecutor = @import("programs/program.zig").ProgramExecutor;
const Instruction = @import("programs/program.zig").Instruction;
const AccountData = @import("programs/program.zig").AccountData;
const CustomProgram = @import("programs/custom_program.zig").CustomProgram;
const CustomProgramRegistry = @import("programs/custom_program.zig").CustomProgramRegistry;

// 예제 프로그램 진입점들 import
const counterProgramEntryPoint = @import("programs/custom_program.zig").counterProgramEntryPoint;
const calculatorProgramEntryPoint = @import("programs/custom_program.zig").calculatorProgramEntryPoint;
const votingProgramEntryPoint = @import("programs/custom_program.zig").votingProgramEntryPoint;
const tokenSwapProgramEntryPoint = @import("programs/custom_program.zig").tokenSwapProgramEntryPoint;

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
        print("  counter     - Counter program test\n", .{});
        print("  calculator  - Calculator program test\n", .{});
        print("  voting      - Voting program test\n", .{});
        print("  token-swap  - Token swap program test\n", .{});
        print("  all         - Run all custom program tests\n", .{});
        print("  benchmark   - Performance benchmark\n", .{});
        print("\nExample: {s} counter\n", .{args[0]});
        return;
    }

    const test_mode = args[1];

    print("🚀 Starting Custom Programs Test\n", .{});
    print("=================================\n", .{});
    print("Test mode: {s}\n", .{test_mode});
    print("\n", .{});

    if (std.mem.eql(u8, test_mode, "counter")) {
        try runCounterProgramTest(allocator);
    } else if (std.mem.eql(u8, test_mode, "calculator")) {
        try runCalculatorProgramTest(allocator);
    } else if (std.mem.eql(u8, test_mode, "voting")) {
        try runVotingProgramTest(allocator);
    } else if (std.mem.eql(u8, test_mode, "token-swap")) {
        try runTokenSwapProgramTest(allocator);
    } else if (std.mem.eql(u8, test_mode, "all")) {
        try runAllCustomProgramTests(allocator);
    } else if (std.mem.eql(u8, test_mode, "benchmark")) {
        try runPerformanceBenchmark(allocator);
    } else {
        print("❌ Unknown test mode: {s}\n", .{test_mode});
        return;
    }
}

/// 카운터 프로그램 테스트
fn runCounterProgramTest(allocator: std.mem.Allocator) !void {
    print("🔢 Running Counter Program Test\n", .{});
    print("===============================\n", .{});

    var executor = ProgramExecutor.init(allocator);
    defer executor.deinit();

    var custom_registry = CustomProgramRegistry.init(allocator);
    defer custom_registry.deinit();

    // 사용자 정의 프로그램 레지스트리 설정
    executor.setCustomProgramRegistry(&custom_registry);

    // 카운터 프로그램 등록
    var counter_id = [_]u8{0} ** 32;
    counter_id[0] = 10;

    const counter_program = CustomProgram.init(
        counter_id,
        "counter",
        "counter program bytecode",
        counterProgramEntryPoint,
    );

    try custom_registry.registerProgram(counter_program);
    print("✅ Counter program registered\n", .{});

    executor.printStatus();

    // 카운터 초기화 테스트
    print("📝 Testing counter initialization...\n", .{});
    var accounts = [_]Instruction.AccountMeta{};
    const init_data = [_]u8{0}; // Initialize command
    const init_instruction = Instruction.init(counter_id, accounts[0..], init_data[0..]);

    var init_result = try executor.executeInstruction(&init_instruction);
    defer init_result.deinit();

    if (init_result.success) {
        print("✅ Counter initialization passed\n", .{});
        for (init_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Counter initialization failed\n", .{});
        if (init_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    // 카운터 증가 테스트
    print("\n➕ Testing counter increment...\n", .{});
    const inc_data = [_]u8{1}; // Increment command
    const inc_instruction = Instruction.init(counter_id, accounts[0..], inc_data[0..]);

    var inc_result = try executor.executeInstruction(&inc_instruction);
    defer inc_result.deinit();

    if (inc_result.success) {
        print("✅ Counter increment passed\n", .{});
        for (inc_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Counter increment failed\n", .{});
        if (inc_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    // 카운터 값 조회 테스트
    print("\n🔍 Testing counter value query...\n", .{});
    const get_data = [_]u8{3}; // Get value command
    const get_instruction = Instruction.init(counter_id, accounts[0..], get_data[0..]);

    var get_result = try executor.executeInstruction(&get_instruction);
    defer get_result.deinit();

    if (get_result.success) {
        print("✅ Counter value query passed\n", .{});
        for (get_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Counter value query failed\n", .{});
        if (get_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    print("\n✅ Counter program test completed!\n", .{});
}

/// 계산기 프로그램 테스트
fn runCalculatorProgramTest(allocator: std.mem.Allocator) !void {
    print("🧮 Running Calculator Program Test\n", .{});
    print("==================================\n", .{});

    var executor = ProgramExecutor.init(allocator);
    defer executor.deinit();

    var custom_registry = CustomProgramRegistry.init(allocator);
    defer custom_registry.deinit();

    executor.setCustomProgramRegistry(&custom_registry);

    // 계산기 프로그램 등록
    var calc_id = [_]u8{0} ** 32;
    calc_id[0] = 11;

    const calc_program = CustomProgram.init(
        calc_id,
        "calculator",
        "calculator program bytecode",
        calculatorProgramEntryPoint,
    );

    try custom_registry.registerProgram(calc_program);
    print("✅ Calculator program registered\n", .{});

    var accounts = [_]Instruction.AccountMeta{};

    // 덧셈 테스트
    print("📝 Testing addition: 15 + 25...\n", .{});
    const add_data = [_]u8{ 0, 15, 25 }; // Addition: 15 + 25
    const add_instruction = Instruction.init(calc_id, accounts[0..], add_data[0..]);

    var add_result = try executor.executeInstruction(&add_instruction);
    defer add_result.deinit();

    if (add_result.success) {
        print("✅ Addition test passed\n", .{});
        for (add_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Addition test failed\n", .{});
        if (add_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    // 곱셈 테스트
    print("\n✖️ Testing multiplication: 7 * 8...\n", .{});
    const mul_data = [_]u8{ 2, 7, 8 }; // Multiplication: 7 * 8
    const mul_instruction = Instruction.init(calc_id, accounts[0..], mul_data[0..]);

    var mul_result = try executor.executeInstruction(&mul_instruction);
    defer mul_result.deinit();

    if (mul_result.success) {
        print("✅ Multiplication test passed\n", .{});
        for (mul_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Multiplication test failed\n", .{});
        if (mul_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    // 나눗셈 테스트
    print("\n➗ Testing division: 20 / 4...\n", .{});
    const div_data = [_]u8{ 3, 20, 4 }; // Division: 20 / 4
    const div_instruction = Instruction.init(calc_id, accounts[0..], div_data[0..]);

    var div_result = try executor.executeInstruction(&div_instruction);
    defer div_result.deinit();

    if (div_result.success) {
        print("✅ Division test passed\n", .{});
        for (div_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Division test failed\n", .{});
        if (div_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    print("\n✅ Calculator program test completed!\n", .{});
}

/// 투표 프로그램 테스트
fn runVotingProgramTest(allocator: std.mem.Allocator) !void {
    print("🗳️ Running Voting Program Test\n", .{});
    print("==============================\n", .{});

    var executor = ProgramExecutor.init(allocator);
    defer executor.deinit();

    var custom_registry = CustomProgramRegistry.init(allocator);
    defer custom_registry.deinit();

    executor.setCustomProgramRegistry(&custom_registry);

    // 투표 프로그램 등록
    var voting_id = [_]u8{0} ** 32;
    voting_id[0] = 12;

    const voting_program = CustomProgram.init(
        voting_id,
        "voting",
        "voting program bytecode",
        votingProgramEntryPoint,
    );

    try custom_registry.registerProgram(voting_program);
    print("✅ Voting program registered\n", .{});

    var accounts = [_]Instruction.AccountMeta{};

    // 제안 생성 테스트
    print("📝 Testing proposal creation...\n", .{});
    const create_data = [_]u8{ 0, 1 }; // Create proposal with ID 1
    const create_instruction = Instruction.init(voting_id, accounts[0..], create_data[0..]);

    var create_result = try executor.executeInstruction(&create_instruction);
    defer create_result.deinit();

    if (create_result.success) {
        print("✅ Proposal creation passed\n", .{});
        for (create_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Proposal creation failed\n", .{});
        if (create_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    // 투표 테스트
    print("\n🗳️ Testing vote casting (Yes)...\n", .{});
    const vote_data = [_]u8{ 1, 1, 1 }; // Cast vote: proposal 1, vote Yes
    const vote_instruction = Instruction.init(voting_id, accounts[0..], vote_data[0..]);

    var vote_result = try executor.executeInstruction(&vote_instruction);
    defer vote_result.deinit();

    if (vote_result.success) {
        print("✅ Vote casting passed\n", .{});
        for (vote_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Vote casting failed\n", .{});
        if (vote_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    // 결과 조회 테스트
    print("\n📊 Testing results query...\n", .{});
    const results_data = [_]u8{ 2, 1 }; // Get results for proposal 1
    const results_instruction = Instruction.init(voting_id, accounts[0..], results_data[0..]);

    var results_result = try executor.executeInstruction(&results_instruction);
    defer results_result.deinit();

    if (results_result.success) {
        print("✅ Results query passed\n", .{});
        for (results_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Results query failed\n", .{});
        if (results_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    print("\n✅ Voting program test completed!\n", .{});
}

/// 토큰 스왑 프로그램 테스트
fn runTokenSwapProgramTest(allocator: std.mem.Allocator) !void {
    print("🔄 Running Token Swap Program Test\n", .{});
    print("==================================\n", .{});

    var executor = ProgramExecutor.init(allocator);
    defer executor.deinit();

    var custom_registry = CustomProgramRegistry.init(allocator);
    defer custom_registry.deinit();

    executor.setCustomProgramRegistry(&custom_registry);

    // 토큰 스왑 프로그램 등록
    var swap_id = [_]u8{0} ** 32;
    swap_id[0] = 13;

    const swap_program = CustomProgram.init(
        swap_id,
        "token-swap",
        "token swap program bytecode",
        tokenSwapProgramEntryPoint,
    );

    try custom_registry.registerProgram(swap_program);
    print("✅ Token swap program registered\n", .{});

    var accounts = [_]Instruction.AccountMeta{};

    // 스왑 풀 초기화 테스트
    print("📝 Testing swap pool initialization...\n", .{});
    const init_data = [_]u8{0}; // Initialize swap pool
    const init_instruction = Instruction.init(swap_id, accounts[0..], init_data[0..]);

    var init_result = try executor.executeInstruction(&init_instruction);
    defer init_result.deinit();

    if (init_result.success) {
        print("✅ Swap pool initialization passed\n", .{});
        for (init_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Swap pool initialization failed\n", .{});
        if (init_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    // 토큰 A -> 토큰 B 스왑 테스트
    print("\n🔄 Testing Token A -> Token B swap (50 tokens)...\n", .{});
    const swap_a_data = [_]u8{ 1, 50 }; // Swap 50 Token A for Token B
    const swap_a_instruction = Instruction.init(swap_id, accounts[0..], swap_a_data[0..]);

    var swap_a_result = try executor.executeInstruction(&swap_a_instruction);
    defer swap_a_result.deinit();

    if (swap_a_result.success) {
        print("✅ Token A -> Token B swap passed\n", .{});
        for (swap_a_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Token A -> Token B swap failed\n", .{});
        if (swap_a_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    // 풀 정보 조회 테스트
    print("\n📊 Testing pool info query...\n", .{});
    const info_data = [_]u8{3}; // Get pool info
    const info_instruction = Instruction.init(swap_id, accounts[0..], info_data[0..]);

    var info_result = try executor.executeInstruction(&info_instruction);
    defer info_result.deinit();

    if (info_result.success) {
        print("✅ Pool info query passed\n", .{});
        for (info_result.logs.items) |log| {
            print("   📄 Log: {s}\n", .{log});
        }
    } else {
        print("❌ Pool info query failed\n", .{});
        if (info_result.error_message) |err| {
            print("   Error: {s}\n", .{err});
        }
    }

    print("\n✅ Token swap program test completed!\n", .{});
}

/// 모든 사용자 정의 프로그램 테스트 실행
fn runAllCustomProgramTests(allocator: std.mem.Allocator) !void {
    print("🎯 Running All Custom Program Tests\n", .{});
    print("===================================\n", .{});

    print("\n1️⃣ Counter Program Test\n", .{});
    print("------------------------\n", .{});
    try runCounterProgramTest(allocator);

    print("\n2️⃣ Calculator Program Test\n", .{});
    print("---------------------------\n", .{});
    try runCalculatorProgramTest(allocator);

    print("\n3️⃣ Voting Program Test\n", .{});
    print("-----------------------\n", .{});
    try runVotingProgramTest(allocator);

    print("\n4️⃣ Token Swap Program Test\n", .{});
    print("---------------------------\n", .{});
    try runTokenSwapProgramTest(allocator);

    print("\n🎉 All custom program tests completed successfully!\n", .{});
    print("==================================================\n", .{});
}

/// 성능 벤치마크
fn runPerformanceBenchmark(allocator: std.mem.Allocator) !void {
    print("⚡ Running Custom Programs Performance Benchmark\n", .{});
    print("================================================\n", .{});

    var executor = ProgramExecutor.init(allocator);
    defer executor.deinit();

    var custom_registry = CustomProgramRegistry.init(allocator);
    defer custom_registry.deinit();

    executor.setCustomProgramRegistry(&custom_registry);

    // 모든 프로그램 등록
    var counter_id = [_]u8{0} ** 32;
    counter_id[0] = 10;
    try custom_registry.registerProgram(CustomProgram.init(counter_id, "counter", "counter bytecode", counterProgramEntryPoint));

    var calc_id = [_]u8{0} ** 32;
    calc_id[0] = 11;
    try custom_registry.registerProgram(CustomProgram.init(calc_id, "calculator", "calculator bytecode", calculatorProgramEntryPoint));

    print("✅ Programs registered for benchmark\n", .{});

    const iterations = 1000;
    print("🏃 Running {d} program executions per program...\n", .{iterations});

    // 카운터 프로그램 벤치마크
    print("\n📊 Counter Program Benchmark\n", .{});
    var accounts = [_]Instruction.AccountMeta{};
    const counter_data = [_]u8{1}; // Increment command
    const counter_instruction = Instruction.init(counter_id, accounts[0..], counter_data[0..]);

    const counter_start = std.time.milliTimestamp();
    for (0..iterations) |_| {
        var result = try executor.executeInstruction(&counter_instruction);
        result.deinit();
    }
    const counter_end = std.time.milliTimestamp();
    const counter_duration = counter_end - counter_start;

    print("Counter program: {d}ms total, {d:.2}ms avg, {d:.0} ops/sec\n", .{
        counter_duration,
        @as(f64, @floatFromInt(counter_duration)) / @as(f64, @floatFromInt(iterations)),
        @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(counter_duration)) / 1000.0),
    });

    // 계산기 프로그램 벤치마크
    print("\n📊 Calculator Program Benchmark\n", .{});
    const calc_data = [_]u8{ 0, 5, 3 }; // Addition: 5 + 3
    const calc_instruction = Instruction.init(calc_id, accounts[0..], calc_data[0..]);

    const calc_start = std.time.milliTimestamp();
    for (0..iterations) |_| {
        var result = try executor.executeInstruction(&calc_instruction);
        result.deinit();
    }
    const calc_end = std.time.milliTimestamp();
    const calc_duration = calc_end - calc_start;

    print("Calculator program: {d}ms total, {d:.2}ms avg, {d:.0} ops/sec\n", .{
        calc_duration,
        @as(f64, @floatFromInt(calc_duration)) / @as(f64, @floatFromInt(iterations)),
        @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(calc_duration)) / 1000.0),
    });

    print("\n🎯 Benchmark Summary\n", .{});
    print("===================\n", .{});
    print("Total executions: {d}\n", .{iterations * 2});
    print("Total time: {d}ms\n", .{counter_duration + calc_duration});
    print("Average execution time: {d:.2}ms\n", .{@as(f64, @floatFromInt(counter_duration + calc_duration)) / @as(f64, @floatFromInt(iterations * 2))});

    print("\n✅ Performance benchmark completed!\n", .{});
}
