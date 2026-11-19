//! Disk Image Command

const std = @import("std");

const tool = @import("mkafsdisk");

const ArgumentError = tool.errors.arguments.ArgumentError;
const Record = tool.types.progress.Record;
const messages = tool.strings.messages;

pub fn run() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = general_purpose_allocator.deinit();
    const allocator = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const stream = args.len == 5 and std.mem.eql(u8, args[4], messages.PROGRESS_STREAM);
    if (args.len != 4 and !stream) {
        std.debug.print(messages.USAGE, .{args[0]});
        return ArgumentError.InvalidArgs;
    }

    const source_location = args[1];
    const output_image_path = args[2];
    const size_megabytes = try std.fmt.parseInt(u32, args[3], 10);
    if (stream) {
        return tool.image.create.createDiskImageObserved(allocator, source_location, output_image_path, size_megabytes, .{
            .Context = null,
            .UpdateFn = reportStream,
        });
    }

    const name = try std.fmt.allocPrint(allocator, messages.PACKING, .{std.fs.path.basename(output_image_path)});
    defer allocator.free(name);
    var progress = std.Progress.start(.{ .root_name = name });
    defer progress.end();
    try tool.image.create.createDiskImageObserved(allocator, source_location, output_image_path, size_megabytes, .{
        .Context = &progress,
        .UpdateFn = reportTerminal,
    });
}

fn reportTerminal(context: ?*anyopaque, written: u32, total: u32) !void {
    const progress: *std.Progress.Node = @ptrCast(@alignCast(context.?));
    progress.setEstimatedTotalItems(total);
    progress.setCompletedItems(written);
}

fn reportStream(_: ?*anyopaque, written: u32, total: u32) !void {
    const record: Record = .{ .Written = written, .Total = total };
    try std.fs.File.stdout().writeAll(&record.encode());
}
