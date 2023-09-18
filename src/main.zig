const std = @import("std");
const log = std.log.debug; // std.log.scoped(.powmem);
pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // const event_buffer = [2048]u8;
    const stdin_file = std.io.getStdIn();
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const parser = std.json.StreamingParser.init();
    var t1: std.json.Token = .{null};
    var t2: std.json.Token = .{null};
    while (true) {
        try parser.feed(stdin_file.read(), &t1, &t2);
    }

    try stdout.print("Bobolobo\n", .{});

    try bw.flush(); // don't forget to flush!
}

const StreamingParser = std.json.StreamingParser;
const Token = std.json.Token;

const StrfryCommand = struct { id: []const u8, action: []const u8, msg: []const u8 };
const StrfryEvent = struct {
    event: struct {
        content: []const u8,
        tags: [][]const u8,
    },
    receivedAt: usize,
    sourceInfo: []const u8,
    sourceType: []const u8,
    type: []const u8,
};

pub const PowmemFilter = struct {
    const Self = @This();
    geohash: []const u8,
    //parser: StreamingParser,

    pub fn init() PowmemFilter {
        return .{
            .geohash = "u268",
            //.parser = StreamingParser.init(),
        };
    }

    pub fn doLine(_: *Self, json: []const u8, allocator: std.mem.Allocator) !StrfryCommand {
        log("doLine(): {s}", .{json});
        var tokens = std.json.TokenStream.init(json);
        var ev = try std.json.parse(StrfryEvent, &tokens, .{ .allocator = allocator });
        log("Magic {}", .{ev});
        //var iter = TokenIterator.init(&self.parser, json);
        //while (try iter.next()) |token| {
        //var d: u8 = 0;
        //switch (token) {
        //.ObjectBegin => {
        //d += 1;
        //log(">> {i}", .{d});
        //},
        //.ObjectEnd => {
        //d -= 1;
        //log(">> {i}", .{d});
        //},
        //.String => |str| {
        //log(".String: ", .{str.slice()});
        //},
        //else => {
        //log(">>> Token set {}", .{token});
        //},
        //}
        //}

        return .{
            .id = "",
            .msg = "",
            .action = "reject",
        };
    }
};

pub const TokenIterator = struct {
    const Self = @This();
    parser: *StreamingParser,
    t0: ?Token,
    t1: ?Token,
    line: []const u8,
    offset: usize,
    pub fn init(parser: *StreamingParser, line: []const u8) TokenIterator {
        parser.reset();
        return .{ .parser = parser, .line = line, .t0 = null, .t1 = null, .offset = 0 };
    }
    pub fn next(self: *Self) !?Token {
        if (self.t1) |carry| {
            self.t1 = null;
            return carry;
        }
        while (self.offset < self.line.len) {
            try self.parser.feed(self.line[self.offset], &self.t0, &self.t1);
            self.offset += 1;
            if (self.t0) |_| return self.t0;
        }
        return null;
    }
};

test "simple test" {
    std.testing.log_level = .debug;
    const ally = std.testing.allocator;

    log("\nKEOKE", .{});
    // Managed to extract at least one event.
    const event_json = (
        \\{"event":{"content":"{\"ws://localhost:7777\":{\"read\":true,\"write\":true}}","created_at":1694743226,"id":"07d116430524028f69d5cb98b30a07e9b8facc8ac0e1a05b5b6308a4c82faa63","kind":3,"pubkey":"a68d00310ff20aa1b44512859278950b338440d79d3a4b861b7e6f4343543363","sig":"9dc7f31aa4c802529c211d6bee528bf549648d7a12c2bbc0c9aa2f1e0c4735d8443f7f6a81651e402b08dc88e2c6f947f7580629f5ec809604e209446b148711","tags":[]},"receivedAt":1694743226,"sourceInfo":"172.18.0.1","sourceType":"IP4","type":"new"}
    );
    //const EV1 = "eyJldmVudCI6eyJjb250ZW50Ijoie1wid3M6Ly9sb2NhbGhvc3Q6Nzc3N1wiOntcInJlYWRcIjp0cnVlLFwid3JpdGVcIjp0cnVlfX0iLCJjcmVhdGVkX2F0IjoxNjk0NzQzMjI2LCJpZCI6IjA3ZDExNjQzMDUyNDAyOGY2OWQ1Y2I5OGIzMGEwN2U5YjhmYWNjOGFjMGUxYTA1YjViNjMwOGE0YzgyZmFhNjMiLCJraW5kIjozLCJwdWJrZXkiOiJhNjhkMDAzMTBmZjIwYWExYjQ0NTEyODU5Mjc4OTUwYjMzODQ0MGQ3OWQzYTRiODYxYjdlNmY0MzQzNTQzMzYzIiwic2lnIjoiOWRjN2YzMWFhNGM4MDI1MjljMjExZDZiZWU1MjhiZjU0OTY0OGQ3YTEyYzJiYmMwYzlhYTJmMWUwYzQ3MzVkODQ0M2Y3ZjZhODE2NTFlNDAyYjA4ZGM4OGUyYzZmOTQ3Zjc1ODA2MjlmNWVjODA5NjA0ZTIwOTQ0NmIxNDg3MTEiLCJ0YWdzIjpbXX0sInJlY2VpdmVkQXQiOjE2OTQ3NDMyMjYsInNvdXJjZUluZm8iOiIxNzIuMTguMC4xIiwic291cmNlVHlwZSI6IklQNCIsInR5cGUiOiJuZXcifQ";
    //const Decoder = std.base64.url_safe_no_pad.Decoder;
    //var buf = try std.ArrayList(u8).initCapacity(ally, try Decoder.calcSizeForSlice(EV1));
    //defer buf.deinit();
    //buf.expandToCapacity();
    //try Decoder.decode(buf.items, EV1);
    //const event_json = buf.items;

    log("B64Decoded {s}", .{event_json});
    var filter = PowmemFilter.init();
    const cmd = try filter.doLine(event_json, ally);
    log("Filter result: {}", .{cmd});
    // try std.testing.expectEqual(@as(i32, 42), list.pop());
}
