const std = @import("std");

const is = std.io.getStdIn().reader();
pub fn main() !void {
    var ai = std.process.args();
    std.debug.print("Process args...begin\n", .{});
    while (ai.next()) |n| {
        std.debug.print("{s}\n", .{n});
    }
    std.debug.print("Process args...end\n", .{});
    var buffer: [1024]u8 = undefined;
    const bytes = try is.readUntilDelimiter(&buffer, '\n');
    std.debug.print("Got input: {s}\n", .{bytes});
}
