const std = @import("std");

pub const ArgIterator = struct {
    buffer: []const u8,
    index: usize = 0,

    const Self = @This();

    pub fn next(self: *Self) ?[]const u8 {
        if (self.index == self.buffer.len)
            return null;

        var single_quotes: bool = false;
        var double_quotes: bool = false;
        const start = self.index;
        while (self.index < self.buffer.len) : (self.index += 1) {
            const c = self.buffer[self.index];
            if (c == '\'' and !double_quotes) {
                single_quotes = !single_quotes;
                continue;
            } else if (c == '"' and !single_quotes) {
                double_quotes = !double_quotes;
                continue;
            } else if (std.ascii.isWhitespace(c) and !single_quotes and !double_quotes) {
                break;
            }
        }
        if (single_quotes or double_quotes) {
            std.io.getStdErr().writer().print("Error: Unmatched quotes\n", .{}) catch unreachable;
        }
        defer {
            if (self.index < self.buffer.len) self.index += 1;
        }
        return std.mem.replaceScalar(u8, self.buffer[start..self.index], '\'', '');
    }

    pub fn next_0(self: *Self) ?[]const u8 {
        if (self.index == self.buffer.len)
            return null;
        const c = self.buffer[self.index];
        const needle: u8 = if (c == '\'' or c == '"') c else ' ';
        std.debug.print("index: {d} needle: \"{c}\"", .{ self.index, needle });
        if (needle != ' ') self.index += 1;
        const start = self.index;

        while (self.index < self.buffer.len and self.buffer[self.index] != needle) : (self.index += 1) {}

        defer {
            // if (needle != ' ') self.index += 1;
            if (self.index < self.buffer.len) self.index += 1;
        }
        std.debug.print("range: [{d}..{d}]\n", .{ start, self.index });

        return self.buffer[start..self.index];
    }
};

pub fn main() !void {
    // const str = "A quick ' brown ' fox jumps over a \"lazy  \" 'dog'";
    const str = "'world     script' 'test''example'";
    // "world     script testexample"
    var it = ArgIterator{ .buffer = str };
    while (it.next()) |n| {
        std.debug.print("[{s}]\n", .{n});
    }
}
