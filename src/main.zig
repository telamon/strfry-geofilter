const std = @import("std");
const log = std.log.debug; // std.log.scoped(.powmem);
const toHex = std.fmt.fmtSliceHexLower;

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    //std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    //const stdin_file = std.io.getStdIn();
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("Bobolobo\n", .{});
    try bw.flush(); // don't forget to flush!
}

const NostrEvent = struct {
    id: []const u8,
    created_at: u64,
    kind: u32,
    pubkey: []const u8,
    sig: []const u8,
    content: []const u8,
    tags: [][]const u8,
    pub fn format(
        self: *const NostrEvent,
        comptime _: []const u8, // fmt
        _: std.fmt.FormatOptions, // fmtOpts
        writer: anytype,
    ) !void {
        try writer.print("NostrEvent=>\n" ++
            "\tid: {s}\n" ++
            "\tkind: {d}\n" ++
            "\tcreated_at: {d}\n" ++
            "\tpubkey: {s}\n" ++
            "\tsig: {s}\n" ++
            "\ttags: {s}\n" ++
            "\tcontent: {s}", .{
            self.id,
            self.kind,
            self.created_at,
            self.pubkey,
            self.sig,
            self.tags,
            self.content,
        });
    }
};
const StrfryEvent = struct {
    event: NostrEvent,
    receivedAt: u64,
    sourceInfo: []const u8,
    sourceType: []const u8,
    type: []const u8,
    pub fn format(
        self: *const StrfryEvent,
        comptime _: []const u8, // fmt
        _: std.fmt.FormatOptions, // fmtOpts
        writer: anytype,
    ) !void {
        try writer.print("StrfryEvent[ receivedAt: {d} type: {s}, sourceType: {s}, sourceInfo: {s},\n{}\n ]", .{
            self.receivedAt,
            self.type,
            self.sourceType,
            self.sourceInfo,
            self.event,
        });
    }
};
const StrfryCommand = struct { id: []const u8, action: []const u8, msg: []const u8 };

pub const PowmemFilter = struct {
    const Self = @This();
    geohash: []const u8,

    pub fn init() PowmemFilter {
        return .{
            .geohash = "u268",
        };
    }

    pub fn doLine(_: *Self, json: []const u8, allocator: std.mem.Allocator) !StrfryCommand {
        log("doLine(): {s}", .{json});
        var tokens = std.json.TokenStream.init(json);
        const opts: std.json.ParseOptions = .{ .allocator = allocator };
        var ev = try std.json.parse(StrfryEvent, &tokens, opts);
        defer std.json.parseFree(StrfryEvent, ev, opts);
        log("{}", .{ev});
        var pk: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&pk, ev.event.id);
        log("Raw PK {s} ASL: {}", .{ pk, decodeASL(&pk) });
        return .{
            .id = "",
            .msg = "",
            .action = "reject",
        };
    }
};

pub fn roundByte(n_bits: usize) usize {
    const bytes = n_bits >> 3;
    if (n_bits % 8 == 0) return bytes;
    return bytes + 1;
}

pub fn decodeASL(pubkey: []const u8) ASL {
    const GEOBITS = 15;
    // The information is bitpacked / unaligned,
    // whoever data mines will end up paying something.
    var bit = BitIterator.init(pubkey);
    const age = bit.read(u2);
    const sex = bit.read(u2);
    // Port of unpackGeo()

    // Bitpacked geohash, NOT b32 string form!
    var geohash: [roundByte(GEOBITS)]u8 = undefined;
    bit.copy(&geohash, GEOBITS);
    log("Geohash {}", .{toHex(&geohash)});

    // var geohash_string: [GEOBITS / 5]u8 = undefined;
    // var i: usize = 0;
    // while (i < geohash.len) : (i += 1) geohash[i] = iter.next(5);

    return .{
        .age = age, // (pubkey[0] & 1) | ((pubkey[0] & 0b10) << 1),
        .sex = sex, // (pubkey[0] & 0b100) | ((pubkey[0] & 0b1000) << 1),
        .location = &geohash, // TODO: b32Encode
    };
}
pub const ASL = struct { age: u2, sex: u2, location: []const u8 };

pub const BitIterator = struct {
    const Self = @This();
    buffer: []const u8,
    byte: usize,
    bit: u3,
    pub fn init(b: []const u8) Self {
        return .{ .buffer = b, .byte = 0, .bit = 0 };
    }

    /// Reads n_bits from buffer at current offset and copies to dst buffer
    pub fn copy(self: *Self, dst: []u8, n_bits: usize) void {
        var i: usize = 0;
        while (i < n_bits) : (i += 1) {
            dst[i >> 3] |= @as(u8, self.next()) << @truncate(u3, i % 8);
        }
    }

    // Entertaining myself with some meta-programming
    /// Reads Uint of size T
    pub fn read(self: *Self, comptime T: type) T {
        const n_bits = @typeInfo(T).Int.bits;
        const TLog2 = comptime @Type(.{ .Int = .{
            .signedness = .unsigned,
            .bits = std.math.log2(n_bits),
        } });
        var i: u16 = 0;
        var out: T = 0;
        while (i < n_bits) : (i += 1) {
            out |= @as(T, self.next()) << @truncate(TLog2, i);
        }
        return out;
    }

    /// Reads 1 bit from buffer
    pub fn next(self: *Self) u1 {
        if (self.byte >= self.buffer.len) unreachable;
        const out = @truncate(u1, self.buffer[self.byte] >> self.bit);
        self.inc();
        return out;
    }

    /// Increase offset by 1 bit, or roll over to next byte
    inline fn inc(self: *Self) void {
        if (self.bit == 7) {
            self.byte += 1;
            self.bit = 0;
        } else self.bit += 1;
    }
};

pub const Geo32 = struct {
    pub const ALPHA = "0123456789bcdefghjkmnpqrstuvwxyz";
    // Encodes u64 to base32 string using the highest bits.
    pub fn encode(geohash: u64, dst: []u8) !void {
        const bits = @typeInfo(u64).Int.bits;
        const chars = std.math.ceil(bits / 5);
        if (dst.len < chars) return error.NotEnoughSpace;
        var i = 0;
        while (i < chars) : (i += 1) {
            const q: u5 = geohash & (0b11111 << (bits - (5 + 5 * i)));
            log("Quintet{d} => {d}", .{ i, q });
        }
    }
};

test "Decode ASL" {
    std.testing.log_level = .debug;
    // This is a public key x-coordinate with the first parity byte/key-id stripped;
    // I wrote the first version of powmem in codename: picochat.
    // That project used the default curve and key format of libsodium
    // When I published this idea i adapted it to nostr which uses the secp256k1 curve.
    // The praxis there is to prepend each pk with an id-byte 02,03 that gives the Y-coord parity.
    // This byte must be ignored in powmem, we burn bits into the raw X-coord.
    var pk: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&pk, "b618af96fde8ba61d43dde06583e7a897256c10c1d11c4b32dc15b76726593e6");
    const asl = decodeASL(&pk);
    try std.testing.expectEqual(asl.age, 2);
    try std.testing.expectEqual(asl.sex, 1);
    log("Decoded {}", .{toHex(asl.location)});
}

test "simple test" {
    std.testing.log_level = .debug;
    const ally = std.testing.allocator;

    log("\nKEOKE", .{});
    // Managed to extract at least one event.
    const event_json = (
        \\{"event":{"content":"{\"ws://localhost:7777\":{\"read\":true,\"write\":true}}","created_at":1694743226,"id":"07d116430524028f69d5cb98b30a07e9b8facc8ac0e1a05b5b6308a4c82faa63","kind":3,"pubkey":"a68d00310ff20aa1b44512859278950b338440d79d3a4b861b7e6f4343543363","sig":"9dc7f31aa4c802529c211d6bee528bf549648d7a12c2bbc0c9aa2f1e0c4735d8443f7f6a81651e402b08dc88e2c6f947f7580629f5ec809604e209446b148711","tags":[]},"receivedAt":1694743226,"sourceInfo":"172.18.0.1","sourceType":"IP4","type":"new"}
    );
    var filter = PowmemFilter.init();
    const cmd = try filter.doLine(event_json, ally);
    log("Filter result: {}", .{cmd});
    // try std.testing.expectEqual(@as(i32, 42), list.pop());
}

// The Three Lemmas of Decentralization
//
// 1. Any attempt to measure the state alters the state.
// 2.
