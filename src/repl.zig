const std = @import("std");
const Allocator = std.mem.Allocator;
const FileReader = std.fs.File.Reader;
const FileWriter = std.fs.File.Writer;
const SplitIterator = std.mem.SplitIterator(u8, .sequence);

const CommandInfo = struct {
    name: []const u8,
    arity: i8, //127 args including command name itself.
};

looping: bool = true,
allocator: Allocator,
reader: FileReader,
writer: FileWriter,
commands: std.StringHashMap(CommandInfo),

const REPL = @This();

pub fn init(allocator: Allocator, reader: FileReader, writer: FileWriter) !REPL {
    var result = REPL{ .allocator = allocator, .reader = reader, .writer = writer, .commands = std.StringHashMap(CommandInfo).init(allocator) };
    try result.commands.put("exit", .{ .name = "exit", .arity = 2 });
    return result;
}

pub fn deinit(self: *REPL) void {
    self.commands.deinit();
    // self.* = undefined;
}

pub fn loop(self: *REPL) !void {
    while (self.looping) {
        try self.writer.print("$ ", .{});
        //read
        var buffer: [1024]u8 = undefined;
        const user_input = try self.reader.readUntilDelimiter(&buffer, '\n');
        var it = std.mem.split(u8, user_input, " ");
        const cmd = it.next();
        if (cmd == null) {
            return error.InvalidInput;
        }
        const cmd_info = self.commands.getPtr(cmd.?);
        if (cmd_info) |info| {
            var resolvedCommand = Command.init(info, &it);
            const result = resolvedCommand.evaluate();
            self.looping = result.looping;
        } else {
            try self.writer.print("{s}: command not found\n", .{cmd.?});
        }
        //evaluate
        //print
        // try self.writer.print("{s}\n", .{user_input});
    }
    // std.process.exit(0);
}
// Read Evaluate Print Loop

const CommandResult = struct {
    looping: bool = true,
};

const ExitCommand = struct {
    status: u8,

    pub fn init(
        it: *SplitIterator,
    ) ExitCommand {
        var s: u8 = 0;
        if (it.next()) |n| {
            // std.debug.print("parsing {s}...\n", .{n});
            s = std.fmt.parseInt(u8, n, 10) catch 0;
            // std.debug.print("parsed: {d}\n", .{s});
            // std.debug.print("parsed: {any}\n", .{s});
        }
        return .{ .status = s };
    }

    pub fn evaluate(self: *ExitCommand) CommandResult {
        std.process.exit(self.status);
        return .{ .looping = false };
    }
};

const Command = union(enum) {
    exit: ExitCommand,

    pub fn init(cmdInfo: *CommandInfo, it: *SplitIterator) Command {
        var cmd: Command = undefined;
        if (std.ascii.eqlIgnoreCase(cmdInfo.name, "exit")) {
            cmd = toExitCommand(it);
        }
        return cmd;
    }

    fn toExitCommand(it: *SplitIterator) Command {
        return .{ .exit = ExitCommand.init(it) };
    }

    pub fn evaluate(self: *Command) CommandResult {
        switch (self.*) {
            .exit => |exit| {
                var _exit = exit;
                return _exit.evaluate();
            },
            // else => |cmd| {
            //     var kmd = cmd;
            //     std.debug.print("who am i? {any}\n", .{kmd});
            //     return kmd.evaluate();
            // },
            // .exit => |cmd| {
            //     std.process.exit(cmd.status);
            // },
        }
    }
};
