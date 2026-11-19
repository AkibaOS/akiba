//! Disk Image Command

const std = @import("std");

const tool = @import("mkafsdisk");

const messages = tool.strings.messages;
const ArgumentError = tool.errors.arguments.ArgumentError;
const Record = tool.types.progress.Record;

pub const display = @import("display.zig");

pub fn run() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = general_purpose_allocator.deinit();
    const allocator = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const stream = args.len == 5 and std.mem.eql(u8, args[4], messages.PROGRESS_STREAM);
    const label: ?[]const u8 = if (args.len == 6 and std.mem.eql(u8, args[4], messages.IMAGE_LABEL) and args[5].len != 0) args[5] else null;
    if (args.len != 4 and !stream and label == null) {
        std.debug.print(messages.USAGE, .{args[0]});
        return ArgumentError.InvalidArgs;
    }

    const source_location = args[1];
    const output_image_path = args[2];
    const size_megabytes = try std.fmt.parseInt(u32, args[3], 10);
    if (stream) {
        const stats = try tool.image.create.createDiskImageReported(allocator, source_location, output_image_path, size_megabytes, .{
            .Context = null,
            .UpdateFn = reportStream,
        });
        return std.fs.File.stdout().writeAll(&stats.encode());
    }

    const name = std.fs.path.basename(label orelse output_image_path);
    var progress = display.Progress.init(name);
    defer progress.end();
    const stats = try tool.image.create.createDiskImageReported(allocator, source_location, output_image_path, size_megabytes, .{
        .Context = &progress,
        .UpdateFn = reportTerminal,
    });
    display.report(name, output_image_path, source_location, stats);
}

fn reportTerminal(context: ?*anyopaque, written: u32, total: u32) !void {
    const progress: *display.Progress = @ptrCast(@alignCast(context.?));
    progress.update(written, total);
}

fn reportStream(_: ?*anyopaque, written: u32, total: u32) !void {
    const record: Record = .{ .Written = written, .Total = total };
    try std.fs.File.stdout().writeAll(&record.encode());
}
