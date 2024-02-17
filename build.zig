const std = @import("std");

pub const LexStep = @import("LexStep.zig");
pub const YaccStep = @import("YaccStep.zig");

pub const Variant = enum {
    core,
    devkit,
    mainline,

    pub fn name(self: Variant) []const u8 {
        return switch (self) {
            .core => "Core",
            .devkit => "DevKit",
            .mainline => "Mainline",
        };
    }
};

pub fn runAllowFailSingleLine(b: *std.Build, argv: []const []const u8) ?[]const u8 {
    var c: u8 = 0;
    if (b.runAllowFail(argv, &c, .Ignore) catch null) |result| {
        const end = std.mem.indexOf(u8, result, "\n") orelse result.len;
        return result[0..end];
    }
    return null;
}

pub fn evalChildProcessInDirectory(s: *std.Build.Step, argv: []const []const u8, cwd: []const u8) !void {
    const arena = s.owner.allocator;

    try s.handleChildProcUnsupported(null, argv);
    try std.Build.Step.handleVerbose(s.owner, null, argv);

    const result = std.ChildProcess.run(.{
        .allocator = arena,
        .argv = argv,
        .cwd = cwd,
    }) catch |err| return s.fail("unable to spawn {s}: {s}", .{ argv[0], @errorName(err) });

    if (result.stderr.len > 0) {
        try s.result_error_msgs.append(arena, result.stderr);
    }

    try s.handleChildProcessTerm(result.term, null, argv);
}

pub fn build(_: *std.Build) void {}
