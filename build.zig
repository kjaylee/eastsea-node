const std = @import("std");

fn createAppModule(
    b: *std.Build,
    root_file: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path(root_file),
        .target = target,
        .optimize = optimize,
    });
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "eastsea",
        .root_module = createAppModule(b, "src/main.zig", target, optimize),
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
        .root_module = createAppModule(b, "src/main_production.zig", target, optimize),
    });

    b.installArtifact(prod_exe);

    const prod_run_cmd = b.addRunArtifact(prod_exe);
    prod_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        prod_run_cmd.addArgs(args);
    }
    const prod_run_step = b.step("run-prod", "Run the production node");
    prod_run_step.dependOn(&prod_run_cmd.step);

    // Helper inline function for test executables
    const test_targets = .{
        .{ "p2p-test", "src/p2p_test.zig", "run-p2p", "Run the P2P network test" },
        .{ "dht-test", "src/dht_test.zig", "run-dht", "Run the DHT test" },
        .{ "bootstrap-test", "src/bootstrap_test.zig", "run-bootstrap", "Run the Bootstrap test" },
        .{ "mdns-test", "src/mdns_test.zig", "run-mdns", "Run the mDNS test" },
        .{ "auto-discovery-test", "src/auto_discovery_test.zig", "run-auto-discovery", "Run the Auto Discovery test" },
        .{ "upnp-test", "src/upnp_test.zig", "run-upnp", "Run the UPnP test" },
        .{ "stun-test", "src/stun_test_simple.zig", "run-stun", "Run the STUN/NAT Traversal test" },
        .{ "port-scanner-test", "src/port_scanner_test.zig", "run-port-scan", "Run the Port Scanner test" },
        .{ "broadcast-test", "src/broadcast_test.zig", "run-broadcast", "Run the Broadcast test" },
        .{ "tracker-test", "src/tracker_test.zig", "run-tracker", "Run the Tracker server/client test" },
        .{ "programs-test", "src/programs_test.zig", "run-programs", "Run the Smart Contracts (Programs) test" },
        .{ "custom-programs-test", "src/custom_programs_test.zig", "run-custom-programs", "Run the Custom Programs test" },
        .{ "phase9-test", "src/phase9_test.zig", "run-phase9", "Run Phase 9 comprehensive testing framework" },
        .{ "eas-test", "src/eas_test.zig", "run-eas", "Run Eastsea Attestation Service test" },
        .{ "eas-use-cases-test", "src/eas_use_cases_test.zig", "run-eas-use-cases", "Run Eastsea Attestation Service use cases test" },
        .{ "quic-test", "src/quic_test.zig", "run-quic", "Run QUIC protocol test" },
    };

    inline for (test_targets) |t| {
        const test_exe = b.addExecutable(.{
            .name = t[0],
            .root_module = createAppModule(b, t[1], target, optimize),
        });
        b.installArtifact(test_exe);

        const test_run_cmd = b.addRunArtifact(test_exe);
        test_run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            test_run_cmd.addArgs(args);
        }
        const test_run_step = b.step(t[2], t[3]);
        test_run_step.dependOn(&test_run_cmd.step);
    }

    // Unit tests (main)
    const unit_tests = b.addTest(.{
        .root_module = createAppModule(b, "src/main.zig", target, optimize),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // REQ module unit tests
    const module_tests = .{
        "src/onboarding.zig",
        "src/boot_check.zig",
        "src/storage_init.zig",
        "src/auth.zig",
        "src/tls_config.zig",
        "src/rpc_validator.zig",
        "src/updater.zig",
        "src/update_manager.zig",
        "src/persistence.zig",
        "src/rbac.zig",
        "src/diagnostics.zig",
        "src/monitoring.zig",
        "src/cluster.zig",
        "src/upnp.zig",
        "src/vm.zig",
    };

    inline for (module_tests) |src| {
        const mod_test = b.addTest(.{
            .root_module = createAppModule(b, src, target, optimize),
        });
        const run_mod_test = b.addRunArtifact(mod_test);
        test_step.dependOn(&run_mod_test.step);
    }
}
