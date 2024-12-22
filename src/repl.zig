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
builtins: std.StringHashMap(CommandInfo),
path: ?[]const u8 = undefined,

const REPL = @This();

var exec_command_info: CommandInfo = .{ .name = "exec", .arity = -2 };

pub fn init(allocator: Allocator, reader: FileReader, writer: FileWriter) !REPL {
    var result = REPL{ .allocator = allocator, .reader = reader, .writer = writer, .builtins = std.StringHashMap(CommandInfo).init(allocator) };
    try result.builtins.put("exit", .{ .name = "exit", .arity = 2 });
    try result.builtins.put("echo", .{ .name = "echo", .arity = -2 });
    try result.builtins.put("type", .{ .name = "type", .arity = 2 });
    result.path = try std.process.getEnvVarOwned(allocator, "PATH");
    // std.debug.print("Inferred PATH = {s}\n", .{result.path.?});
    return result;
}

pub fn deinit(self: *REPL) void {
    self.builtins.deinit();
    if (self.path) |p| {
        self.allocator.free(p);
    }
    // self.* = undefined;
}

pub fn is_builtin(self: *REPL, cmd: []const u8) bool {
    return self.builtins.contains(cmd);
}

fn exutableOwned(self: *REPL, cmd: []const u8) !?[]u8 {
    if (self.path) |p| {
        var it = std.mem.split(u8, p, ":");
        while (it.next()) |dir| {
            const full_path = try std.fs.path.join(self.allocator, &[_][]const u8{ dir, cmd });
            defer self.allocator.free(full_path);

            const file = std.fs.openFileAbsolute(full_path, .{ .mode = .read_only }) catch continue;
            defer file.close();

            const mode = file.mode() catch continue;
            const is_executable = mode & 0b001 != 0;
            if (!is_executable) continue;

            // try self.repl.writer.print("{s} is {s}\n", .{ self.cmd, full_path });
            return try self.allocator.dupe(u8, full_path);
        }
    }
    return null;
}

fn is_executableOwned(self: *REPL, cmd: []const u8) !?[]u8 {
    // std.log.info("PATH={s}", .{self.path.?});
    // std.log.err("PATH={s}", .{self.path.?});
    if (self.path) |p| {
        var pit = std.mem.split(u8, p, ":");
        while (pit.next()) |path| {
            // std.log.err("iterating path: {s}\n", .{path});
            var dir = std.fs.openDirAbsolute(path, .{
                // .iterate = true,
                // .no_follow = true,
            }) catch |err| {
                // std.log.info("[path:{s}][open error]: {}\n", .{ path, err });
                switch (err) {
                    inline else => {
                        continue;
                    },
                }
                continue;
            };
            defer dir.close();

            var walker = try dir.walk(self.allocator);
            defer walker.deinit();

            // while (walker.next() catch |err| {
            //     std.log.err("walk error: {}\n", .{err});
            // }) |entry| {

            outer: while (true) {
                const ent = walker.next() catch |err| {
                    // std.log.err("[walker err]: {}\n", .{err});
                    switch (err) {
                        inline else => {
                            continue;
                        },
                    }
                    continue;
                };
                if (ent == null) break :outer;
                if (ent) |entry| {
                    if (entry.kind == .file and std.mem.eql(u8, entry.basename, cmd)) {
                        const full_path = try std.fs.path.join(self.allocator, &.{ path, entry.path });

                        const file = std.fs.openFileAbsolute(full_path, .{}) catch continue;
                        defer file.close();
                        const mode = file.mode() catch continue;

                        if ((mode & 0b001) == 1) {
                            return full_path;
                        } else {
                            continue;
                        }
                    }
                }
            }

            // while (try walker.next()) |entry| {
            //     if (entry.kind == .file and std.mem.eql(u8, entry.basename, cmd)) {
            //         const full_path = try std.fs.path.join(self.allocator, &.{ path, entry.path });

            //         const file = std.fs.openFileAbsolute(full_path, .{}) catch continue;
            //         defer file.close();
            //         const mode = file.mode() catch continue;

            //         if ((mode & 0b001) == 1) {
            //             return full_path;
            //         } else {
            //             continue;
            //         }
            //     }
            // }
        }
    }
    return null;
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
        var cmd_info = self.builtins.getPtr(cmd.?);
        if (cmd_info == null) {
            cmd_info = &exec_command_info;
            it.reset();
        }
        if (cmd_info) |info| {
            var resolvedCommand = try Command.init(self, info, &it);
            defer resolvedCommand.deinit();
            try resolvedCommand.evaluate();
            try resolvedCommand.print();
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

const ExecCommand = struct {
    repl: *REPL,
    cmd: []const u8,
    args: [][]const u8,

    pub fn init(repl: *REPL, it: *SplitIterator) !ExecCommand {
        var cmd: []const u8 = undefined;
        if (it.next()) |arg| {
            cmd = try repl.allocator.dupe(u8, arg);
        }
        var list = std.ArrayList([]const u8).init(repl.allocator);
        while (it.next()) |fragment| {
            try list.append(fragment);
        }
        const args = try list.toOwnedSlice();
        return .{
            .repl = repl,
            .cmd = cmd,
            .args = args,
        };
    }

    pub fn evaluate(self: *ExecCommand) !void {
        const exec = self.repl.exutableOwned(self.cmd) catch {
            try self.repl.writer.print("{s}: not found\n", .{self.cmd});
            return;
        };
        if (exec) |exe| {
            defer self.repl.allocator.free(exe);
            var program = std.ArrayList([]const u8).init(self.repl.allocator);
            defer program.deinit();

            //add exe name
            try program.append(exe);
            for (self.args) |arg| {
                try program.append(arg);
            }

            const argv = try program.toOwnedSlice();
            defer self.repl.allocator.free(argv);

            var cp = std.process.Child.init(argv, self.repl.allocator);
            _ = try cp.spawnAndWait();
        } else {
            try self.repl.writer.print("{s}: not found\n", .{self.cmd});
        }
    }

    pub fn deinit(self: *ExecCommand) void {
        self.repl.allocator.free(self.cmd);
        self.repl.allocator.free(self.args);
    }

    pub fn print(_: *ExecCommand) !void {
        // const output = try std.mem.join(self.repl.allocator, " ", self.args);
        // defer self.repl.allocator.free(output);
        // try self.repl.writer.print("EXEC: {s} {s}\n", .{ self.cmd, output });
    }
};

const TypeCommand = struct {
    repl: *REPL,
    cmd: []const u8,

    pub fn init(repl: *REPL, it: *SplitIterator) !TypeCommand {
        var cmd: []const u8 = undefined;
        if (it.next()) |arg| {
            cmd = try repl.allocator.dupe(u8, arg);
        }
        return .{ .repl = repl, .cmd = cmd };
    }

    pub fn deinit(self: *TypeCommand) void {
        self.repl.allocator.free(self.cmd);
    }

    pub fn evaluate(_: *TypeCommand) !void {
        //no op
    }

    pub fn print(self: *TypeCommand) !void {
        if (self.repl.is_builtin(self.cmd)) {
            try self.repl.writer.print("{s} is a shell builtin\n", .{self.cmd});
        } else {
            //lookup PATH variable
            const found = try self.repl.exutableOwned(self.cmd);
            if (found) |full_path| {
                defer self.repl.allocator.free(full_path);
                try self.repl.writer.print("{s} is {s}\n", .{ self.cmd, full_path });
            } else {
                try self.repl.writer.print("{s}: not found\n", .{self.cmd});
            }
        }
    }
};

const EchoCommand = struct {
    repl: *REPL,
    args: [][]const u8,

    pub fn init(repl: *REPL, it: *SplitIterator) !EchoCommand {
        var list = std.ArrayList([]const u8).init(repl.allocator);
        while (it.next()) |fragment| {
            try list.append(fragment);
        }
        const args = try list.toOwnedSlice();
        return .{ .repl = repl, .args = args };
    }

    pub fn evaluate(_: *EchoCommand) !void {
        //no op
    }

    pub fn deinit(self: *EchoCommand) void {
        self.repl.allocator.free(self.args);
    }

    pub fn print(self: *EchoCommand) !void {
        const output = try std.mem.join(self.repl.allocator, " ", self.args);
        defer self.repl.allocator.free(output);
        try self.repl.writer.print("{s}\n", .{output});
    }
};

const ExitCommand = struct {
    repl: *REPL,
    status: u8,

    pub fn init(repl: *REPL, it: *SplitIterator) !ExitCommand {
        var s: u8 = 0;
        if (it.next()) |n| {
            s = std.fmt.parseInt(u8, n, 10) catch 0;
        }
        return .{ .repl = repl, .status = s };
    }

    pub fn evaluate(self: *ExitCommand) !void {
        self.repl.looping = false;
        std.process.exit(self.status);
    }

    pub fn deinit(_: *ExitCommand) void {
        //noop
    }

    pub fn print(_: *ExitCommand) !void {}
};

const Command = union(enum) {
    exit: ExitCommand,
    echo: EchoCommand,
    type: TypeCommand,
    exec: ExecCommand,

    pub fn init(repl: *REPL, cmdInfo: *CommandInfo, it: *SplitIterator) !Command {
        var cmd: Command = undefined;
        if (std.ascii.eqlIgnoreCase(cmdInfo.name, "exit")) {
            cmd = try toExitCommand(repl, it);
        }
        if (std.ascii.eqlIgnoreCase(cmdInfo.name, "echo")) {
            cmd = try toEchoCommand(repl, it);
        }
        if (std.ascii.eqlIgnoreCase(cmdInfo.name, "type")) {
            cmd = try toTypeCommand(repl, it);
        }
        if (std.ascii.eqlIgnoreCase(cmdInfo.name, "exec")) {
            cmd = try toExecCommand(repl, it);
        }
        return cmd;
    }

    fn toExitCommand(repl: *REPL, it: *SplitIterator) !Command {
        return .{ .exit = try ExitCommand.init(repl, it) };
    }

    fn toEchoCommand(repl: *REPL, it: *SplitIterator) !Command {
        return .{ .echo = try EchoCommand.init(repl, it) };
    }

    fn toTypeCommand(repl: *REPL, it: *SplitIterator) !Command {
        return .{ .type = try TypeCommand.init(repl, it) };
    }

    fn toExecCommand(repl: *REPL, it: *SplitIterator) !Command {
        return .{ .exec = try ExecCommand.init(repl, it) };
    }

    pub fn print(self: *Command) !void {
        switch (self.*) {
            inline else => |cmd| {
                var kmd = cmd;
                return kmd.print();
            },
        }
    }

    pub fn evaluate(self: *Command) !void {
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
