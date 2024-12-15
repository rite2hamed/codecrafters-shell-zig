const std = @import("std");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit() == .ok;
    const allocator = gpa.allocator();

    var dir = try std.fs.openDirAbsolute("/Users/hamed/devspace/ziggy/codecrafters-shell-zig/zig-out/bin", .{});
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind == .file) {
            // const stat = try entry.dir.stat();
            // const mode = stat.mode;
            std.debug.print("dir = {any} BN = {s}, Entry: /Users/hamed/devspace/ziggy/codecrafters-shell-zig/zig-out/bin/{s}\n", .{
                entry.dir,
                entry.basename,
                entry.path,
            });
        }
    }
    std.debug.print("Hello world!\n", .{});
}
