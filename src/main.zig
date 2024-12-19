const std = @import("std");
const REPL = @import("repl.zig");

pub fn main_() !void {
    // Uncomment this block to pass the first stage
    const stdout = std.io.getStdOut().writer();
    while (true) {
        try stdout.print("$ ", .{});

        const stdin = std.io.getStdIn().reader();
        var buffer: [1024]u8 = undefined;
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        var it = std.mem.split(u8, user_input, " ");
        const cmd = it.next().?;
        // TODO: Handle user input
        std.debug.print("{s}: not found\n", .{cmd});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit() == .ok;
    const allocator = gpa.allocator();

    var repl = try REPL.init(
        allocator,
        std.io.getStdIn().reader(),
        std.io.getStdOut().writer(),
    );
    defer repl.deinit();
    try repl.loop();
    // std.process.exit(0);
}
