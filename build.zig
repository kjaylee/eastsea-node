const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Helper: create an executable with Zig 0.15 API
    const addExe = struct {
        fn call(builder: *std.Build, name: []const u8, root_path: []const u8, tgt: std.Build.ResolvedTarget, opt: std.builtin.OptimizeMode) *std.Build.Step.Compile {
            return builder.addExecutable(.{
                .name = name,
                .root_module = builder.createModule(.{
                    .root_source_file = builder.path(root_path),
                    .target = tgt,
                    .optimize = opt,
                }),
            });
        }
    }.call;

    // Helper: create exe + install + run step
    const addRunTarget = struct {
        fn call(builder: *std.Build, name: []const u8, root_path: []const u8, step_name: []const u8, step_desc: []const u8, tgt: std.Build.ResolvedTarget, opt: std.builtin.OptimizeMode) void {
            const exe = builder.addExecutable(.{
                .name = name,
                .root_module = builder.createModule(.{
                    .root_source_file = builder.path(root_path),
                    .target = tgt,
                    .optimize = opt,
                }),
            });
            builder.installArtifact(exe);
            const run_cmd = builder.addRunArtifact(exe);
            run_cmd.step.dependOn(builder.getInstallStep());
            if (builder.args) |args| {
                run_cmd.addArgs(args);
            }
            const run_step = builder.step(step_name, step_desc);
            run_step.dependOn(&run_cmd.step);
        }
    }.call;

    // Main executable
    const exe = addExe(b, "eastsea", "src/main.zig", target, optimize);
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Production executable
    addRunTarget(b, "eastsea-production", "src/main_production.zig", "run-prod", "Run the production node", target, optimize);

    // Network test executables
    addRunTarget(b, "p2p-test", "src/p2p_test.zig", "run-p2p", "Run the P2P network test", target, optimize);
    addRunTarget(b, "dht-test", "src/dht_test.zig", "run-dht", "Run the DHT test", target, optimize);
    addRunTarget(b, "bootstrap-test", "src/bootstrap_test.zig", "run-bootstrap", "Run the Bootstrap test", target, optimize);
    addRunTarget(b, "mdns-test", "src/mdns_test.zig", "run-mdns", "Run the mDNS test", target, optimize);
    addRunTarget(b, "auto-discovery-test", "src/auto_discovery_test.zig", "run-auto-discovery", "Run the Auto Discovery test", target, optimize);
    addRunTarget(b, "upnp-test", "src/upnp_test.zig", "run-upnp", "Run the UPnP test", target, optimize);
    addRunTarget(b, "stun-test", "src/stun_test_simple.zig", "run-stun", "Run the STUN/NAT Traversal test", target, optimize);
    addRunTarget(b, "port-scanner-test", "src/port_scanner_test.zig", "run-port-scan", "Run the Port Scanner test", target, optimize);
    addRunTarget(b, "broadcast-test", "src/broadcast_test.zig", "run-broadcast", "Run the Broadcast test", target, optimize);
    addRunTarget(b, "tracker-test", "src/tracker_test.zig", "run-tracker", "Run the Tracker server/client test", target, optimize);

    // Smart Contract test executables
    addRunTarget(b, "programs-test", "src/programs_test.zig", "run-programs", "Run the Smart Contracts (Programs) test", target, optimize);
    addRunTarget(b, "custom-programs-test", "src/custom_programs_test.zig", "run-custom-programs", "Run the Custom Programs test", target, optimize);

    // Phase 9 Testing Framework
    addRunTarget(b, "phase9-test", "src/phase9_test.zig", "run-phase9", "Run Phase 9 comprehensive testing framework", target, optimize);

    // EAS (Eastsea Attestation Service) tests
    addRunTarget(b, "eas-test", "src/eas_test.zig", "run-eas", "Run Eastsea Attestation Service test", target, optimize);
    addRunTarget(b, "eas-use-cases-test", "src/eas_use_cases_test.zig", "run-eas-use-cases", "Run Eastsea Attestation Service use cases test", target, optimize);

    // QUIC Protocol Test (Phase 13) - previously missing run command
    addRunTarget(b, "quic-test", "src/quic_test.zig", "run-quic", "Run QUIC protocol test", target, optimize);

    // Web Server Test - previously commented out
    addRunTarget(b, "web-server-test", "src/web_server_test.zig", "run-web-server", "Run the Web Server test", target, optimize);
}