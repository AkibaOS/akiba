//! Plan The Exact Installed Driver ELF With The Production Loader

const std = @import("std");

const memory = @import("common").constants.memory;
const weaver = @import("weaver");

pub fn prove(bytes: []const u8) !void {
    const allocator = std.testing.allocator;
    const empty: u8 = 0;
    var graph = try weaver.library.load.collect.collect(allocator, .{ .Context = &empty, .ReadFromOrigin = noLibrary }, bytes);
    defer graph.deinit();
    var placement = try weaver.image.place.place(allocator, &graph, null, .{
        .MinimumAddress = memory.sizes.PAGE_SIZE,
        .MaximumAddress = memory.layout.USER_SPACE_END,
        .MaximumPages = memory.layout.USER_SPACE_END / memory.sizes.PAGE_SIZE,
    }, &.{});
    defer placement.deinit();
    var linked = try weaver.link.plan.plan(allocator, &placement);
    defer linked.deinit();
    try std.testing.expect(placement.Executable.Image.Entry != 0);
}

fn noLibrary(_: *const anyopaque, _: std.mem.Allocator, _: []const []const u8, _: []const u8) weaver.library.errors.library.ReadError!?[]u8 {
    return null;
}
