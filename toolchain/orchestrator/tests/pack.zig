//! Cached Test Images With Parent-Owned Unit Progress

const std = @import("std");

const display = @import("../../mkafsdisk/command/display.zig");
const messages = @import("../../mkafsdisk/strings/messages.zig");
const paths = @import("../strings/paths.zig");
const steps = @import("../strings/steps.zig");
const Pack = @import("../types/pack.zig").Pack;
const Record = @import("../../mkafsdisk/types/progress.zig").Record;
const Report = @import("../../mkafsdisk/types/report.zig").Report;

pub fn image(builder: *std.Build, stage: *std.Build.Step.WriteFile, packer: *std.Build.Step.Compile, name: []const u8) std.Build.LazyPath {
    const pack = builder.allocator.create(Pack) catch @panic("OOM");
    pack.* = .{
        .Step = std.Build.Step.init(.{ .id = .custom, .name = builder.fmt(messages.PACKING, .{name}), .owner = builder, .makeFn = make }),
        .Source = stage.getDirectory(),
        .Tool = packer.getEmittedBin(),
        .ImageName = name,
        .Output = .{ .step = &pack.Step },
    };
    pack.Source.addStepDependencies(&pack.Step);
    pack.Tool.addStepDependencies(&pack.Step);
    return .{ .generated = .{ .file = &pack.Output } };
}

fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) !void {
    const pack: *Pack = @fieldParentPtr("Step", step);
    const builder = step.owner;
    const source = pack.Source.getPath2(builder, step);
    const executable = pack.Tool.getPath2(builder, step);
    var manifest = builder.graph.cache.obtain();
    defer manifest.deinit();
    manifest.hash.addBytes(messages.PROGRESS_STREAM);
    manifest.hash.addBytes(source);
    manifest.hash.addBytes(pack.ImageName);
    manifest.hash.addBytes(paths.GUEST_IMAGE_MB);
    _ = try manifest.addFile(executable, null);
    const hit = try step.cacheHitAndWatch(&manifest);
    const digest = manifest.final();
    const directory = builder.pathJoin(&.{ paths.CACHE_OBJECT_DIRECTORY, &digest });
    const output = try builder.cache_root.join(builder.allocator, &.{ directory, pack.ImageName });
    pack.Output.path = output;
    const published = if (hit) null else fresh: {
        try builder.cache_root.handle.makePath(directory);
        break :fresh try emit(step, options, pack.ImageName, executable, source, output);
    };
    const info = std.fs.cwd().statFile(output) catch return step.fail(steps.PACK_IMAGE_MISSING, .{output});
    if (info.kind != .file) return step.fail(steps.PACK_IMAGE_MISSING, .{output});
    if (published) |result| {
        if (info.size != result.SizeBytes) return step.fail(steps.PACK_STATISTICS, .{output});
        try step.writeManifestAndWatch(&manifest);
        display.report(pack.ImageName, output, source, result);
    }
}

fn emit(step: *std.Build.Step, options: std.Build.Step.MakeOptions, name: []const u8, executable: []const u8, source: []const u8, output: []const u8) !Report {
    const arguments = &.{ executable, source, output, paths.GUEST_IMAGE_MB, messages.PROGRESS_STREAM };
    var progress = display.Progress.init(name);
    defer progress.end();
    var child = std.process.Child.init(arguments, options.gpa);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Inherit;
    child.spawn() catch |failure| return step.fail(steps.PACK_EXECUTION, .{@errorName(failure)});
    var reaped = false;
    errdefer if (!reaped) {
        _ = child.kill() catch {};
    };
    const stats = observe(child.stdout.?, options.progress_node, &progress) catch |failure| return step.fail(steps.PACK_PROGRESS, .{@errorName(failure)});
    const result = try child.wait();
    reaped = true;
    if (result != .Exited or result.Exited != 0) return step.fail(steps.PACK_EXIT, .{result});
    return stats orelse return step.fail(steps.PACK_INCOMPLETE, .{});
}

fn observe(pipe: std.fs.File, node: std.Progress.Node, progress: *display.Progress) !?Report {
    var last: ?Record = null;
    var bytes: [Record.BYTES]u8 = undefined;
    while (true) {
        const count = try pipe.readAll(&bytes);
        if (count == 0) return null;
        if (count != bytes.len) return error.TruncatedProgressRecord;
        const event = Record.decode(&bytes);
        if (!event.follows(last)) return error.UnorderedProgressRecord;
        if (last == null) node.setEstimatedTotalItems(event.Total);
        node.setCompletedItems(event.Written);
        progress.update(event.Written, event.Total);
        if (event.Written == event.Total) return readReport(pipe, event.Total);
        last = event;
    }
}

fn readReport(pipe: std.fs.File, units: u32) !?Report {
    var raw: [Report.BYTES]u8 = undefined;
    const count = try pipe.readAll(&raw);
    if (count == 0) return null;
    if (count != raw.len) return error.TruncatedImageStatistics;
    var tail: [1]u8 = undefined;
    if (try pipe.readAll(&tail) != 0) return error.UnexpectedImageStatistics;
    const stats = Report.decode(&raw);
    if (stats.Units != units or stats.FreeCells > stats.TotalCells) return error.InvalidImageStatistics;
    return stats;
}
