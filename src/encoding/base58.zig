const std = @import("std");

const BASE58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

fn base58Char(value: u8) u8 {
    return BASE58_ALPHABET[value];
}

pub fn encode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) {
        return allocator.dupe(u8, "");
    }

    var zeros: usize = 0;
    while (zeros < input.len and input[zeros] == 0) : (zeros += 1) {}

    var digits = try allocator.alloc(u8, input.len * 138 / 100 + 2);
    defer allocator.free(digits);
    var digits_len: usize = 0;

    for (input) |byte| {
        var carry = @as(u32, byte);

        var i: usize = 0;
        while (i < digits_len) : (i += 1) {
            carry += @as(u32, digits[i]) * 256;
            digits[i] = @intCast(carry % 58);
            carry = carry / 58;
        }

        while (carry > 0) {
            if (digits_len >= digits.len) return error.OutOfMemory;
            digits[digits_len] = @intCast(carry % 58);
            digits_len += 1;
            carry = carry / 58;
        }
    }

    const output_len = zeros + digits_len;
    var output = try allocator.alloc(u8, output_len);
    var out_i: usize = 0;

    while (out_i < zeros) : (out_i += 1) {
        output[out_i] = '1';
    }

    var digit_i: usize = digits_len;
    while (digit_i > 0) : (digit_i -= 1) {
        output[out_i] = base58Char(digits[digit_i - 1]);
        out_i += 1;
    }

    return output;
}

fn base58Index(ch: u8) ?u8 {
    return if (std.mem.indexOfScalar(u8, BASE58_ALPHABET, ch)) |idx|
        @intCast(idx)
    else
        null;
}

pub fn decode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) {
        return allocator.dupe(u8, "");
    }

    var zeros: usize = 0;
    while (zeros < input.len and input[zeros] == '1') : (zeros += 1) {}

    var bytes = try allocator.alloc(u8, input.len);
    defer allocator.free(bytes);
    var bytes_len: usize = 0;

    for (input) |ch| {
        const value = base58Index(ch) orelse return error.InvalidCharacter;
        var carry = @as(u32, value);

        var i: usize = 0;
        while (i < bytes_len) : (i += 1) {
            carry += @as(u32, bytes[i]) * 58;
            bytes[i] = @intCast(carry & 0xff);
            carry = carry >> 8;
        }

        while (carry > 0) {
            if (bytes_len >= bytes.len) return error.OutOfMemory;
            bytes[bytes_len] = @intCast(carry & 0xff);
            bytes_len += 1;
            carry = carry >> 8;
        }
    }

    const output_len = zeros + bytes_len;
    var output = try allocator.alloc(u8, output_len);
    var output_i: usize = 0;

    while (output_i < zeros) : (output_i += 1) {
        output[output_i] = 0;
    }

    var bi: usize = 0;
    while (bi < bytes_len) : (bi += 1) {
        output[output_i] = bytes[bytes_len - 1 - bi];
        output_i += 1;
    }

    return output;
}
