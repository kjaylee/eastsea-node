const std = @import("std");
const print = std.debug.print;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

/// 성능 벤치마킹 프레임워크
/// 블록체인 핵심 기능들의 성능을 측정하고 분석
pub const BenchmarkFramework = struct {
    allocator: Allocator,
    results: ArrayList(BenchmarkResult),
    
    const Self = @This();
    
    pub const BenchmarkResult = struct {
        name: []const u8,
        iterations: u32,
        total_time_ns: u64,
        min_time_ns: u64,
        max_time_ns: u64,
        avg_time_ns: u64,
        memory_used: usize,
        operations_per_second: f64,
        
        pub fn format(self: BenchmarkResult, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            try writer.print("Benchmark: {s}\n", .{self.name});
            try writer.print("  Iterations: {}\n", .{self.iterations});
            try writer.print("  Total time: {d:.2}ms\n", .{@as(f64, @floatFromInt(self.total_time_ns)) / 1_000_000.0});
            try writer.print("  Average time: {d:.3}ms\n", .{@as(f64, @floatFromInt(self.avg_time_ns)) / 1_000_000.0});
            try writer.print("  Min time: {d:.3}ms\n", .{@as(f64, @floatFromInt(self.min_time_ns)) / 1_000_000.0});
            try writer.print("  Max time: {d:.3}ms\n", .{@as(f64, @floatFromInt(self.max_time_ns)) / 1_000_000.0});
            try writer.print("  Memory used: {d:.2}MB\n", .{@as(f64, @floatFromInt(self.memory_used)) / 1_048_576.0});
            try writer.print("  Operations/sec: {d:.0}\n", .{self.operations_per_second});
        }
    };
    
    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .results = ArrayList(BenchmarkResult).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        for (self.results.items) |result| {
            self.allocator.free(result.name);
        }
        self.results.deinit();
    }
    
    /// 벤치마크 실행
    pub fn benchmark(self: *Self, name: []const u8, iterations: u32, func: anytype, args: anytype) !void {
        print("🔬 Running benchmark: {s} ({} iterations)\n", .{ name, iterations });
        
        var min_time: u64 = std.math.maxInt(u64);
        var max_time: u64 = 0;
        var total_time: u64 = 0;
        
        const start_memory = self.getCurrentMemoryUsage();
        
        // 워밍업 (JIT 최적화 등을 위해)
        @call(.auto, func, args);
        
        for (0..iterations) |_| {
            const start_time = std.time.nanoTimestamp();
            
            // 함수 실행
            @call(.auto, func, args);
            
            const end_time = std.time.nanoTimestamp();
            const duration = @as(u64, @intCast(end_time - start_time));
            
            total_time += duration;
            min_time = @min(min_time, duration);
            max_time = @max(max_time, duration);
        }
        
        const end_memory = self.getCurrentMemoryUsage();
        const memory_used = if (end_memory > start_memory) end_memory - start_memory else 0;
        
        const avg_time = total_time / iterations;
        const ops_per_second = if (avg_time > 0) 1_000_000_000.0 / @as(f64, @floatFromInt(avg_time)) else 0.0;
        
        const result = BenchmarkResult{
            .name = try self.allocator.dupe(u8, name),
            .iterations = iterations,
            .total_time_ns = total_time,
            .min_time_ns = min_time,
            .max_time_ns = max_time,
            .avg_time_ns = avg_time,
            .memory_used = memory_used,
            .operations_per_second = ops_per_second,
        };
        
        try self.results.append(result);
        print("✅ Benchmark completed: {}\n\n", .{result});
    }
    
    /// 메모리 사용량 추정 (간단한 구현)
    fn getCurrentMemoryUsage(self: *Self) usize {
        _ = self;
        // 실제로는 프로세스 메모리 사용량을 조회해야 하지만,
        // 여기서는 간단히 처리
        return 0;
    }
    
    /// 결과 요약 출력
    pub fn printSummary(self: *Self) void {
        print("📊 Benchmark Summary\n", .{});
        print("==================\n", .{});
        
        if (self.results.items.len == 0) {
            print("No benchmarks run.\n", .{});
            return;
        }
        
        for (self.results.items) |result| {
            print("{}\n", .{result});
        }
        
        // 전체 통계
        var total_ops: f64 = 0;
        var fastest_ops: f64 = 0;
        var slowest_ops: f64 = std.math.inf(f64);
        var fastest_name: []const u8 = "";
        var slowest_name: []const u8 = "";
        
        for (self.results.items) |result| {
            total_ops += result.operations_per_second;
            if (result.operations_per_second > fastest_ops) {
                fastest_ops = result.operations_per_second;
                fastest_name = result.name;
            }
            if (result.operations_per_second < slowest_ops) {
                slowest_ops = result.operations_per_second;
                slowest_name = result.name;
            }
        }
        
        print("🏆 Performance Summary:\n", .{});
        print("  Fastest: {s} ({d:.0} ops/sec)\n", .{ fastest_name, fastest_ops });
        print("  Slowest: {s} ({d:.0} ops/sec)\n", .{ slowest_name, slowest_ops });
        print("  Average: {d:.0} ops/sec\n", .{total_ops / @as(f64, @floatFromInt(self.results.items.len))});
    }
    
    /// CSV 형식으로 결과 저장
    pub fn exportToCSV(self: *Self, filename: []const u8) !void {
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        
        const writer = file.writer();
        
        // 헤더
        try writer.print("Name,Iterations,TotalTime(ns),AvgTime(ns),MinTime(ns),MaxTime(ns),Memory(bytes),OpsPerSec\n", .{});
        
        // 데이터
        for (self.results.items) |result| {
            try writer.print("{s},{},{},{},{},{},{},{d:.2}\n", .{
                result.name,
                result.iterations,
                result.total_time_ns,
                result.avg_time_ns,
                result.min_time_ns,
                result.max_time_ns,
                result.memory_used,
                result.operations_per_second,
            });
        }
        
        print("📄 Benchmark results exported to: {s}\n", .{filename});
    }
};

/// 부하 테스트 프레임워크
pub const LoadTestFramework = struct {
    allocator: Allocator,
    concurrent_users: u32,
    test_duration_seconds: u32,
    ramp_up_seconds: u32,
    
    const Self = @This();
    
    pub const LoadTestResult = struct {
        total_requests: u64,
        successful_requests: u64,
        failed_requests: u64,
        avg_response_time_ms: f64,
        max_response_time_ms: f64,
        min_response_time_ms: f64,
        requests_per_second: f64,
        error_rate: f64,
    };
    
    pub fn init(allocator: Allocator, concurrent_users: u32, test_duration_seconds: u32, ramp_up_seconds: u32) Self {
        return Self{
            .allocator = allocator,
            .concurrent_users = concurrent_users,
            .test_duration_seconds = test_duration_seconds,
            .ramp_up_seconds = ramp_up_seconds,
        };
    }
    
    /// 부하 테스트 실행
    pub fn runLoadTest(self: *Self, test_name: []const u8, target_func: anytype, args: anytype) !LoadTestResult {
        print("🚀 Starting load test: {s}\n", .{test_name});
        print("  Concurrent users: {}\n", .{self.concurrent_users});
        print("  Test duration: {}s\n", .{self.test_duration_seconds});
        print("  Ramp-up time: {}s\n", .{self.ramp_up_seconds});
        
        var total_requests: u64 = 0;
        var successful_requests: u64 = 0;
        var failed_requests: u64 = 0;
        var total_response_time: u64 = 0;
        var max_response_time: u64 = 0;
        var min_response_time: u64 = std.math.maxInt(u64);
        
        const start_time = std.time.timestamp();
        const end_time = start_time + self.test_duration_seconds;
        
        // 간단한 부하 테스트 시뮬레이션
        while (std.time.timestamp() < end_time) {
            for (0..self.concurrent_users) |_| {
                const request_start = std.time.nanoTimestamp();
                
                const success = blk: {
                    _ = @call(.auto, target_func, args) catch {
                        break :blk false;
                    };
                    break :blk true;
                };
                
                const request_end = std.time.nanoTimestamp();
                const response_time = @as(u64, @intCast(request_end - request_start));
                
                total_requests += 1;
                total_response_time += response_time;
                max_response_time = @max(max_response_time, response_time);
                min_response_time = @min(min_response_time, response_time);
                
                if (success) {
                    successful_requests += 1;
                } else {
                    failed_requests += 1;
                }
            }
            
            // 짧은 대기 (CPU 과부하 방지)
            std.time.sleep(10 * std.time.ns_per_ms);
        }
        
        const actual_duration = std.time.timestamp() - start_time;
        const avg_response_time_ms = if (total_requests > 0) 
            @as(f64, @floatFromInt(total_response_time)) / @as(f64, @floatFromInt(total_requests)) / 1_000_000.0 
            else 0.0;
        
        const result = LoadTestResult{
            .total_requests = total_requests,
            .successful_requests = successful_requests,
            .failed_requests = failed_requests,
            .avg_response_time_ms = avg_response_time_ms,
            .max_response_time_ms = @as(f64, @floatFromInt(max_response_time)) / 1_000_000.0,
            .min_response_time_ms = @as(f64, @floatFromInt(min_response_time)) / 1_000_000.0,
            .requests_per_second = if (actual_duration > 0) @as(f64, @floatFromInt(total_requests)) / @as(f64, @floatFromInt(actual_duration)) else 0.0,
            .error_rate = if (total_requests > 0) @as(f64, @floatFromInt(failed_requests)) / @as(f64, @floatFromInt(total_requests)) * 100.0 else 0.0,
        };
        
        print("✅ Load test completed: {s}\n", .{test_name});
        print("  Total requests: {}\n", .{result.total_requests});
        print("  Successful: {} ({d:.1}%)\n", .{ result.successful_requests, 100.0 - result.error_rate });
        print("  Failed: {} ({d:.1}%)\n", .{ result.failed_requests, result.error_rate });
        print("  Avg response time: {d:.2}ms\n", .{result.avg_response_time_ms});
        print("  Requests/sec: {d:.1}\n", .{result.requests_per_second});
        
        return result;
    }
};

// 테스트 함수들
test "BenchmarkFramework basic functionality" {
    const allocator = std.testing.allocator;
    
    var benchmark = BenchmarkFramework.init(allocator);
    defer benchmark.deinit();
    
    // 간단한 테스트 함수
    const testFunc = struct {
        fn run() void {
            var sum: u64 = 0;
            for (0..1000) |i| {
                sum += i;
            }
        }
    }.run;
    
    try benchmark.benchmark("Simple Loop", 100, testFunc, .{});
    
    try std.testing.expect(benchmark.results.items.len == 1);
    try std.testing.expect(benchmark.results.items[0].iterations == 100);
}