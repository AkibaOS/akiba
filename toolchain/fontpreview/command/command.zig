//! Font Preview Command

const std = @import("std");

const preview = @import("fontpreview");

const ArgumentError = preview.errors.arguments.ArgumentError;

const limits = preview.constants.limits;
const messages = preview.strings.messages;

pub fn run() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = general_purpose_allocator.deinit();
    const allocator = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print(messages.USAGE, .{args[0]});
        return ArgumentError.InvalidArgs;
    }

    const data = try std.fs.cwd().readFileAlloc(allocator, args[1], limits.MAX_FONT_BYTES);
    defer allocator.free(data);

    if (std.mem.eql(u8, args[2], messages.MODE_OUTLINES)) {
        return preview.dump.outlines.emit(data);
    }

    if (std.mem.eql(u8, args[2], messages.MODE_RENDER) and args.len == 8) {
        return preview.render.renderText(allocator, data, args);
    }

    std.debug.print(messages.USAGE, .{args[0]});
    return ArgumentError.InvalidArgs;
}
