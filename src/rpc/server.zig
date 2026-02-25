const std = @import("std");
const blockchain = @import("../blockchain/blockchain.zig");
const network = @import("../network/node.zig");
const base58 = @import("../encoding/base58.zig");
const ed25519 = std.crypto.sign.ed25519.Ed25519;
const base64 = std.base64;

fn hexValue(ch: u8) ?u8 {
    return switch (ch) {
        '0'...'9' => ch - '0',
        'a'...'f' => ch - 'a' + 10,
        'A'...'F' => ch - 'A' + 10,
        else => null,
    };
}

fn parseHexBytePair(input: []const u8, index: usize) !u8 {
    const hi = hexValue(input[index]) orelse return error.InvalidParams;
    const lo = hexValue(input[index + 1]) orelse return error.InvalidParams;
    return (hi << 4) | lo;
}

fn decodeHexBytes(comptime N: usize, input: []const u8) ![N]u8 {
    if (input.len != N * 2) return error.InvalidParams;
    var bytes: [N]u8 = undefined;
    for (0..N) |i| {
        bytes[i] = try parseHexBytePair(input, i * 2);
    }
    return bytes;
}

fn decodeBase64Bytes(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const decoded_len = try base64.standard.Decoder.calcSizeForSlice(input);
    const decoded = try allocator.alloc(u8, decoded_len);
    const written = base64.standard.Decoder.decode(decoded, input) catch |err| {
        allocator.free(decoded);
        return err;
    };
    if (written == 0) {
        allocator.free(decoded);
        return error.InvalidParams;
    }
    return decoded[0..written];
}

fn decodeTransactionPayload(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const decoded_base64 = decodeBase64Bytes(allocator, encoded) catch |_| null;
    if (decoded_base64 != null) {
        return decoded_base64.?;
    }
    return try base58.decode(allocator, encoded);
}

const LegacyTxPayload = struct {
    from: []const u8,
    to: []const u8,
    amount: u64,
    timestamp: i64,
    nonce: i64,
};

fn parseLegacySignedPayload(payload: []const u8) !LegacyTxPayload {
    if (!std.mem.startsWith(u8, payload, "eastsea:tx:")) {
        return error.InvalidParams;
    }

    const body = payload["eastsea:tx:".len..];
    var parts = std.mem.split(u8, body, ":");

    const from = parts.next() orelse return error.InvalidParams;
    const to = parts.next() orelse return error.InvalidParams;
    const amount_text = parts.next() orelse return error.InvalidParams;
    const timestamp_text = parts.next() orelse return error.InvalidParams;
    const nonce_text = parts.next() orelse return error.InvalidParams;

    if (parts.next() != null) return error.InvalidParams;

    return .{
        .from = from,
        .to = to,
        .amount = std.fmt.parseInt(u64, amount_text, 10) catch return error.InvalidParams,
        .timestamp = std.fmt.parseInt(i64, timestamp_text, 10) catch return error.InvalidParams,
        .nonce = std.fmt.parseInt(i64, nonce_text, 10) catch return error.InvalidParams,
    };
}

fn setObjectField(
    allocator: std.mem.Allocator,
    object: *std.json.ObjectMap,
    key: []const u8,
    value: std.json.Value,
) !void {
    const copied_key = try allocator.dupe(u8, key);
    errdefer allocator.free(copied_key);
    try object.put(copied_key, value);
}

fn decodeSolanaAddress(allocator: std.mem.Allocator, address: []const u8) ![ed25519.PublicKey.encoded_length]u8 {
    const decoded = try base58.decode(allocator, address) catch return error.InvalidParams;
    defer allocator.free(decoded);

    if (decoded.len != ed25519.PublicKey.encoded_length) {
        return error.InvalidParams;
    }

    var normalized: [ed25519.PublicKey.encoded_length]u8 = undefined;
    @memcpy(normalized[0..], decoded);
    return normalized;
}

fn getRequiredString(params: *const std.json.ObjectMap, key: []const u8) ![]const u8 {
    const value = params.get(key) orelse return error.InvalidParams;
    return switch (value) {
        .string => |v| v,
        else => return error.InvalidParams,
    };
}

fn getOptionalString(params: *const std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const value = params.get(key) orelse return null;
    return switch (value) {
        .string => |v| v,
        else => null,
    };
}

fn getRequiredInteger(params: *const std.json.ObjectMap, key: []const u8) !i64 {
    const value = params.get(key) orelse return error.InvalidParams;
    return switch (value) {
        .integer => |v| v,
        else => return error.InvalidParams,
    };
}

fn getOptionalInteger(params: *const std.json.ObjectMap, key: []const u8) ?i64 {
    const value = params.get(key) orelse return null;
    return switch (value) {
        .integer => |v| v,
        else => null,
    };
}

fn parseStringFromValue(value: std.json.Value) ![]const u8 {
    return switch (value) {
        .string => |v| v,
        else => return error.InvalidParams,
    };
}

fn parseU64FromValue(value: std.json.Value) !u64 {
    switch (value) {
        .integer => |v| {
            if (v < 0) return error.InvalidParams;
            return @intCast(v);
        },
        .string => |v| return std.fmt.parseInt(u64, v, 10) catch error.InvalidParams,
        else => return error.InvalidParams,
    }
}

fn getAddressFromParams(params: ?std.json.Value) ![]const u8 {
    if (params == null) return error.InvalidParams;

    switch (params.?) {
        .array => |arr| {
            if (arr.items.len == 0) return error.InvalidParams;
            return parseStringFromValue(arr.items[0]);
        },
        .object => |obj| {
            return getRequiredString(&obj, "address");
        },
        else => return error.InvalidParams,
    }
}

fn getSignatureFromParams(params: ?std.json.Value) ![]const u8 {
    if (params == null) return error.InvalidParams;

    switch (params.?) {
        .array => |arr| {
            if (arr.items.len == 0) return error.InvalidParams;
            return parseStringFromValue(arr.items[0]);
        },
        .object => |obj| {
            return getRequiredString(&obj, "signature");
        },
        .string => |signature| return signature,
        else => return error.InvalidParams,
    }
}

fn getSlotFromParams(params: ?std.json.Value) !usize {
    if (params == null) return error.InvalidParams;

    switch (params.?) {
        .array => |arr| {
            if (arr.items.len == 0) return error.InvalidParams;
            return parseU64FromValue(arr.items[0]) catch error.InvalidParams;
        },
        .object => |obj| {
            const slot_value = obj.get("slot") orelse return error.InvalidParams;
            return parseU64FromValue(slot_value);
        },
        .integer => |slot| {
            if (slot < 0) return error.InvalidParams;
            return @intCast(slot);
        },
        .string => |slot| return parseU64FromValue(.{ .string = slot }) catch error.InvalidParams,
        else => return error.InvalidParams,
    }
}

fn getLimitFromSignaturesParams(params: ?std.json.Value) !usize {
    if (params == null) return 100;

    var limit: usize = 100;

    switch (params.?) {
        .array => |arr| {
            if (arr.items.len >= 2) {
                switch (arr.items[1]) {
                    .object => |opts| {
                        if (opts.get("limit")) |value| {
                            const limit_value = try parseU64FromValue(value);
                            const clamped = std.math.min(limit_value, @as(u64, 1000));
                            limit = @intCast(clamped);
                        }
                    },
                    else => {},
                }
            }
        },
        .object => |obj| {
            if (obj.get("limit")) |value| {
                const limit_value = try parseU64FromValue(value);
                const clamped = std.math.min(limit_value, @as(u64, 1000));
                limit = @intCast(clamped);
            }
        },
        else => {},
    }

    return limit;
}

fn buildSignedPayload(
    allocator: std.mem.Allocator,
    from: []const u8,
    to: []const u8,
    amount: u64,
    timestamp: i64,
    nonce: i64,
) ![]u8 {
    return try std.fmt.allocPrint(
        allocator,
        "eastsea:tx:{s}:{s}:{d}:{d}:{d}",
        .{ from, to, amount, timestamp, nonce },
    );
}

pub const RpcMethod = enum {
    getBlockHeight,
    getBalance,
    getHealth,
    getVersion,
    getSlot,
    getLatestBlockhash,
    getLatestBlockHeight,
    getTransactionCount,
    getGenesisHash,
    getSignaturesForAddress,
    sendTransaction,
    getBlock,
    getTransaction,
    getPeers,
    getNodeInfo,
    
    pub fn fromString(method: []const u8) ?RpcMethod {
        if (std.mem.eql(u8, method, "getBlockHeight")) return .getBlockHeight;
        if (std.mem.eql(u8, method, "getBalance")) return .getBalance;
        if (std.mem.eql(u8, method, "getHealth")) return .getHealth;
        if (std.mem.eql(u8, method, "getVersion")) return .getVersion;
        if (std.mem.eql(u8, method, "getSlot")) return .getSlot;
        if (std.mem.eql(u8, method, "getLatestBlockhash")) return .getLatestBlockhash;
        if (std.mem.eql(u8, method, "getLatestBlockHeight")) return .getLatestBlockHeight;
        if (std.mem.eql(u8, method, "getTransactionCount")) return .getTransactionCount;
        if (std.mem.eql(u8, method, "getGenesisHash")) return .getGenesisHash;
        if (std.mem.eql(u8, method, "getSignaturesForAddress")) return .getSignaturesForAddress;
        if (std.mem.eql(u8, method, "sendTransaction")) return .sendTransaction;
        if (std.mem.eql(u8, method, "getBlock")) return .getBlock;
        if (std.mem.eql(u8, method, "getTransaction")) return .getTransaction;
        if (std.mem.eql(u8, method, "getPeers")) return .getPeers;
        if (std.mem.eql(u8, method, "getNodeInfo")) return .getNodeInfo;
        return null;
    }
};

pub const RpcRequest = struct {
    jsonrpc: []const u8,
    method: []const u8,
    params: ?std.json.Value,
    id: ?std.json.Value,
};

pub const RpcResponse = struct {
    jsonrpc: []const u8 = "2.0",
    result: ?std.json.Value = null,
    @"error": ?RpcError = null,
    id: ?std.json.Value = null,
    
    // Helper method to clean up allocated memory in result
    pub fn deinit(self: *RpcResponse, allocator: std.mem.Allocator) void {
        if (self.result) |*result| {
            self.deinitJsonValue(result, allocator);
        }
    }
    
    fn deinitJsonValue(self: *RpcResponse, value: *std.json.Value, allocator: std.mem.Allocator) void {
        switch (value.*) {
            .string => |str| allocator.free(str),
            .array => |*arr| {
                for (arr.items) |*item| {
                    self.deinitJsonValue(item, allocator);
                }
                arr.deinit();
            },
            .object => |*obj| {
                var iterator = obj.iterator();
                while (iterator.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    self.deinitJsonValue(entry.value_ptr, allocator);
                }
                obj.deinit();
            },
            else => {},
        }
    }
};

pub const RpcError = struct {
    code: i32,
    message: []const u8,
    data: ?std.json.Value = null,
};

pub const RpcServer = struct {
    allocator: std.mem.Allocator,
    blockchain_ref: *blockchain.Blockchain,
    node_ref: *network.Node,
    port: u16,
    is_running: bool,
    
    pub fn init(
        allocator: std.mem.Allocator, 
        blockchain_ref: *blockchain.Blockchain, 
        node_ref: *network.Node,
        port: u16
    ) RpcServer {
        return RpcServer{
            .allocator = allocator,
            .blockchain_ref = blockchain_ref,
            .node_ref = node_ref,
            .port = port,
            .is_running = false,
        };
    }
    
    pub fn start(self: *RpcServer) !void {
        self.is_running = true;
        std.debug.print("🚀 RPC Server started on port {}\n", .{self.port});
        std.debug.print("📡 Available methods:\n", .{});
        std.debug.print("  - getBlockHeight\n", .{});
        std.debug.print("  - getBalance\n", .{});
        std.debug.print("  - getHealth\n", .{});
        std.debug.print("  - getVersion\n", .{});
        std.debug.print("  - getSlot\n", .{});
        std.debug.print("  - getLatestBlockhash\n", .{});
        std.debug.print("  - getLatestBlockHeight\n", .{});
        std.debug.print("  - getTransactionCount\n", .{});
        std.debug.print("  - getGenesisHash\n", .{});
        std.debug.print("  - getSignaturesForAddress\n", .{});
        std.debug.print("  - sendTransaction\n", .{});
        std.debug.print("  - getBlock\n", .{});
        std.debug.print("  - getTransaction\n", .{});
        std.debug.print("  - getPeers\n", .{});
        std.debug.print("  - getNodeInfo\n", .{});
    }
    
    pub fn stop(self: *RpcServer) void {
        self.is_running = false;
        std.debug.print("🛑 RPC Server stopped\n", .{});
    }
    
    pub fn handleRequest(self: *RpcServer, request_json: []const u8) ![]u8 {
        var parsed = std.json.parseFromSlice(RpcRequest, self.allocator, request_json, .{}) catch {
            const error_response = RpcResponse{
                .@"error" = RpcError{
                    .code = -32700,
                    .message = "Parse error",
                },
            };
            return try serializeJsonResponse(self.allocator, error_response);
        };
        defer parsed.deinit();
        
        const request = parsed.value;
        
        // Validate JSON-RPC version
        if (!std.mem.eql(u8, request.jsonrpc, "2.0")) {
            const error_response = RpcResponse{
                .@"error" = RpcError{
                    .code = -32600,
                    .message = "Invalid Request",
                },
                .id = request.id,
            };
            return try serializeJsonResponse(self.allocator, error_response);
        }
        
        const method = RpcMethod.fromString(request.method) orelse {
            const error_response = RpcResponse{
                .@"error" = RpcError{
                    .code = -32601,
                    .message = "Method not found",
                },
                .id = request.id,
            };
            return try serializeJsonResponse(self.allocator, error_response);
        };

        const result = self.executeMethod(method, request.params) catch |err| {
            const error_info = switch (err) {
                error.InvalidParams => .{ .code = -32602, .message = "Invalid params" },
                error.InvalidSignature => .{ .code = -32000, .message = "Invalid signature" },
                else => .{ .code = -32603, .message = "Internal error" },
            };
            const error_response = RpcResponse{
                .@"error" = RpcError{
                    .code = error_info.code,
                    .message = error_info.message,
                },
                .id = request.id,
            };
            return try serializeJsonResponse(self.allocator, error_response);
        };
        
        var response = RpcResponse{
            .result = result,
            .id = request.id,
        };
        
        const response_json = try serializeJsonResponse(self.allocator, response);
        
        // Clean up the response result to prevent memory leaks
        response.deinit(self.allocator);
        
        return response_json;
    }

fn serializeJsonResponse(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    var buffer = std.array_list.Managed(u8).init(allocator);
    defer buffer.deinit();
    try std.fmt.format(buffer.writer(), "{f}", .{std.json.fmt(value, .{})});
    return try buffer.toOwnedSlice();
}
    
    fn executeMethod(self: *RpcServer, method: RpcMethod, params: ?std.json.Value) !std.json.Value {
        switch (method) {
            .getBlockHeight => {
                const height = self.blockchain_ref.getHeight();
                return std.json.Value{ .integer = @intCast(height) };
            },

            .getBalance => {
                const address = try getAddressFromParams(params);
                _ = try decodeSolanaAddress(self.allocator, address);

                const balance = self.blockchain_ref.getAddressBalance(address);
                const current_slot = self.blockchain_ref.getHeight();
                const slot = if (current_slot > 0) current_slot - 1 else 0;

                var context = std.json.ObjectMap.init(self.allocator);
                var result = std.json.ObjectMap.init(self.allocator);

                try setObjectField(self.allocator, &context, "slot", .{ .integer = @intCast(slot) });
                try setObjectField(self.allocator, &result, "context", .{ .object = context });
                try setObjectField(self.allocator, &result, "value", .{ .integer = @intCast(balance) });
                return std.json.Value{ .object = result };
            },

            .getHealth => {
                return std.json.Value{ .string = try self.allocator.dupe(u8, "ok") };
            },

            .getVersion => {
                var version = std.json.ObjectMap.init(self.allocator);
                try setObjectField(self.allocator, &version, "solana-core", .{ .string = try self.allocator.dupe(u8, "1.18.18") });
                try setObjectField(self.allocator, &version, "feature-set", .{ .integer = 0 });
                try setObjectField(self.allocator, &version, "version", .{ .string = try self.allocator.dupe(u8, "1.0.0") });
                return std.json.Value{ .object = version };
            },

            .getSlot => {
                const height = self.blockchain_ref.getHeight();
                const slot = if (height > 0) height - 1 else 0;
                return std.json.Value{ .integer = @intCast(slot) };
            },

            .getLatestBlockhash => {
                const block = self.blockchain_ref.getLatestBlock();
                const current_slot = block.index;
                const tx_count: u64 = @intCast(block.transactions.items.len);
                const last_valid_height = self.blockchain_ref.getHeight() + tx_count;

                var value = std.json.ObjectMap.init(self.allocator);
                var result = std.json.ObjectMap.init(self.allocator);
                var context = std.json.ObjectMap.init(self.allocator);

                try setObjectField(self.allocator, &value, "blockhash", .{ .string = try self.allocator.dupe(u8, block.hash) });
                try setObjectField(self.allocator, &value, "lastValidBlockHeight", .{ .integer = @intCast(last_valid_height) });
                try setObjectField(self.allocator, &context, "slot", .{ .integer = @intCast(current_slot) });
                try setObjectField(self.allocator, &result, "context", .{ .object = context });
                try setObjectField(self.allocator, &result, "value", .{ .object = value });
                return std.json.Value{ .object = result };
            },

            .getLatestBlockHeight => {
                const block = self.blockchain_ref.getLatestBlock();
                return std.json.Value{ .integer = @intCast(block.index) };
            },

            .getTransactionCount => {
                var count: u64 = 0;
                for (self.blockchain_ref.chain.items) |*block| {
                    count += @as(u64, @intCast(block.transactions.items.len));
                }
                for (self.blockchain_ref.pending_transactions.items) |_| {
                    count += 1;
                }

                const current_slot = self.blockchain_ref.getHeight();
                const slot = if (current_slot > 0) current_slot - 1 else 0;

                var context = std.json.ObjectMap.init(self.allocator);
                var result = std.json.ObjectMap.init(self.allocator);

                try setObjectField(self.allocator, &context, "slot", .{ .integer = @intCast(slot) });
                try setObjectField(self.allocator, &result, "context", .{ .object = context });
                try setObjectField(self.allocator, &result, "value", .{ .integer = @intCast(count) });
                return std.json.Value{ .object = result };
            },

            .getGenesisHash => {
                const genesis_block = &self.blockchain_ref.chain.items[0];
                return std.json.Value{ .string = try self.allocator.dupe(u8, genesis_block.hash) };
            },

            .getSignaturesForAddress => {
                const address = try getAddressFromParams(params);
                _ = try decodeSolanaAddress(self.allocator, address);

                const limit = try getLimitFromSignaturesParams(params);
                var signatures = std.array_list.Managed(std.json.Value).init(self.allocator);
                var remaining = limit;

                var chain_index = self.blockchain_ref.chain.items.len;
                while (chain_index > 0 and remaining > 0) {
                    chain_index -= 1;
                    const block = self.blockchain_ref.chain.items[chain_index];
                    for (block.transactions.items) |tx| {
                        if (remaining == 0) break;
                        const tx_hash = try tx.hash(self.allocator);
                        const matches = std.mem.eql(u8, tx.from, address) or std.mem.eql(u8, tx.to, address);
                        if (!matches) {
                            self.allocator.free(tx_hash);
                            continue;
                        }

                        var item = std.json.ObjectMap.init(self.allocator);
                        try setObjectField(self.allocator, &item, "signature", .{ .string = tx_hash });
                        try setObjectField(self.allocator, &item, "slot", .{ .integer = @as(i64, @intCast(block.index)) });
                        try setObjectField(self.allocator, &item, "err", .null);
                        try setObjectField(self.allocator, &item, "confirmationStatus", .{ .string = try self.allocator.dupe(u8, "finalized") });
                        try setObjectField(self.allocator, &item, "blockTime", .{ .integer = tx.timestamp });
                        try signatures.append(.{ .object = item });

                        remaining -= 1;
                    }
                }

                if (remaining > 0) {
                    for (self.blockchain_ref.pending_transactions.items) |tx| {
                        if (remaining == 0) break;
                        if (!std.mem.eql(u8, tx.from, address) and !std.mem.eql(u8, tx.to, address)) continue;

                        const tx_hash = try tx.hash(self.allocator);
                        var item = std.json.ObjectMap.init(self.allocator);
                        try setObjectField(self.allocator, &item, "signature", .{ .string = tx_hash });
                        try setObjectField(self.allocator, &item, "slot", .{ .integer = @as(i64, @intCast(self.blockchain_ref.getHeight())) });
                        try setObjectField(self.allocator, &item, "err", .null);
                        try setObjectField(self.allocator, &item, "confirmationStatus", .{ .string = try self.allocator.dupe(u8, "processed") });
                        try setObjectField(self.allocator, &item, "blockTime", .{ .integer = tx.timestamp });
                        try signatures.append(.{ .object = item });

                        remaining -= 1;
                    }
                }

                var context = std.json.ObjectMap.init(self.allocator);
                var result = std.json.ObjectMap.init(self.allocator);
                const current_slot = self.blockchain_ref.getHeight();
                const slot = if (current_slot > 0) current_slot - 1 else 0;

                try setObjectField(self.allocator, &context, "slot", .{ .integer = @as(i64, @intCast(slot)) });
                try setObjectField(self.allocator, &result, "context", .{ .object = context });
                try setObjectField(self.allocator, &result, "value", .{ .array = signatures });
                return std.json.Value{ .object = result };
            },

            .sendTransaction => {
                if (params == null) {
                    return error.InvalidParams;
                }

                const params_value = params.?;
                if (params_value == .array) {
                    const params_array = params_value.array;
                    if (params_array.items.len == 0) {
                        return error.InvalidParams;
                    }

                    const encoded_tx = try parseStringFromValue(params_array.items[0]);
                    const decoded = try decodeTransactionPayload(self.allocator, encoded_tx);
                    defer self.allocator.free(decoded);

                    const parsed = parseLegacySignedPayload(decoded) catch {
                        return error.InvalidParams;
                    };

                    _ = try decodeSolanaAddress(self.allocator, parsed.from);
                    _ = try decodeSolanaAddress(self.allocator, parsed.to);
                    if (parsed.amount == 0) {
                        return error.InvalidParams;
                    }

                    const tx = blockchain.Transaction{
                        .from = try self.allocator.dupe(u8, parsed.from),
                        .to = try self.allocator.dupe(u8, parsed.to),
                        .amount = parsed.amount,
                        .timestamp = parsed.timestamp,
                    };
                    errdefer {
                        self.allocator.free(tx.from);
                        self.allocator.free(tx.to);
                    }

                    try self.blockchain_ref.addTransaction(tx);
                    const tx_hash = try tx.hash(self.allocator);
                    return std.json.Value{ .string = tx_hash };
                } else if (params_value == .object) {
                    const params_obj = params_value.object;

                    const from = try getRequiredString(&params_obj, "from");
                    const to = try getRequiredString(&params_obj, "to");
                    _ = try decodeSolanaAddress(self.allocator, from);
                    _ = try decodeSolanaAddress(self.allocator, to);
                    const amount_value = try getRequiredInteger(&params_obj, "amount");
                    if (amount_value <= 0) {
                        return error.InvalidParams;
                    }
                    const amount = @as(u64, @intCast(amount_value));

                    const timestamp = getOptionalInteger(&params_obj, "timestamp") orelse std.time.timestamp();
                    const nonce = getOptionalInteger(&params_obj, "nonce") orelse 0;

                    const signature = getOptionalString(&params_obj, "signature");
                    const public_key = getOptionalString(&params_obj, "public_key");
                    const has_signature = signature != null;
                    const has_public_key = public_key != null;
                    if (has_signature != has_public_key) {
                        return error.InvalidParams;
                    }

                    if (has_signature and has_public_key) {
                        const public_key_bytes = try decodeSolanaAddress(self.allocator, public_key.?);
                        if (!std.mem.eql(u8, from, public_key.?)) {
                            return error.InvalidParams;
                        }

                        const signature_hex = signature.?;
                        const provided_message = getOptionalString(&params_obj, "message");
                        const message = provided_message orelse
                            try buildSignedPayload(self.allocator, from, to, amount, timestamp, nonce);
                        defer if (provided_message == null) {
                            self.allocator.free(message);
                        };

                        const signature_bytes = try decodeHexBytes(ed25519.Signature.encoded_length, signature_hex);
                        const public_key_obj = ed25519.PublicKey.fromBytes(public_key_bytes);
                        const signature_obj = ed25519.Signature.fromBytes(signature_bytes);
                        signature_obj.verify(message, public_key_obj) catch |err| {
                            if (err == error.SignatureVerificationFailed) {
                                return error.InvalidSignature;
                            }
                            return err;
                        };
                    }

                    const tx = blockchain.Transaction{
                        .from = try self.allocator.dupe(u8, from),
                        .to = try self.allocator.dupe(u8, to),
                        .amount = amount,
                        .timestamp = timestamp,
                    };
                    errdefer {
                        self.allocator.free(tx.from);
                        self.allocator.free(tx.to);
                    }

                    try self.blockchain_ref.addTransaction(tx);
                    const tx_hash = try tx.hash(self.allocator);
                    return std.json.Value{ .string = tx_hash };
                }

                return error.InvalidParams;
            },

            .getBlock => {
                if (params == null) {
                    return error.InvalidParams;
                }

                const slot_u = try getSlotFromParams(params);
                if (slot_u >= self.blockchain_ref.chain.items.len) {
                    return std.json.Value{ .null = {} };
                }

                const block = &self.blockchain_ref.chain.items[slot_u];
                var transaction_list = std.array_list.Managed(std.json.Value).init(self.allocator);

                for (block.transactions.items) |tx| {
                    const tx_hash = try tx.hash(self.allocator);
                    const tx_from = try self.allocator.dupe(u8, tx.from);
                    const tx_to = try self.allocator.dupe(u8, tx.to);

                var tx_record = std.json.ObjectMap.init(self.allocator);
                var account_keys = std.array_list.Managed(std.json.Value).init(self.allocator);
                try account_keys.append(.{ .string = tx_from });
                try account_keys.append(.{ .string = tx_to });
                try setObjectField(self.allocator, &tx_record, "hash", .{ .string = tx_hash });
                try setObjectField(self.allocator, &tx_record, "amount", .{ .integer = @as(i64, @intCast(tx.amount)) });
                try setObjectField(self.allocator, &tx_record, "timestamp", .{ .integer = tx.timestamp });
                try setObjectField(self.allocator, &tx_record, "accountKeys", .{ .array = account_keys });
                    try transaction_list.append(.{ .object = tx_record });
                }

                var value = std.json.ObjectMap.init(self.allocator);
                var result = std.json.ObjectMap.init(self.allocator);
                var context = std.json.ObjectMap.init(self.allocator);

                try setObjectField(self.allocator, &value, "blockhash", .{ .string = try self.allocator.dupe(u8, block.hash) });
                try setObjectField(self.allocator, &value, "previousBlockhash", .{ .string = try self.allocator.dupe(u8, block.previous_hash) });
                try setObjectField(self.allocator, &value, "parentSlot", .{ .integer = if (block.index > 0) @as(i64, @intCast(block.index - 1)) else 0 });
                try setObjectField(self.allocator, &value, "timestamp", .{ .integer = block.timestamp });
                try setObjectField(self.allocator, &value, "transactions", .{ .array = transaction_list });
                try setObjectField(self.allocator, &context, "slot", .{ .integer = @as(i64, @intCast(slot_u)) });
                try setObjectField(self.allocator, &result, "context", .{ .object = context });
                try setObjectField(self.allocator, &result, "value", .{ .object = value });
                return std.json.Value{ .object = result };
            },

            .getTransaction => {
                if (params == null) {
                    return error.InvalidParams;
                }

                const signature = try getSignatureFromParams(params);
                const chain = self.blockchain_ref.chain.items;
                const current_height = self.blockchain_ref.getHeight();
                const current_slot = if (current_height > 0) current_height - 1 else 0;

                for (chain, 0..) |*block, slot| {
                    for (block.transactions.items) |tx| {
                        const tx_hash = try tx.hash(self.allocator);
                        if (!std.mem.eql(u8, tx_hash, signature)) {
                            self.allocator.free(tx_hash);
                            continue;
                        }

                        var sigs = std.array_list.Managed(std.json.Value).init(self.allocator);
                        try sigs.append(.{ .string = tx_hash });

                        var message = std.json.ObjectMap.init(self.allocator);
                        var account_keys = std.array_list.Managed(std.json.Value).init(self.allocator);
                        const tx_from = try self.allocator.dupe(u8, tx.from);
                        const tx_to = try self.allocator.dupe(u8, tx.to);
                        var instructions = std.array_list.Managed(std.json.Value).init(self.allocator);

                        try account_keys.append(.{ .string = tx_from });
                        try account_keys.append(.{ .string = tx_to });
                        try setObjectField(self.allocator, &message, "accountKeys", .{ .array = account_keys });
                        try setObjectField(self.allocator, &message, "recentBlockhash", .{ .string = try self.allocator.dupe(u8, block.hash) });
                        try setObjectField(self.allocator, &message, "instructions", .{ .array = instructions });

                        var tx_obj = std.json.ObjectMap.init(self.allocator);
                        try setObjectField(self.allocator, &tx_obj, "message", .{ .object = message });
                        try setObjectField(self.allocator, &tx_obj, "signatures", .{ .array = sigs });

                        var meta = std.json.ObjectMap.init(self.allocator);
                        try setObjectField(self.allocator, &meta, "err", .null);
                        try setObjectField(self.allocator, &meta, "status", .{ .string = try self.allocator.dupe(u8, "finalized") });

                        var result = std.json.ObjectMap.init(self.allocator);
                        try setObjectField(self.allocator, &result, "slot", .{ .integer = @as(i64, @intCast(slot)) });
                        try setObjectField(self.allocator, &result, "blockTime", .{ .integer = tx.timestamp });
                        try setObjectField(self.allocator, &result, "transaction", .{ .object = tx_obj });
                        try setObjectField(self.allocator, &result, "meta", .{ .object = meta });
                        return std.json.Value{ .object = result };
                    }
                }

                for (self.blockchain_ref.pending_transactions.items) |tx| {
                    const tx_hash = try tx.hash(self.allocator);
                    if (!std.mem.eql(u8, tx_hash, signature)) {
                        self.allocator.free(tx_hash);
                        continue;
                    }

                    var sigs = std.array_list.Managed(std.json.Value).init(self.allocator);
                    try sigs.append(.{ .string = tx_hash });

                    var message = std.json.ObjectMap.init(self.allocator);
                    var account_keys = std.array_list.Managed(std.json.Value).init(self.allocator);
                    const tx_from = try self.allocator.dupe(u8, tx.from);
                    const tx_to = try self.allocator.dupe(u8, tx.to);

                    try account_keys.append(.{ .string = tx_from });
                    try account_keys.append(.{ .string = tx_to });
                    try setObjectField(self.allocator, &message, "accountKeys", .{ .array = account_keys });
                    try setObjectField(self.allocator, &message, "instructions", .{ .array = std.array_list.Managed(std.json.Value).init(self.allocator) });

                    var tx_obj = std.json.ObjectMap.init(self.allocator);
                    try setObjectField(self.allocator, &tx_obj, "message", .{ .object = message });
                    try setObjectField(self.allocator, &tx_obj, "signatures", .{ .array = sigs });

                    var meta = std.json.ObjectMap.init(self.allocator);
                    try setObjectField(self.allocator, &meta, "err", .null);

                    var result = std.json.ObjectMap.init(self.allocator);
                    try setObjectField(self.allocator, &result, "slot", .{ .integer = @as(i64, @intCast(current_slot)) });
                    try setObjectField(self.allocator, &result, "blockTime", .{ .integer = tx.timestamp });
                    try setObjectField(self.allocator, &result, "transaction", .{ .object = tx_obj });
                    try setObjectField(self.allocator, &result, "meta", .{ .object = meta });
                    return std.json.Value{ .object = result };
                }

                return std.json.Value{ .null = {} };
            },

            .getPeers => {
                const peer_count = self.node_ref.getPeerCount();
                return std.json.Value{ .integer = @as(i64, @intCast(peer_count)) };
            },

            .getNodeInfo => {
                const peer_count = self.node_ref.getPeerCount();
                const block_height = self.blockchain_ref.getHeight();
                const node_id = try self.node_ref.getNodeId(self.allocator);
                errdefer self.allocator.free(node_id);

                var node_info = std.json.ObjectMap.init(self.allocator);
                const address_value = try self.allocator.dupe(u8, self.node_ref.address);
                errdefer self.allocator.free(address_value);

                try setObjectField(self.allocator, &node_info, "address", .{ .string = address_value });
                try setObjectField(self.allocator, &node_info, "port", .{ .integer = self.node_ref.port });
                try setObjectField(self.allocator, &node_info, "peer_count", .{ .integer = @as(i64, @intCast(peer_count)) });
                try setObjectField(self.allocator, &node_info, "is_running", .{ .bool = self.node_ref.is_running });
                try setObjectField(self.allocator, &node_info, "blockchain_height", .{ .integer = @as(i64, @intCast(block_height)) });
                try setObjectField(self.allocator, &node_info, "node_id", .{ .string = node_id });
                return std.json.Value{ .object = node_info };
            },
        }
    }
    
    pub fn processRequest(self: *RpcServer, method: []const u8, params: []const u8) ![]u8 {
        const request_template = 
            \\{{"jsonrpc": "2.0", "method": "{s}", "params": {s}, "id": 1}}
        ;
        
        const request_json = try std.fmt.allocPrint(self.allocator, request_template, .{ method, params });
        defer self.allocator.free(request_json);
        
        return try self.handleRequest(request_json);
    }
    
    pub fn isRunning(self: *const RpcServer) bool {
        return self.is_running;
    }
};

// Helper function to create a simple RPC client for testing
pub const RpcClient = struct {
    allocator: std.mem.Allocator,
    server_address: []const u8,
    server_port: u16,
    
    pub fn init(allocator: std.mem.Allocator, address: []const u8, port: u16) RpcClient {
        return RpcClient{
            .allocator = allocator,
            .server_address = address,
            .server_port = port,
        };
    }
    
    pub fn call(self: *RpcClient, method: []const u8, params: ?[]const u8) ![]u8 {
        const params_str = params orelse "null";
        
        const request = try std.fmt.allocPrint(
            self.allocator,
            \\{{"jsonrpc": "2.0", "method": "{s}", "params": {s}, "id": 1}}
            ,
            .{ method, params_str }
        );
        defer self.allocator.free(request);
        
        // In a real implementation, this would make an HTTP request
        std.debug.print("📞 RPC Call: {s}\n", .{request});
        
        // Mock response for demo
        const response = try std.fmt.allocPrint(
            self.allocator,
            \\{{"jsonrpc": "2.0", "result": "mock_result", "id": 1}}
            ,
            .{}
        );
        
        return response;
    }
};

test "rpc method parsing" {
    const method = RpcMethod.fromString("getBlockHeight");
    try std.testing.expect(method == .getBlockHeight);
    
    const invalid = RpcMethod.fromString("invalidMethod");
    try std.testing.expect(invalid == null);
}

test "rpc server creation" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var chain = try blockchain.Blockchain.init(allocator);
    defer chain.deinit();
    
    var node = network.Node.init(allocator, "127.0.0.1", 8000);
    defer node.deinit();
    
    var server = RpcServer.init(allocator, &chain, &node, 8545);
    
    try testing.expect(!server.isRunning());
    try server.start();
    try testing.expect(server.isRunning());
    
    server.stop();
    try testing.expect(!server.isRunning());
}
