//! mkafsdisk - Creates bootable Akiba disk image

const std = @import("std");

const image = @import("image/image.zig");
const strings = @import("strings/strings.zig");

const messages = strings.messages;

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = general_purpose_allocator.deinit();
    const allocator = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 4) {
        std.debug.print(messages.USAGE, .{args[0]});
        return error.InvalidArgs;
    }

    const source_location = args[1];
    const output_image_path = args[2];
    const size_megabytes = try std.fmt.parseInt(u32, args[3], 10);

    std.debug.print(messages.CREATING, .{output_image_path});
    std.debug.print(messages.SOURCE, .{source_location});
    std.debug.print(messages.SIZE, .{size_megabytes});

    try image.create.createDiskImage(allocator, source_location, output_image_path, size_megabytes);

    std.debug.print(messages.DONE, .{});
}
