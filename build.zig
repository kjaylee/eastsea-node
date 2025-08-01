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

    // Auto Discovery Test executable
    const auto_discovery_test_exe = b.addExecutable(.{
        .name = "auto-discovery-test",
        .root_source_file = b.path("src/auto_discovery_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(auto_discovery_test_exe);

    // Auto Discovery Test run command
    const auto_discovery_test_run_cmd = b.addRunArtifact(auto_discovery_test_exe);
    auto_discovery_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        auto_discovery_test_run_cmd.addArgs(args);
    }

    const auto_discovery_test_run_step = b.step("run-auto-discovery", "Run the Auto Discovery test");
    auto_discovery_test_run_step.dependOn(&auto_discovery_test_run_cmd.step);

    // UPnP Test executable
    const upnp_test_exe = b.addExecutable(.{
        .name = "upnp-test",
        .root_source_file = b.path("src/upnp_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(upnp_test_exe);

    // UPnP Test run command
    const upnp_test_run_cmd = b.addRunArtifact(upnp_test_exe);
    upnp_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        upnp_test_run_cmd.addArgs(args);
    }

    const upnp_test_run_step = b.step("run-upnp", "Run the UPnP test");
    upnp_test_run_step.dependOn(&upnp_test_run_cmd.step);

    // Programs/Smart Contracts Test executable
    const programs_test_exe = b.addExecutable(.{
        .name = "programs-test",
        .root_source_file = b.path("src/programs_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(programs_test_exe);

    // Programs Test run command
    const programs_test_run_cmd = b.addRunArtifact(programs_test_exe);
    programs_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        programs_test_run_cmd.addArgs(args);
    }

    const programs_test_run_step = b.step("run-programs", "Run the Smart Contracts (Programs) test");
    programs_test_run_step.dependOn(&programs_test_run_cmd.step);
    // Custom Programs Test executable
    const custom_programs_test_exe = b.addExecutable(.{
        .name = "custom-programs-test",
        .root_source_file = b.path("src/custom_programs_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(custom_programs_test_exe);

    // Custom Programs Test run command
    const custom_programs_test_run_cmd = b.addRunArtifact(custom_programs_test_exe);
    custom_programs_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        custom_programs_test_run_cmd.addArgs(args);
    }

    const custom_programs_test_run_step = b.step("run-custom-programs", "Run the Custom Programs test");
    custom_programs_test_run_step.dependOn(&custom_programs_test_run_cmd.step);

    // STUN/NAT Traversal Test executable
    const stun_test_exe = b.addExecutable(.{
        .name = "stun-test",
        .root_source_file = b.path("src/stun_test_simple.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(stun_test_exe);

    // STUN Test run command
    const stun_test_run_cmd = b.addRunArtifact(stun_test_exe);
    stun_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        stun_test_run_cmd.addArgs(args);
    }

    const stun_test_run_step = b.step("run-stun", "Run the STUN/NAT Traversal test");
    stun_test_run_step.dependOn(&stun_test_run_cmd.step);



    // Port Scanner Test executable
    const port_scanner_test_exe = b.addExecutable(.{
        .name = "port-scanner-test",
        .root_source_file = b.path("src/port_scanner_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(port_scanner_test_exe);

    // Port Scanner Test run command
    const port_scanner_test_run_cmd = b.addRunArtifact(port_scanner_test_exe);
    port_scanner_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        port_scanner_test_run_cmd.addArgs(args);
    }

    const port_scanner_test_run_step = b.step("run-port-scan", "Run the Port Scanner test");
    port_scanner_test_run_step.dependOn(&port_scanner_test_run_cmd.step);

    // Broadcast Test executable
    const broadcast_test_exe = b.addExecutable(.{
        .name = "broadcast-test",
        .root_source_file = b.path("src/broadcast_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(broadcast_test_exe);

    // Broadcast Test run command
    const broadcast_test_run_cmd = b.addRunArtifact(broadcast_test_exe);
    broadcast_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        broadcast_test_run_cmd.addArgs(args);
    }

    const broadcast_test_run_step = b.step("run-broadcast", "Run the Broadcast test");
    broadcast_test_run_step.dependOn(&broadcast_test_run_cmd.step);
    // Tracker Test executable
    const tracker_test_exe = b.addExecutable(.{
        .name = "tracker-test",
        .root_source_file = b.path("src/tracker_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(tracker_test_exe);

    // Tracker Test run command
    const tracker_test_run_cmd = b.addRunArtifact(tracker_test_exe);
    tracker_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        tracker_test_run_cmd.addArgs(args);
    }

    const tracker_test_run_step = b.step("run-tracker", "Run the Tracker server/client test");
    tracker_test_run_step.dependOn(&tracker_test_run_cmd.step);

    // Phase 9 Testing Framework executable
    const phase9_test_exe = b.addExecutable(.{
        .name = "phase9-test",
        .root_source_file = b.path("src/phase9_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(phase9_test_exe);

    // Phase 9 Test run command
    const phase9_test_run_cmd = b.addRunArtifact(phase9_test_exe);
    phase9_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        phase9_test_run_cmd.addArgs(args);
    }

    const phase9_test_run_step = b.step("run-phase9", "Run Phase 9 comprehensive testing framework");
    phase9_test_run_step.dependOn(&phase9_test_run_cmd.step);

    // EAS (Eastsea Attestation Service) Test executable
    const eas_test_exe = b.addExecutable(.{
        .name = "eas-test",
        .root_source_file = b.path("src/eas_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(eas_test_exe);

    // EAS Test run command
    const eas_test_run_cmd = b.addRunArtifact(eas_test_exe);
    eas_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        eas_test_run_cmd.addArgs(args);
    }

    const eas_test_run_step = b.step("run-eas", "Run Eastsea Attestation Service test");
    eas_test_run_step.dependOn(&eas_test_run_cmd.step);

    // EAS Use Cases Test executable
    const eas_use_cases_test_exe = b.addExecutable(.{
        .name = "eas-use-cases-test",
        .root_source_file = b.path("src/eas_use_cases_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(eas_use_cases_test_exe);

    // EAS Use Cases Test run command
    const eas_use_cases_test_run_cmd = b.addRunArtifact(eas_use_cases_test_exe);
    eas_use_cases_test_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        eas_use_cases_test_run_cmd.addArgs(args);
    }

    const eas_use_cases_test_run_step = b.step("run-eas-use-cases", "Run Eastsea Attestation Service use cases test");
    eas_use_cases_test_run_step.dependOn(&eas_use_cases_test_run_cmd.step);

    // QUIC Protocol Test executable (Phase 13)
    const quic_test_exe = b.addExecutable(.{
        .name = "quic-test",
        .root_source_file = b.path("src/quic_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(quic_test_exe);

    // Web Server Test executable
    // const web_server_test_exe = b.addExecutable(.{
    //     .name = "web-server-test",
    //     .root_source_file = b.path("src/web_server_test.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });

    // b.installArtifact(web_server_test_exe);

    // Web Server Test run command
    // const web_server_test_run_cmd = b.addRunArtifact(web_server_test_exe);
    // web_server_test_run_cmd.step.dependOn(b.getInstallStep());

    // if (b.args) |args| {
    //     web_server_test_run_cmd.addArgs(args);
    // }

    // const web_server_test_run_step = b.step("run-web-server", "Run the Web Server test");
    // web_server_test_run_step.dependOn(&web_server_test_run_cmd.step);

}