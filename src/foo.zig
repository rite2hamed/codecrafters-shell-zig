const std = @import("std");
const Command = struct {
    name: []const u8,
    evaluate: fn (cmd: *const Command) void,
};

pub fn main() !void {
    std.debug.print("Hola! \n", .{});

    const echo: Command = .{ .name = "echo", .evaluate = struct {
        fn eval(self: *const Command) void {
            std.debug.print("Hola {s} from callback!\n", .{self.name});
        }
    }.eval };

    echo.evaluate(&echo);
}
