const std = @import("std");
const Allocator = std.mem.Allocator;
const FileReader = std.fs.File.Reader;
const FileWriter = std.fs.File.Writer;
const SplitIterator = std.mem.SplitIterator(u8, .sequence);

const REPL2 = @This();

looping: bool = true,
allocator: Allocator,
reader: FileReader,
writer: FileWriter,
path: ?[]const u8 = undefined,
home: []const u8 = undefined,
cwd: []const u8 = undefined,
builtins: std.StringHashMap(Command),

const Command = struct {
    name: []const u8,
    arity: i8, //127 args including name, -2 indicates var args
    eval: fn (self: *const Command, repl: *REPL2) anyerror!void,
};

pub fn init(allocator: Allocator, reader: FileReader, writer: FileWriter) !REPL2 {
    var result = REPL2{
        .allocator = allocator,
        .reader = reader,
        .writer = writer,
        .builtins = std.StringHashMap(Command).init(allocator),
    };
    try result.builtins.put("exit", .{ .name = "exit", .arity = 2, .eval = struct {
        fn eval(self: *const Command, repl: *REPL2) !void {
            _ = self;
            _ = repl;
        }
    }.eval });
    result.path = try std.process.getEnvVarOwned(allocator, "PATH");
    result.home = try std.process.getEnvVarOwned(allocator, "HOME");
    result.cwd = try std.process.getCwdAlloc(allocator);
    return result;
}
