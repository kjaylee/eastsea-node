const std = @import("std");
const crypto = @import("../crypto/hash.zig");
const blockchain = @import("../blockchain/blockchain.zig");

pub const KeyPair = struct {
    public_key: [32]u8,
    private_key: [32]u8,
    
    pub fn generate() KeyPair {
        var public_key: [32]u8 = undefined;
        var private_key: [32]u8 = undefined;
        
        std.crypto.random.bytes(&private_key);
        std.crypto.random.bytes(&public_key); // Simplified for demo
        
        return KeyPair{
            .public_key = public_key,
            .private_key = private_key,
        };
    }
    
    pub fn getAddress(self: *const KeyPair, allocator: std.mem.Allocator) ![]u8 {
        // Generate address from public key (simplified)
        const address_hash = crypto.sha256Raw(std.mem.asBytes(&self.public_key));
        
        // Take first 20 bytes and encode as hex
        const address = try allocator.alloc(u8, 40);
        _ = std.fmt.bufPrint(address, "{}", .{std.fmt.fmtSliceHexLower(address_hash[0..20])}) catch unreachable;
        
        return address;
    }
    
    pub fn sign(self: *const KeyPair, message: []const u8, allocator: std.mem.Allocator) ![]u8 {
        // Simplified signing - in real implementation would use proper cryptography
        const message_hash = crypto.sha256Raw(message);
        
        const signature = try allocator.alloc(u8, 64);
        
        // Mock signature combining private key and message hash
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(std.mem.asBytes(&self.private_key));
        hasher.update(std.mem.asBytes(&message_hash));
        var sig_hash: [32]u8 = undefined;
        hasher.final(&sig_hash);
        
        _ = std.fmt.bufPrint(signature, "{}", .{std.fmt.fmtSliceHexLower(&sig_hash)}) catch unreachable;
        
        return signature;
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
    keypairs: std.ArrayList(KeyPair),
    accounts: std.ArrayList(Account),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) Wallet {
        return Wallet{
            .keypairs = std.ArrayList(KeyPair).init(allocator),
            .accounts = std.ArrayList(Account).init(allocator),
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
    
    pub fn createAccount(self: *Wallet) ![]const u8 {
        const keypair = KeyPair.generate();
        const address = try keypair.getAddress(self.allocator);
        defer self.allocator.free(address); // Free the temporary address
        
        try self.keypairs.append(keypair);
        
        const account = try Account.init(self.allocator, address);
        try self.accounts.append(account);
        
        std.debug.print("🔑 New account created: {s}\n", .{address});
        
        // Return a reference to the stored address instead of the temporary one
        return self.accounts.items[self.accounts.items.len - 1].address;
    }
    
    pub fn getBalance(self: *const Wallet, address: []const u8) ?u64 {
        for (self.accounts.items) |account| {
            if (std.mem.eql(u8, account.address, address)) {
                return account.balance;
            }
        }
        return null;
    }
    
    pub fn setBalance(self: *Wallet, address: []const u8, balance: u64) !void {
        for (self.accounts.items) |*account| {
            if (std.mem.eql(u8, account.address, address)) {
                account.balance = balance;
                return;
            }
        }
        return error.AccountNotFound;
    }
    
    pub fn transfer(self: *Wallet, from: []const u8, to: []const u8, amount: u64) !blockchain.Transaction {
        // Check if sender account exists and has sufficient balance
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
        
        // Create transaction
        const transaction = blockchain.Transaction{
            .from = from,
            .to = to,
            .amount = amount,
            .timestamp = std.time.timestamp(),
        };
        
        // Update balances (simplified - in real implementation this would be done by blockchain)
        sender_account.?.balance -= amount;
        sender_account.?.nonce += 1;
        
        // Try to update recipient balance if they're in our wallet
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
        // Find the keypair for the sender
        for (self.keypairs.items) |keypair| {
            const address = try keypair.getAddress(self.allocator);
            defer self.allocator.free(address);
            
            if (std.mem.eql(u8, address, transaction.from)) {
                const tx_data = try std.fmt.allocPrint(
                    self.allocator,
                    "{s}{s}{}{}",
                    .{ transaction.from, transaction.to, transaction.amount, transaction.timestamp }
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
        if (private_key_hex.len != 64) {
            return error.InvalidPrivateKeyLength;
        }
        
        // Parse hex private key (simplified)
        var private_key: [32]u8 = undefined;
        var public_key: [32]u8 = undefined;
        
        // In real implementation, would properly parse hex and derive public key
        std.crypto.random.bytes(&private_key);
        std.crypto.random.bytes(&public_key);
        
        const keypair = KeyPair{
            .private_key = private_key,
            .public_key = public_key,
        };
        
        const address = try keypair.getAddress(self.allocator);
        
        try self.keypairs.append(keypair);
        
        const account = try Account.init(self.allocator, address);
        try self.accounts.append(account);
        
        std.debug.print("📥 Private key imported: {s}\n", .{address});
        
        return address;
    }
    
    pub fn exportPrivateKey(self: *const Wallet, address: []const u8, allocator: std.mem.Allocator) ![]u8 {
        for (self.keypairs.items) |keypair| {
            const addr = try keypair.getAddress(allocator);
            defer allocator.free(addr);
            
            if (std.mem.eql(u8, addr, address)) {
                const private_key_hex = try allocator.alloc(u8, 64);
                _ = std.fmt.bufPrint(private_key_hex, "{}", .{std.fmt.fmtSliceHexLower(&keypair.private_key)}) catch unreachable;
                return private_key_hex;
            }
        }
        
        return error.AccountNotFound;
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
                std.debug.print("❌ Usage: balance <address>\n");
                return;
            }
            const balance = self.wallet.getBalance(args[0]);
            if (balance) |bal| {
                std.debug.print("💰 Balance for {s}: {}\n", .{ args[0], bal });
            } else {
                std.debug.print("❌ Account not found\n");
            }
        } else if (std.mem.eql(u8, command, "transfer")) {
            if (args.len < 3) {
                std.debug.print("❌ Usage: transfer <from> <to> <amount>\n");
                return;
            }
            const amount = std.fmt.parseInt(u64, args[2], 10) catch {
                std.debug.print("❌ Invalid amount\n");
                return;
            };
            _ = self.wallet.transfer(args[0], args[1], amount) catch |err| {
                std.debug.print("❌ Transfer failed: {}\n", .{err});
                return;
            };
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
        std.debug.print("  help                      - Show this help\n");
    }
};

test "keypair generation" {
    const keypair = KeyPair.generate();
    
    // Keys should be different
    try std.testing.expect(!std.mem.eql(u8, &keypair.public_key, &keypair.private_key));
}

test "wallet operations" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var wallet = Wallet.init(allocator);
    defer wallet.deinit();
    
    // Create account
    const address = try wallet.createAccount();
    try testing.expect(wallet.getAccountCount() == 1);
    
    // Set and get balance
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