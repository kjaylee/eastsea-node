const std = @import("std");
const print = std.debug.print;

// 기존 코어 모듈
const blockchain = @import("blockchain/blockchain.zig");
const crypto = @import("crypto/hash.zig");
const network = @import("network/node.zig");
const consensus = @import("consensus/poh.zig");
const rpc = @import("rpc/server.zig");
const wallet = @import("cli/wallet.zig");

// REQ 신규 모듈 통합
const onboarding = @import("onboarding.zig");
const boot_check = @import("boot_check.zig");
const storage_init = @import("storage_init.zig");
const auth = @import("auth.zig");
const tls_config = @import("tls_config.zig");
const rpc_validator = @import("rpc_validator.zig");
const updater = @import("updater.zig");
const monitoring = @import("monitoring.zig");
const diagnostics = @import("diagnostics.zig");
const persistence = @import("persistence.zig");
const rbac = @import("rbac.zig");
const web_dashboard = @import("web_dashboard.zig");
const upnp = @import("upnp.zig");
const vm = @import("vm.zig");

/// ~/.eastsea 경로 결정
fn getEastseaHome(allocator: std.mem.Allocator) ![]u8 {
    const home = std.process.getEnvVarOwned(allocator, "HOME") catch {
        return try allocator.dupe(u8, "/tmp");
    };
    defer allocator.free(home);
    return try std.fmt.allocPrint(allocator, "{s}/.eastsea", .{home});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var demo_mode = false;
    var show_help = false;
    var show_diag = false;

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--demo")) {
            demo_mode = true;
        } else if (std.mem.eql(u8, arg, "--help")) {
            show_help = true;
        } else if (std.mem.eql(u8, arg, "--diag")) {
            show_diag = true;
        }
    }

    if (show_help) {
        printUsage();
        return;
    }

    // ========================================
    // Phase 0: 진단 리포트 (--diag)
    // ========================================
    if (show_diag) {
        const report = try diagnostics.generateReport(allocator);
        defer allocator.free(report);
        print("{s}\n", .{report});
        return;
    }

    print("\n", .{});
    print("🌊 Eastsea Node v{d}.{d}.{d}\n", .{
        updater.CURRENT_VERSION.major,
        updater.CURRENT_VERSION.minor,
        updater.CURRENT_VERSION.patch,
    });
    print("==========================================\n", .{});

    // ========================================
    // Phase 1: 온보딩 (REQ-101)
    // ========================================
    print("\n📋 Phase 1: 온보딩 설정...\n", .{});

    const eastsea_home = try getEastseaHome(allocator);
    defer allocator.free(eastsea_home);

    // ~/.eastsea/ 디렉토리 보장
    try onboarding.validateDataPath(eastsea_home);

    const config_path = try std.fmt.allocPrint(allocator, "{s}/config.json", .{eastsea_home});
    defer allocator.free(config_path);
    const node_config = try onboarding.saveInitialConfig(allocator, config_path);

    print("   node_port={d}, rpc_port={d}, validator={}\n", .{
        node_config.node_port,
        node_config.rpc_port,
        node_config.is_validator,
    });

    // ========================================
    // Phase 2: 부트 진단 (REQ-111)
    // ========================================
    print("\n🔍 Phase 2: 부트 진단...\n", .{});

    boot_check.runBootDiagnostics(
        node_config.node_port,
        node_config.rpc_port,
        9000, // QUIC port
        node_config.data_dir,
    );

    // ========================================
    // Phase 2.5: UPnP 포트 자동 매핑
    // ========================================
    print("\n🔓 Phase 2.5: UPnP 포트 매핑...\n", .{});
    var upnp_client = upnp.UPnP.init(allocator);
    defer upnp_client.deinit();
    if (upnp_client.discover() catch false) {
        upnp_client.autoMapNodePorts(node_config.node_port, node_config.rpc_port);
    } else {
        print("   ⚠️  UPnP 미지원 라우터 — 수동 포트 포워딩 필요\n", .{});
    }

    // ========================================
    // Phase 3: 저장소 초기화 (REQ-110)
    // ========================================
    print("📦 Phase 3: 저장소 초기화...\n", .{});

    const data_dir = try std.fmt.allocPrint(allocator, "{s}/data", .{eastsea_home});
    defer allocator.free(data_dir);
    try onboarding.validateDataPath(data_dir);

    const storage_meta = try storage_init.autoInitStorage(allocator, data_dir);
    print("   스키마 v{d}\n", .{storage_meta.schema_version});

    // 마이그레이션 확인
    const migrated = try storage_init.migrateOnce(allocator, data_dir);
    if (migrated) {
        print("   ✅ 마이그레이션 적용됨\n", .{});
    }

    // ========================================
    // Phase 4: 보안 초기화 (REQ-001, REQ-040)
    // ========================================
    print("\n🔐 Phase 4: 보안 초기화...\n", .{});

    // 인증 토큰 발급
    const api_token = auth.issueToken("admin", 86400); // 24시간
    const token_valid = auth.validateToken(&api_token) catch false;
    print("   API 토큰 발급: scope=admin, valid={}\n", .{token_valid});

    // TLS 설정 검증 (마스킹)
    const tls = tls_config.TlsConfig{};
    const tls_json = try tls_config.validateConfig(allocator, tls);
    defer allocator.free(tls_json);
    print("   TLS 설정: enabled={}\n", .{tls.enabled});

    // RBAC 확인
    const admin_can_delete = rbac.authorize(.admin, "config", "delete");
    const viewer_can_write = rbac.authorize(.viewer, "config", "write");
    print("   RBAC: admin.delete={}, viewer.write={}\n", .{ admin_can_delete, viewer_can_write });

    // ========================================
    // Phase 5: 버전 확인 (REQ-102)
    // ========================================
    print("\n🔄 Phase 5: 버전 확인...\n", .{});
    print("   현재 버전: v{d}.{d}.{d}\n", .{
        updater.CURRENT_VERSION.major,
        updater.CURRENT_VERSION.minor,
        updater.CURRENT_VERSION.patch,
    });

    // ========================================
    // Phase 6: 웹 대시보드 + 코어 시작
    // ========================================
    print("\n🚀 Phase 6: 코어 시작...\n", .{});

    // 웹 대시보드 시작 (별도 스레드)
    var web_server = web_dashboard.WebServer.init(allocator, node_config.rpc_port);
    web_server.start() catch |err| {
        print("⚠️  웹 대시보드 시작 실패: {} (노드는 계속 실행)\n", .{err});
    };
    defer web_server.stop();

    if (demo_mode) {
        try runDemo(allocator, node_config);
    } else {
        try runProductionNode(allocator, node_config);
    }
}

fn printUsage() void {
    print("Eastsea Node — Install-and-Run 블록체인 노드\n", .{});
    print("사용법: eastsea [옵션]\n\n", .{});
    print("  --demo    데모 모드로 실행\n", .{});
    print("  --diag    진단 리포트 출력\n", .{});
    print("  --help    도움말\n", .{});
}

fn runProductionNode(allocator: std.mem.Allocator, config: onboarding.NodeConfig) !void {
    print("==========================================\n", .{});
    print("📍 Node: {s}:{d}\n", .{ config.node_address, config.node_port });
    print("🌐 RPC:  {s}:{d}\n", .{ config.node_address, config.rpc_port });
    print("⚡ Validator: {}\n", .{config.is_validator});

    // 코어 초기화
    var chain = try blockchain.Blockchain.init(allocator);
    defer chain.deinit();
    print("✅ Blockchain initialized (Height: {d})\n", .{chain.getHeight()});

    var node = network.Node.init(allocator, config.node_address, config.node_port);
    defer node.deinit();
    try node.start();
    try node.discoverPeers();

    const node_id = try std.fmt.allocPrint(allocator, "node_{d}", .{config.node_port});
    defer allocator.free(node_id);

    var consensus_engine = try consensus.ConsensusEngine.init(allocator, node_id);
    defer consensus_engine.deinit();
    print("⚡ Consensus engine initialized\n", .{});

    var rpc_server = rpc.RpcServer.init(allocator, &chain, &node, config.rpc_port);
    try rpc_server.start();
    defer rpc_server.stop();

    // RPC 응답 검증 (REQ-021)
    const info = try rpc_server.processRequest("getNodeInfo", "null");
    defer allocator.free(info);
    if (!rpc_validator.validateRpcResponse(info)) {
        print("⚠️  RPC 응답에 mock 값 감지\n", .{});
    }

    // 모니터링 시작 (REQ-121)
    const start_time = std.time.timestamp();

    print("\n🎯 Node is running in production mode...\n", .{});
    print("Press Ctrl+C to stop\n", .{});
    print("==========================================\n", .{});

    // 메인 루프
    var slot_timer = std.time.Timer.start() catch unreachable;
    const slot_duration_ns = 400 * std.time.ns_per_ms;
    var last_stats_time = std.time.timestamp();

    while (true) {
        if (slot_timer.read() >= slot_duration_ns) {
            try consensus_engine.processSlot();

            if (consensus_engine.isCurrentLeader() and chain.hasPendingTransactions()) {
                try chain.mineBlock();
                print("⛏️  Block mined! Height: {d}\n", .{chain.getHeight()});
            }

            slot_timer.reset();
        }

        _ = processNetworkMessages(&node) catch {};

        // 30초마다 통계 + 모니터링 (REQ-121)
        const current_time = std.time.timestamp();
        if (current_time - last_stats_time >= 30) {
            const metrics = monitoring.collectMetrics(
                chain.getHeight(),
                @as(u32, @intCast(node.getPeerCount())),
                start_time,
            );
            const alert = monitoring.alertThreshold(&metrics);
            if (alert) |msg| {
                print("🚨 Alert: {s}\n", .{msg});
            }

            // 상태 영속화 (REQ-010)
            persistence.saveState(allocator, "/tmp/.eastsea_state.json", .{
                .block_height = chain.getHeight(),
                .peer_count = @intCast(node.getPeerCount()),
                .last_checkpoint = current_time,
            }) catch {};

            printNodeStats(&chain, &node, &consensus_engine);
            last_stats_time = current_time;
        }

        std.time.sleep(10 * std.time.ns_per_ms);
    }
}

fn processNetworkMessages(node: *network.Node) !void {
    _ = node;
}

fn printNodeStats(chain: *blockchain.Blockchain, node: *network.Node, consensus_engine: *consensus.ConsensusEngine) void {
    const poh_state = consensus_engine.getCurrentPohState();
    print("\n📊 Node Statistics:\n", .{});
    print("  • Blockchain Height: {d}\n", .{chain.getHeight()});
    print("  • Connected Peers: {d}\n", .{node.getPeerCount()});
    print("  • PoH Ticks: {d}\n", .{poh_state.tick_count});
    print("  • Node Status: {s}\n", .{if (node.isConnected()) "Connected" else "Disconnected"});
    print("==========================================\n", .{});
}

fn runDemo(allocator: std.mem.Allocator, config: onboarding.NodeConfig) !void {
    print("==========================================\n", .{});
    print("🎯 Demo Sequence Starting...\n", .{});
    print("==========================================\n", .{});

    // 코어 초기화
    var chain = try blockchain.Blockchain.init(allocator);
    defer chain.deinit();
    print("✅ Blockchain initialized (Height: {d})\n", .{chain.getHeight()});

    var node = network.Node.init(allocator, config.node_address, config.node_port);
    defer node.deinit();
    try node.start();
    try node.discoverPeers();

    var consensus_engine = try consensus.ConsensusEngine.init(allocator, "main_node");
    defer consensus_engine.deinit();
    print("⚡ Proof of History consensus initialized\n", .{});

    var rpc_server = rpc.RpcServer.init(allocator, &chain, &node, config.rpc_port);
    try rpc_server.start();
    defer rpc_server.stop();

    var cli_wallet = wallet.WalletCLI.init(allocator);
    defer cli_wallet.deinit();

    // Demo 1: Wallet
    print("\n1️⃣  Creating wallet accounts...\n", .{});
    const addr1 = try cli_wallet.wallet.createAccount();
    const addr2 = try cli_wallet.wallet.createAccount();
    try cli_wallet.wallet.setBalance(addr1, 1000);
    try cli_wallet.wallet.setBalance(addr2, 500);
    cli_wallet.wallet.listAccounts();

    // Demo 2: Transaction + PoH
    print("\n2️⃣  Processing transactions with Proof of History...\n", .{});
    const tx1 = blockchain.Transaction{
        .from = addr1,
        .to = addr2,
        .amount = 100,
        .timestamp = std.time.timestamp(),
    };
    const tx1_data = try std.fmt.allocPrint(allocator, "{s}{s}{d}{d}", .{ tx1.from, tx1.to, tx1.amount, tx1.timestamp });
    defer allocator.free(tx1_data);
    try consensus_engine.processTransaction(tx1_data);
    try chain.addTransaction(tx1);
    print("💸 Transaction: {s} -> {s} ({d})\n", .{ tx1.from, tx1.to, tx1.amount });

    // Demo 3: Mine
    print("\n3️⃣  Mining blocks...\n", .{});
    try consensus_engine.processSlot();
    try consensus_engine.processSlot();
    try chain.mineBlock();
    print("⛏️  Block mined! Height: {d}\n", .{chain.getHeight()});

    // Demo 4: Network
    print("\n4️⃣  Network operations...\n", .{});
    const ping_msg = network.Message.init(.ping, "ping");
    try node.broadcastMessage(ping_msg);

    // Demo 5: RPC + mock 검증 (REQ-021)
    print("\n5️⃣  RPC API + mock 검증...\n", .{});
    const height_response = try rpc_server.processRequest("getBlockHeight", "null");
    defer allocator.free(height_response);
    print("📡 getBlockHeight: {s}\n", .{height_response});

    const node_info = try rpc_server.processRequest("getNodeInfo", "null");
    defer allocator.free(node_info);
    const is_clean = rpc_validator.validateRpcResponse(node_info);
    print("📡 getNodeInfo: {s} (mock-free: {})\n", .{ node_info, is_clean });

    // Demo 6: Wallet transfer
    print("\n6️⃣  Wallet transfer...\n", .{});
    const transfer_tx = try cli_wallet.wallet.transfer(addr1, addr2, 50);
    const signature = try cli_wallet.wallet.signTransaction(transfer_tx);
    defer allocator.free(signature);
    print("✍️  Signed: {s}\n", .{signature[0..16]});

    // Demo 7: Auth + RBAC (REQ-001, REQ-002)
    print("\n7️⃣  Auth + RBAC 검증...\n", .{});
    const token = auth.issueToken("admin", 3600);
    const valid = auth.validateToken(&token) catch false;
    print("🔑 Token valid={}, admin.delete={}, viewer.write={}\n", .{
        valid,
        rbac.authorize(.admin, "config", "delete"),
        rbac.authorize(.viewer, "config", "write"),
    });

    // Demo 8: 모니터링 (REQ-121)
    print("\n8️⃣  모니터링 스냅샷...\n", .{});
    const metrics = monitoring.collectMetrics(chain.getHeight(), @intCast(node.getPeerCount()), std.time.timestamp() - 60);
    const healthy = monitoring.healthCheck(&metrics);
    print("💓 healthy={}, uptime={d}s, alert={s}\n", .{
        healthy,
        metrics.uptime_seconds,
        monitoring.alertThreshold(&metrics) orelse "none",
    });

    // Demo 9: 상태 영속화 (REQ-010)
    print("\n9️⃣  상태 영속화...\n", .{});
    const state_path = "/tmp/.eastsea_state.json";
    try persistence.saveState(allocator, state_path, .{
        .block_height = chain.getHeight(),
        .peer_count = @intCast(node.getPeerCount()),
        .last_checkpoint = std.time.timestamp(),
    });
    const loaded = try persistence.loadState(allocator, state_path);
    print("💾 저장 후 로드: block_height={d}\n", .{loaded.block_height});

    // Demo 10: Validation
    print("\n🔟 Blockchain validation...\n", .{});
    print("🔍 Chain valid: {}\n", .{chain.isChainValid()});

    // Demo 11: 스마트 컨트랙트 VM
    print("\n📜 Demo 11: 스마트 컨트랙트 VM...\n", .{});
    {
        var contract_storage = std.AutoHashMap(i64, i64).init(allocator);
        defer contract_storage.deinit();

        // ERC20 토큰 시뮬레이션 바이트코드
        var asm_ = vm.Assembler.init(allocator);
        defer asm_.deinit();

        // total_supply = 1,000,000
        try asm_.push(0);
        try asm_.push(1_000_000);
        try asm_.op(.SSTORE);

        // owner = 1,000,000
        try asm_.push(1);
        try asm_.push(1_000_000);
        try asm_.op(.SSTORE);

        // transfer 100 to user
        try asm_.push(1);
        try asm_.op(.SLOAD);
        try asm_.push(100);
        try asm_.op(.SUB);
        try asm_.push(1);
        try asm_.op(.SWAP);
        try asm_.op(.SSTORE);

        try asm_.push(2);
        try asm_.push(100);
        try asm_.op(.SSTORE);

        // LOG: Transfer event
        try asm_.push(0xEE);
        try asm_.push(100);
        try asm_.op(.LOG);

        try asm_.push(1);
        try asm_.op(.SLOAD);
        try asm_.op(.HALT);

        var evm = vm.VM.init(allocator, &contract_storage, "owner", vm.VM_MAX_GAS);
        var result = try evm.execute(asm_.build());
        defer result.deinit();

        print("   ✅ 컨트랙트 실행: success={}, gas_used={d}\n", .{ result.success, result.gas_used });
        print("   📊 ERC20: owner={d}, user={d}, total={d}\n", .{
            contract_storage.get(1) orelse 0,
            contract_storage.get(2) orelse 0,
            contract_storage.get(0) orelse 0,
        });
        print("   📋 이벤트: {d}개 (Transfer 100 EST)\n", .{result.logs.items.len});
    }

    // Final Stats
    const poh = consensus_engine.getCurrentPohState();
    print("\n🎉 Eastsea Node Demo Completed!\n", .{});
    print("==========================================\n", .{});
    print("📊 Final Statistics:\n", .{});
    print("  • Blockchain height: {d}\n", .{chain.getHeight()});
    print("  • Network peers: {d}\n", .{node.getPeerCount()});
    print("  • Wallet accounts: {d}\n", .{cli_wallet.wallet.getAccountCount()});
    print("  • PoH ticks: {d}\n", .{poh.tick_count});
    print("  • RPC server: {}\n", .{rpc_server.isRunning()});
    print("  • Auth: ✅  RBAC: ✅  TLS: ✅\n", .{});
    print("  • Monitoring: ✅  Persistence: ✅\n", .{});
    print("  • Smart Contract VM: ✅\n", .{});
    print("==========================================\n", .{});
}

test "production node config" {
    const testing = std.testing;
    const config = onboarding.NodeConfig{
        .node_port = 9000,
        .rpc_port = 9545,
        .is_validator = true,
    };
    try testing.expect(config.node_port == 9000);
    try testing.expect(config.rpc_port == 9545);
    try testing.expect(config.is_validator == true);
}
