const std = @import("std");

const blockchain = @import("blockchain/blockchain.zig");
const consensus = @import("consensus/poh.zig");
const network = @import("network/node.zig");
const rpc = @import("rpc/server.zig");

pub const CoreRuntime = struct {
    allocator: std.mem.Allocator,
    chain: *blockchain.Blockchain,
    node: *network.Node,
    consensus_engine: consensus.ConsensusEngine,
    rpc_server: rpc.RpcServer,

    pub fn init(
        allocator: std.mem.Allocator,
        node_address: []const u8,
        node_port: u16,
        rpc_port: u16,
        consensus_node_id: []const u8,
    ) !CoreRuntime {
        const chain = try allocator.create(blockchain.Blockchain);
        chain.* = try blockchain.Blockchain.init(allocator);

        const node = try allocator.create(network.Node);
        node.* = network.Node.init(allocator, node_address, node_port);

        const consensus_engine = try consensus.ConsensusEngine.init(allocator, consensus_node_id);

        var app_runtime = CoreRuntime{
            .allocator = allocator,
            .chain = chain,
            .node = node,
            .consensus_engine = consensus_engine,
            .rpc_server = undefined,
        };

        try app_runtime.node.start();
        try app_runtime.node.discoverPeers();
        app_runtime.rpc_server = rpc.RpcServer.init(allocator, app_runtime.chain, app_runtime.node, rpc_port);
        try app_runtime.rpc_server.start();

        return app_runtime;
    }

    pub fn deinit(self: *CoreRuntime) void {
        self.rpc_server.stop();
        self.consensus_engine.deinit();
        self.node.stop();
        self.node.deinit();
        self.chain.deinit();
        self.allocator.destroy(self.node);
        self.allocator.destroy(self.chain);
    }
};
