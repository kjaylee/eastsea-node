const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "eastsea",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    // Production executable
    const prod_exe = b.addExecutable(.{
        .name = "eastsea-production",
        .root_source_file = b.path("src/main_production.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(prod_exe);

    // Production run command
    const prod_run_cmd = b.addRunArtifact(prod_exe);
    prod_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        prod_run_cmd.addArgs(args);
    }

    const prod_run_step = b.step("run-prod", "Run the production node");
    prod_run_step.dependOn(&prod_run_cmd.step);
    // P2P Test executable
    const p2p_test_exe = b.addExecutable(.{
        .name = "p2p-test",
        .root_source_file = b.path("src/p2p_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(p2p_test_exe);

    // P2P Test run command
    const p2p_test_run_cmd = b.addRunArtifact(p2p_test_exe);
    p2p_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        p2p_test_run_cmd.addArgs(args);
    }

    const p2p_test_run_step = b.step("run-p2p", "Run the P2P network test");
    p2p_test_run_step.dependOn(&p2p_test_run_cmd.step);

    // DHT Test executable
    const dht_test_exe = b.addExecutable(.{
        .name = "dht-test",
        .root_source_file = b.path("src/dht_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(dht_test_exe);

    // DHT Test run command
    const dht_test_run_cmd = b.addRunArtifact(dht_test_exe);
    dht_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        dht_test_run_cmd.addArgs(args);
    }

    const dht_test_run_step = b.step("run-dht", "Run the DHT test");
    dht_test_run_step.dependOn(&dht_test_run_cmd.step);

    // Bootstrap Test executable
    const bootstrap_test_exe = b.addExecutable(.{
        .name = "bootstrap-test",
        .root_source_file = b.path("src/bootstrap_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(bootstrap_test_exe);

    // Bootstrap Test run command
    const bootstrap_test_run_cmd = b.addRunArtifact(bootstrap_test_exe);
    bootstrap_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        bootstrap_test_run_cmd.addArgs(args);
    }

    const bootstrap_test_run_step = b.step("run-bootstrap", "Run the Bootstrap test");
    bootstrap_test_run_step.dependOn(&bootstrap_test_run_cmd.step);
    // mDNS Test executable
    const mdns_test_exe = b.addExecutable(.{
        .name = "mdns-test",
        .root_source_file = b.path("src/mdns_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(mdns_test_exe);

    // mDNS Test run command
    const mdns_test_run_cmd = b.addRunArtifact(mdns_test_exe);
    mdns_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        mdns_test_run_cmd.addArgs(args);
    }

    const mdns_test_run_step = b.step("run-mdns", "Run the mDNS test");
    mdns_test_run_step.dependOn(&mdns_test_run_cmd.step);


    // Tests
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Library for reusable components
    const lib = b.addStaticLibrary(.{
        .name = "eastsea",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);
}