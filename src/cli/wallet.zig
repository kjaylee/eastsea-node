const std = @import("std");
const fs = std.fs;
const blockchain = @import("../blockchain/blockchain.zig");
const base58 = @import("../encoding/base58.zig");
const ed25519 = std.crypto.sign.ed25519.Ed25519;

const WALLET_KEYSTORE_HEADER = "EASTSEA-WALLET-KEYSTORE-V1\n";

pub const WalletError = error{
    InvalidPrivateKeyLength,
    InvalidPrivateKeyHex,
    InvalidKeystoreFormat,
    AddressMismatch,
};

fn hexValue(ch: u8) ?u8 {
    return switch (ch) {
        '0'...'9' => ch - '0',
        'a'...'f' => ch - 'a' + 10,
        'A'...'F' => ch - 'A' + 10,
        else => null,
    };
}

fn parseHexToBytes(hex: []const u8, out: []u8) !void {
    if (hex.len != out.len * 2) return WalletError.InvalidPrivateKeyLength;

    for (0..out.len) |i| {
        const hi = hexValue(hex[i * 2]) orelse return WalletError.InvalidPrivateKeyHex;
        const lo = hexValue(hex[i * 2 + 1]) orelse return WalletError.InvalidPrivateKeyHex;
        out[i] = (hi << 4) | lo;
    }
}

pub const KeyPair = struct {
    key_pair: ed25519.KeyPair,

    pub fn generate() KeyPair {
        return KeyPair{
            .key_pair = ed25519.KeyPair.generate(),
        };
    }

    pub fn fromSeed(seed: [ed25519.KeyPair.seed_length]u8) !KeyPair {
        return KeyPair{
            .key_pair = try ed25519.KeyPair.generateDeterministic(seed),
        };
    }

    pub fn fromPrivateKeyHex(private_key_hex: []const u8) !KeyPair {
        if (private_key_hex.len == ed25519.KeyPair.seed_length * 2) {
            var seed: [ed25519.KeyPair.seed_length]u8 = undefined;
            try parseHexToBytes(private_key_hex, &seed);
            return try KeyPair.fromSeed(seed);
        }

        if (private_key_hex.len == ed25519.SecretKey.encoded_length * 2) {
            var secret_key_bytes: [ed25519.SecretKey.encoded_length]u8 = undefined;
            try parseHexToBytes(private_key_hex, &secret_key_bytes);
            return KeyPair{
                .key_pair = try ed25519.KeyPair.fromSecretKey(try ed25519.SecretKey.fromBytes(secret_key_bytes)),
            };
        }

        return WalletError.InvalidPrivateKeyLength;
    }

    pub fn getAddress(self: *const KeyPair, allocator: std.mem.Allocator) ![]u8 {
        return base58.encode(allocator, self.key_pair.public_key.bytes[0..]);
    }

    pub fn getPrivateKeyHex(self: *const KeyPair, allocator: std.mem.Allocator) ![]u8 {
        const seed = self.key_pair.secret_key.seed();
        const private_key_hex = try allocator.alloc(u8, seed.len * 2);
        _ = std.fmt.bufPrint(private_key_hex, "{s}", .{std.fmt.bytesToHex(&seed, .lower)}) catch unreachable;
        return private_key_hex;
    }

    pub fn sign(self: *const KeyPair, message: []const u8, allocator: std.mem.Allocator) ![]u8 {
        const signature = try ed25519.sign(self.key_pair, message, null);
        const signature_bytes = signature.toBytes();
        const signature_hex = try allocator.alloc(u8, signature_bytes.len * 2);
        _ = std.fmt.bufPrint(signature_hex, "{s}", .{std.fmt.bytesToHex(&signature_bytes, .lower)}) catch unreachable;
        return signature_hex;
    }

    pub fn verifyMessage(self: *const KeyPair, message: []const u8, signature_hex: []const u8) !bool {
        if (signature_hex.len != ed25519.Signature.encoded_length * 2) {
            return false;
        }

        var signature_bytes: [ed25519.Signature.encoded_length]u8 = undefined;
        try parseHexToBytes(signature_hex, &signature_bytes);

        const signature = ed25519.Signature.fromBytes(signature_bytes);
        signature.verify(message, self.key_pair.public_key) catch |err| {
            if (err == error.SignatureVerificationFailed) {
                return false;
            }
            return err;
        };

        return true;
    }
};

pub const Account = struct {
    address: []u8,
    balance: u64,
    nonce: u64,

    pub fn init(allocator: std.mem.Allocator, address: []const u8) !Account {
        return Account{
            .address = try allocator.dupe(u8, address),
            .balance = 0,
            .nonce = 0,
        };
    }

    pub fn deinit(self: *Account, allocator: std.mem.Allocator) void {
        allocator.free(self.address);
    }
};

pub const Wallet = struct {
    keypairs: std.array_list.Managed(KeyPair),
    accounts: std.array_list.Managed(Account),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Wallet {
        return Wallet{
            .keypairs = std.array_list.Managed(KeyPair).init(allocator),
            .accounts = std.array_list.Managed(Account).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Wallet) void {
        for (self.accounts.items) |*account| {
            account.deinit(self.allocator);
        }
        self.keypairs.deinit();
        self.accounts.deinit();
    }

    fn findAccountIndex(self: *const Wallet, address: []const u8) ?usize {
        for (self.accounts.items, 0..) |account, i| {
            if (std.mem.eql(u8, account.address, address)) {
                return i;
            }
        }
        return null;
    }

    fn appendAccount(self: *Wallet, keypair: KeyPair, balance: u64, nonce: u64) ![]const u8 {
        const address = try keypair.getAddress(self.allocator);
        defer self.allocator.free(address);

        if (self.findAccountIndex(address)) |existing_index| {
            self.accounts.items[existing_index].balance = balance;
            self.accounts.items[existing_index].nonce = nonce;
            return self.accounts.items[existing_index].address;
        }

        if (self.keypairs.items.len != self.accounts.items.len) {
            return WalletError.InvalidKeystoreFormat;
        }

        try self.keypairs.append(keypair);
        var account = try Account.init(self.allocator, address);
        account.balance = balance;
        account.nonce = nonce;
        try self.accounts.append(account);

        return self.accounts.items[self.accounts.items.len - 1].address;
    }

    pub fn createAccount(self: *Wallet) ![]const u8 {
        const keypair = KeyPair.generate();
        return try self.appendAccount(keypair, 0, 0);
    }

    pub fn getBalance(self: *const Wallet, address: []const u8) ?u64 {
        if (self.findAccountIndex(address)) |index| {
            return self.accounts.items[index].balance;
        }
        return null;
    }

    pub fn setBalance(self: *Wallet, address: []const u8, balance: u64) !void {
        if (self.findAccountIndex(address)) |index| {
            self.accounts.items[index].balance = balance;
            return;
        }
        return error.AccountNotFound;
    }

    pub fn transfer(self: *Wallet, from: []const u8, to: []const u8, amount: u64) !blockchain.Transaction {
        var sender_account: ?*Account = null;
        for (self.accounts.items) |*account| {
            if (std.mem.eql(u8, account.address, from)) {
                sender_account = account;
                break;
            }
        }

        if (sender_account == null) {
            return error.SenderNotFound;
        }

        if (sender_account.?.balance < amount) {
            return error.InsufficientBalance;
        }

        const transaction = blockchain.Transaction{
            .from = from,
            .to = to,
            .amount = amount,
            .timestamp = std.time.timestamp(),
        };

        sender_account.?.balance -= amount;
        sender_account.?.nonce += 1;

        for (self.accounts.items) |*account| {
            if (std.mem.eql(u8, account.address, to)) {
                account.balance += amount;
                break;
            }
        }

        std.debug.print("💸 Transfer: {s} -> {s} ({} units)\n", .{ from, to, amount });
        return transaction;
    }

    pub fn signTransaction(self: *const Wallet, transaction: blockchain.Transaction) ![]u8 {
        for (self.keypairs.items) |keypair| {
            const sender_address = try keypair.getAddress(self.allocator);
            defer self.allocator.free(sender_address);

            if (std.mem.eql(u8, sender_address, transaction.from)) {
                const tx_data = try std.fmt.allocPrint(
                    self.allocator,
                    "eastsea:tx:{s}:{s}:{d}:{d}:{d}",
                    .{ transaction.from, transaction.to, transaction.amount, transaction.timestamp, 0 },
                );
                defer self.allocator.free(tx_data);

                return try keypair.sign(tx_data, self.allocator);
            }
        }

        return error.KeyPairNotFound;
    }

    pub fn listAccounts(self: *const Wallet) void {
        std.debug.print("📋 Wallet Accounts:\n", .{});
        for (self.accounts.items, 0..) |account, i| {
            std.debug.print("  {}. {s} (Balance: {})\n", .{ i + 1, account.address, account.balance });
        }
    }

    pub fn getAccountCount(self: *const Wallet) usize {
        return self.accounts.items.len;
    }

    pub fn importPrivateKey(self: *Wallet, private_key_hex: []const u8) ![]const u8 {
        const keypair = try KeyPair.fromPrivateKeyHex(private_key_hex);
        const address = try keypair.getAddress(self.allocator);
        defer self.allocator.free(address);

        if (self.findAccountIndex(address)) |existing_index| {
            std.debug.print("📥 Private key already imported: {s}\n", .{self.accounts.items[existing_index].address});
            return self.accounts.items[existing_index].address;
        }

        return try self.appendAccount(keypair, 0, 0);
    }

    pub fn exportPrivateKey(self: *const Wallet, address: []const u8, allocator: std.mem.Allocator) ![]u8 {
        for (self.keypairs.items) |keypair| {
            const key_address = try keypair.getAddress(allocator);
            defer allocator.free(key_address);

            if (std.mem.eql(u8, key_address, address)) {
                return try keypair.getPrivateKeyHex(allocator);
            }
        }

        return error.AccountNotFound;
    }

    pub fn saveToPath(self: *const Wallet, path: []const u8) !void {
        if (self.keypairs.items.len != self.accounts.items.len) {
            return WalletError.InvalidKeystoreFormat;
        }

        var file = try fs.cwd().createFile(path, .{ .truncate = true });
        defer file.close();

        var writer = file.writer();
        try writer.print("{s}", .{WALLET_KEYSTORE_HEADER});
        try writer.print("{d}\n", .{self.accounts.items.len});

        var i: usize = 0;
        while (i < self.accounts.items.len and i < self.keypairs.items.len) : (i += 1) {
            const account = self.accounts.items[i];
            const keypair = self.keypairs.items[i];
            const private_key = try keypair.getPrivateKeyHex(self.allocator);
            defer self.allocator.free(private_key);

            try writer.print(
                "{s}|{s}|{d}|{d}\n",
                .{ account.address, private_key, account.balance, account.nonce },
            );
        }
    }

    pub fn loadFromPath(allocator: std.mem.Allocator, path: []const u8) !Wallet {
        const file = try fs.cwd().openFile(path, .{});
        defer file.close();

        const data = try file.readToEndAlloc(allocator, 16 * 1024 * 1024);
        defer allocator.free(data);

        if (!std.mem.startsWith(u8, data, WALLET_KEYSTORE_HEADER)) {
            return WalletError.InvalidKeystoreFormat;
        }

        const rest = data[WALLET_KEYSTORE_HEADER.len..];
        const header = std.mem.splitScalar(u8, rest, '\n');
        _ = std.fmt.parseInt(usize, std.mem.trim(u8, header.next() orelse return WalletError.InvalidKeystoreFormat, "\r"), 10) catch
            return WalletError.InvalidKeystoreFormat;

        var wallet = Wallet.init(allocator);
        errdefer wallet.deinit();

        var remaining = header;
        while (remaining.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, "\r");
            if (line.len == 0) continue;

            var fields = std.mem.splitScalar(u8, line, '|');
            const address = fields.next() orelse return WalletError.InvalidKeystoreFormat;
            const private_key_hex = fields.next() orelse return WalletError.InvalidKeystoreFormat;
            const balance_text = fields.next() orelse return WalletError.InvalidKeystoreFormat;
            const nonce_text = fields.next() orelse return WalletError.InvalidKeystoreFormat;
            if (fields.next() != null) return WalletError.InvalidKeystoreFormat;

            const keypair = try KeyPair.fromPrivateKeyHex(private_key_hex);
            const expected_address = try keypair.getAddress(allocator);
            defer allocator.free(expected_address);
            if (!std.mem.eql(u8, address, expected_address)) {
                return WalletError.AddressMismatch;
            }

            const balance = std.fmt.parseInt(u64, balance_text, 10) catch return WalletError.InvalidKeystoreFormat;
            const nonce = std.fmt.parseInt(u64, nonce_text, 10) catch return WalletError.InvalidKeystoreFormat;
            _ = try wallet.appendAccount(keypair, balance, nonce);
        }

        return wallet;
    }
};

// CLI Commands
pub const WalletCLI = struct {
    wallet: Wallet,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) WalletCLI {
        return WalletCLI{
            .wallet = Wallet.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *WalletCLI) void {
        self.wallet.deinit();
    }

    pub fn processCommand(self: *WalletCLI, command: []const u8, args: []const []const u8) !void {
        if (std.mem.eql(u8, command, "create")) {
            _ = try self.wallet.createAccount();
        } else if (std.mem.eql(u8, command, "list")) {
            self.wallet.listAccounts();
        } else if (std.mem.eql(u8, command, "balance")) {
            if (args.len < 1) {
                std.debug.print("❌ Usage: balance <address>\n", .{});
                return;
            }
            const balance = self.wallet.getBalance(args[0]);
            if (balance) |bal| {
                std.debug.print("💰 Balance for {s}: {}\n", .{ args[0], bal });
            } else {
                std.debug.print("❌ Account not found\n", .{});
            }
        } else if (std.mem.eql(u8, command, "transfer")) {
            if (args.len < 3) {
                std.debug.print("❌ Usage: transfer <from> <to> <amount>\n", .{});
                return;
            }
            const amount = std.fmt.parseInt(u64, args[2], 10) catch {
                std.debug.print("❌ Invalid amount\n", .{});
                return;
            };
            _ = self.wallet.transfer(args[0], args[1], amount) catch |err| {
                std.debug.print("❌ Transfer failed: {}\n", .{err});
                return;
            };
        } else if (std.mem.eql(u8, command, "import")) {
            if (args.len < 1) {
                std.debug.print("❌ Usage: import <privateKeyHex>\n", .{});
                return;
            }
            const address = try self.wallet.importPrivateKey(args[0]);
            std.debug.print("🔑 Private key imported: {s}\n", .{address});
        } else if (std.mem.eql(u8, command, "export")) {
            if (args.len < 1) {
                std.debug.print("❌ Usage: export <address>\n", .{});
                return;
            }
            const private_key = try self.wallet.exportPrivateKey(args[0], self.allocator);
            defer self.allocator.free(private_key);
            std.debug.print("🔓 Private key: {s}\n", .{private_key});
        } else if (std.mem.eql(u8, command, "save")) {
            if (args.len < 1) {
                std.debug.print("❌ Usage: save <path>\n", .{});
                return;
            }
            try self.wallet.saveToPath(args[0]);
            std.debug.print("💾 Wallet saved to: {s}\n", .{args[0]});
        } else if (std.mem.eql(u8, command, "load")) {
            if (args.len < 1) {
                std.debug.print("❌ Usage: load <path>\n", .{});
                return;
            }
            self.wallet.deinit();
            self.wallet = try Wallet.loadFromPath(self.allocator, args[0]);
            std.debug.print("📥 Wallet loaded from: {s}\n", .{args[0]});
        } else if (std.mem.eql(u8, command, "help")) {
            self.printHelp();
        } else {
            std.debug.print("❌ Unknown command: {s}\n", .{command});
            self.printHelp();
        }
    }

    pub fn printHelp(self: *WalletCLI) void {
        _ = self;
        std.debug.print("🆘 Available commands:\n");
        std.debug.print("  create                    - Create a new account\n");
        std.debug.print("  list                      - List all accounts\n");
        std.debug.print("  balance <address>         - Get account balance\n");
        std.debug.print("  transfer <from> <to> <amt> - Transfer funds\n");
        std.debug.print("  import <privateKeyHex>    - Import private key (32-byte seed)\n");
        std.debug.print("  export <address>          - Export private key (32-byte seed)\n");
        std.debug.print("  save <path>               - Save wallet keystore\n");
        std.debug.print("  load <path>               - Load wallet keystore\n");
        std.debug.print("  help                      - Show this help\n");
    }
};

test "keypair generation" {
    const keypair = KeyPair.generate();
    try std.testing.expect(!std.mem.eql(u8, &keypair.key_pair.public_key.toBytes(), &keypair.key_pair.secret_key.seed()));
}

test "wallet operations" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var wallet = Wallet.init(allocator);
    defer wallet.deinit();

    const address = try wallet.createAccount();
    try testing.expect(wallet.getAccountCount() == 1);

    try wallet.setBalance(address, 100);
    const balance = wallet.getBalance(address);
    try testing.expect(balance.? == 100);
}

test "wallet transfer" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var wallet = Wallet.init(allocator);
    defer wallet.deinit();

    const addr1 = try wallet.createAccount();
    const addr2 = try wallet.createAccount();

    try wallet.setBalance(addr1, 100);
    const tx = try wallet.transfer(addr1, addr2, 50);
    try testing.expect(tx.amount == 50);

    const balance1 = wallet.getBalance(addr1);
    const balance2 = wallet.getBalance(addr2);
    try testing.expect(balance1.? == 50);
    try testing.expect(balance2.? == 50);
}

test "solana-like base58 address generation" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var wallet = Wallet.init(allocator);
    defer wallet.deinit();

    const address = try wallet.createAccount();
    try testing.expect(address.len >= 32);
    try testing.expect(address.len <= 44);

    for (address) |ch| {
        try testing.expect(std.mem.indexOfScalar(u8, "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz", ch) != null);
    }
}

test "import private key keeps deterministic address" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var wallet = Wallet.init(allocator);
    defer wallet.deinit();

    const key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const first = try wallet.importPrivateKey(key);
    const second = try wallet.importPrivateKey(key);

    try testing.expect(std.mem.eql(u8, first, second));
}

test "ed25519 signature verify" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const seed_hex = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const keypair = try KeyPair.fromPrivateKeyHex(seed_hex);
    const message = "hello eastsea";
    const signature = try keypair.sign(message, allocator);
    defer allocator.free(signature);

    try testing.expect(try keypair.verifyMessage(message, signature));
    try testing.expect(!(try keypair.verifyMessage("tampered", signature)));
}

test "wallet keystore save and load" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const wallet_path = "/tmp/eastsea-wallet-keypair-test.txt";

    {
        var wallet = Wallet.init(allocator);
        defer wallet.deinit();

        const address = try wallet.createAccount();
        try wallet.setBalance(address, 1234);
        try wallet.saveToPath(wallet_path);
    }

    var loaded_wallet = try Wallet.loadFromPath(allocator, wallet_path);
    defer loaded_wallet.deinit();

    try testing.expect(loaded_wallet.getAccountCount() == 1);
}
