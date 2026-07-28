//! fontpreview - Renders Akiba font output on the host for verification

const std = @import("std");

pub const dump = @import("dump/dump.zig");
pub const strings = @import("strings/strings.zig");

const messages = strings.messages;

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = general_purpose_allocator.deinit();
    const allocator = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.debug.print(messages.USAGE, .{args[0]});
        return error.InvalidArgs;
    }

    const data = try std.fs.cwd().readFileAlloc(allocator, args[1], MAX_FONT_BYTES);
    defer allocator.free(data);

    try dump.outlines.emit(data);
}

const MAX_FONT_BYTES: usize = 32 * 1024 * 1024;
