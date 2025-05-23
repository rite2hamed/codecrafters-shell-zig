const std = @import("std");

pub const ArgIterator = struct {
    buffer: []const u8,
    index: usize = 0,

    const Self = @This();

    pub fn next(self: *Self) ?[]const u8 {
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
