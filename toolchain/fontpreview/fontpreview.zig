//! fontpreview - Renders Akiba font output on the host for verification

const std = @import("std");

pub const dump = @import("dump/dump.zig");
pub const render = @import("render/render.zig");
pub const strings = @import("strings/strings.zig");

const messages = strings.messages;

const MAX_FONT_BYTES: usize = 32 * 1024 * 1024;

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = general_purpose_allocator.deinit();
    const allocator = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print(messages.USAGE, .{args[0]});
        return error.InvalidArgs;
    }

    const data = try std.fs.cwd().readFileAlloc(allocator, args[1], MAX_FONT_BYTES);
    defer allocator.free(data);

    if (std.mem.eql(u8, args[2], messages.MODE_OUTLINES)) {
        return dump.outlines.emit(data);
    }

    if (std.mem.eql(u8, args[2], messages.MODE_RENDER) and args.len == 8) {
        return renderText(allocator, data, args);
    }

    std.debug.print(messages.USAGE, .{args[0]});
    return error.InvalidArgs;
}

fn renderText(allocator: std.mem.Allocator, data: []const u8, args: [][:0]u8) !void {
    const face = try @import("shared").font.face.load(data);

    const pixel_size = try std.fmt.parseInt(i32, args[3], 10);
    const text = args[4];
    const width = try std.fmt.parseInt(i32, args[5], 10);
    const height = try std.fmt.parseInt(i32, args[6], 10);

    const pixels = try allocator.alloc(u8, @intCast(width * height));
    defer allocator.free(pixels);
    @memset(pixels, 0);

    var canvas = render.Canvas{ .Pixels = pixels, .Width = width, .Height = height };

    const baseline = @divTrunc(@as(i32, face.Ascender) * pixel_size, @as(i32, face.UnitsPerEm));
    try render.drawText(&face, text, pixel_size, 0, baseline, &canvas);
    try render.writePortableGrayMap(&canvas, args[7]);
}
