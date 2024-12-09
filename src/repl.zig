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
    try result.commands.put("echo", .{ .name = "echo", .arity = -1 });
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
            var resolvedCommand = try Command.init(self.allocator, info, &it);
            defer resolvedCommand.deinit();
            const result = resolvedCommand.evaluate();
            self.looping = result.looping;
            try resolvedCommand.print(self.writer);
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

const EchoCommand = struct {
    allocator: Allocator,
    args: [][]const u8,

    pub fn init(allocator: Allocator, it: *SplitIterator) !EchoCommand {
        var list = std.ArrayList([]const u8).init(allocator);
        while (it.next()) |fragment| {
            try list.append(fragment);
        }
        const args = try list.toOwnedSlice();
        return .{ .allocator = allocator, .args = args };
    }

    pub fn evaluate(_: *EchoCommand) CommandResult {
        //no op
        return .{};
    }

    pub fn deinit(self: *EchoCommand) void {
        self.allocator.free(self.args);
    }

    pub fn print(self: *EchoCommand, writer: FileWriter) !void {
        const output = try std.mem.join(self.allocator, " ", self.args);
        defer self.allocator.free(output);
        try writer.print("{s}\n", .{output});
    }
};

const ExitCommand = struct {
    allocator: Allocator,
    status: u8,

    pub fn init(
        allocator: Allocator,
        it: *SplitIterator,
    ) !ExitCommand {
        var s: u8 = 0;
        if (it.next()) |n| {
            // std.debug.print("parsing {s}...\n", .{n});
            s = std.fmt.parseInt(u8, n, 10) catch 0;
            // std.debug.print("parsed: {d}\n", .{s});
            // std.debug.print("parsed: {any}\n", .{s});
        }
        return .{ .allocator = allocator, .status = s };
    }

    pub fn evaluate(self: *ExitCommand) CommandResult {
        std.process.exit(self.status);
        return .{ .looping = false };
    }

    pub fn deinit(_: *ExitCommand) void {
        //noop
    }

    pub fn print(_: *ExitCommand, _: FileWriter) !void {}
};

const Command = union(enum) {
    exit: ExitCommand,
    echo: EchoCommand,

    pub fn init(allocator: Allocator, cmdInfo: *CommandInfo, it: *SplitIterator) !Command {
        var cmd: Command = undefined;
        if (std.ascii.eqlIgnoreCase(cmdInfo.name, "exit")) {
            cmd = try toExitCommand(allocator, it);
        }
        if (std.ascii.eqlIgnoreCase(cmdInfo.name, "echo")) {
            cmd = try toEchoCommand(allocator, it);
        }
        return cmd;
    }

    fn toExitCommand(allocator: Allocator, it: *SplitIterator) !Command {
        return .{ .exit = try ExitCommand.init(allocator, it) };
    }

    fn toEchoCommand(allocator: Allocator, it: *SplitIterator) !Command {
        return .{ .echo = try EchoCommand.init(allocator, it) };
    }

    pub fn print(self: *Command, writer: FileWriter) !void {
        switch (self.*) {
            inline else => |cmd| {
                var kmd = cmd;
                return kmd.print(writer);
            },
        }
    }

    pub fn evaluate(self: *Command) CommandResult {
        switch (self.*) {
            // .exit => |exit| {
            //     var _exit = exit;
            //     return _exit.evaluate();
            // },
            inline else => |cmd| {
                var kmd = cmd;
                return kmd.evaluate();
            },
        }
    }

    pub fn deinit(self: *Command) void {
        switch (self.*) {
            inline else => |cmd| {
                var kmd = cmd;
                return kmd.deinit();
            },
        }
    }
};
