//! Shared World Syntax And Ownership Regression Entry

const std = @import("std");

const checks = @import("tests").fast.strings.world.grammar;
const space = @import("shared").world.lex.space;
const syntax = @import("shared").world.parse.syntax;
const values = @import("shared").world.parse.values;

test "shared World reads the dialect and coerces only valid typed values" {
    try accepts(std.testing.allocator);
}

test "shared World refuses malformed syntax and cleans up caller-owned arena allocations" {
    try std.testing.expectError(error.InvalidWorld, space.width(&.{}));
    try std.testing.checkAllAllocationFailures(std.testing.allocator, accepts, .{});
    for ([_][]const u8{ checks.EXTRA_ARGUMENT, checks.HASH_KEYWORD, checks.UNCLOSED }) |input| {
        try std.testing.checkAllAllocationFailures(std.testing.allocator, rejects, .{input});
    }
}

fn accepts(allocator: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var input = checks.MANIFEST[0..checks.MANIFEST.len].*;
    const nodes = try syntax.parse(&arena, &input);
    @memset(&input, 0);
    try std.testing.expectEqual(@as(usize, 3), nodes.len);
    const root = nodes[0];
    try std.testing.expectEqualStrings(checks.BUNDLE, root.Name);
    try std.testing.expectEqualStrings(checks.METADATA, root.Annotation.?);
    try std.testing.expectEqualStrings(checks.KEYBOARD, try values.text(root.Arguments[0]));
    try std.testing.expect(try values.boolean(values.property(root, checks.ENABLED).?));
    try std.testing.expectEqual(@as(u64, 16), try values.unsigned(values.property(root, checks.COUNT).?));
    try std.testing.expectEqualStrings(checks.TITLE, try values.text(values.property(root, checks.TITLE_KEY).?));
    try std.testing.expectError(error.InvalidWorld, values.text(values.property(root, checks.DISABLED).?));
    try std.testing.expectError(error.InvalidWorld, values.boolean(root.Arguments[0]));
    try std.testing.expect(values.property(root, checks.MISSING) == null);
    try std.testing.expect(nodes[1].Disabled);
    try std.testing.expect(!nodes[2].Disabled);
    try std.testing.expectEqual(@as(?usize, 0), nodes[2].Parent);
}

fn rejects(allocator: std.mem.Allocator, input: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    _ = syntax.parse(&arena, input) catch |failure| switch (failure) {
        error.InvalidWorld => return,
        error.OutOfMemory => return error.OutOfMemory,
    };
    return error.TestUnexpectedResult;
}
