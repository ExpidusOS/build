const std = @import("std");
const YaccStep = @This();
const evalChildProcess = @import("build.zig").evalChildProcessInDirectory;

step: std.Build.Step,
source: std.Build.LazyPath,
isCpp: bool,
output_source: std.Build.GeneratedFile,
output_header: std.Build.GeneratedFile,

pub fn create(b: *std.Build, source: std.Build.LazyPath, isCpp: bool) *YaccStep {
    const self = b.allocator.create(YaccStep) catch @panic("OOM");
    self.* = .{
        .step = std.Build.Step.init(.{
            .id = .custom,
            .name = b.fmt("Yacc {s}", .{source.getDisplayName()}),
            .owner = b,
            .makeFn = make,
        }),
        .source = source,
        .isCpp = isCpp,
        .output_source = .{ .step = &self.step },
        .output_header = .{ .step = &self.step },
    };

    source.addStepDependencies(&self.step);
    return self;
}

fn make(step: *std.Build.Step, _: *std.Progress.Node) anyerror!void {
    const b = step.owner;
    const self = @fieldParentPtr(YaccStep, "step", step);

    var man = b.graph.cache.obtain();
    defer man.deinit();

    _ = try man.addFile(self.source.getPath2(b, step), null);

    const name = std.fs.path.stem(self.source.getPath2(b, step));
    const sourceExt: []const u8 = if (self.isCpp) "cpp" else "c";
    const headerExt: []const u8 = if (self.isCpp) "hpp" else "h";

    if (try step.cacheHit(&man)) {
        const digest = man.final();
        self.output_source.path = try b.cache_root.join(b.allocator, &.{ "o", &digest, b.fmt("{s}.{s}", .{ name, sourceExt }) });
        self.output_header.path = try b.cache_root.join(b.allocator, &.{ "o", &digest, b.fmt("{s}.{s}", .{ name, headerExt }) });
        return;
    }

    const digest = man.final();
    const cache_path = "o" ++ std.fs.path.sep_str ++ digest;

    var cache_dir = b.cache_root.handle.makeOpenPath(cache_path, .{}) catch |err| {
        return step.fail("unable to make path '{}{s}': {s}", .{
            b.cache_root, cache_path, @errorName(err),
        });
    };
    defer cache_dir.close();

    const cmd = try b.findProgram(&.{"yacc"}, &.{});

    try evalChildProcess(step, &.{
        cmd,
        self.source.getPath2(b, step),
        "-o",
        b.fmt("{s}.{s}", .{ name, sourceExt }),
        "-H",
        "-Wno-yacc",
    }, try b.cache_root.join(b.allocator, &.{ "o", &digest }));

    self.output_source.path = try b.cache_root.join(b.allocator, &.{ "o", &digest, b.fmt("{s}.{s}", .{ name, sourceExt }) });
    self.output_header.path = try b.cache_root.join(b.allocator, &.{ "o", &digest, b.fmt("{s}.{s}", .{ name, headerExt }) });

    try step.writeManifest(&man);
}
