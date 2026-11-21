//! Pulse World And Supervision Regressions

const std = @import("std");

const samples = @import("tests").fast.pulse.strings.world;
const world = @import("pulse").world.parse.document;

const ALLOCATOR = std.testing.allocator;

test "Pulse reads the World dialect and orders jobs only after full validation" {
    var result = try world.parse(ALLOCATOR, samples.VALID);
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 2), result.Jobs.len);
    try std.testing.expectEqualStrings(samples.PROVIDER, result.Jobs[0].Name);
    try std.testing.expectEqualStrings(samples.BINARY, result.Jobs[0].Binary);
    try std.testing.expectEqualStrings(samples.PROVIDER, result.Jobs[0].Parameters);
    try std.testing.expectEqual(@as(u64, 1), result.Jobs[0].Restarts);
    try std.testing.expect(result.Jobs[0].Enabled);
    try std.testing.expectEqualStrings(samples.CONSUMER, result.Jobs[1].Name);
    try std.testing.expectEqualStrings(samples.PROVIDER, result.Jobs[1].After[0]);
}

test "Pulse rejects positional values after properties and prefixed keyword aliases" {
    try std.testing.expectError(error.InvalidWorld, world.parse(ALLOCATOR, samples.POSITION));
    try std.testing.expectError(error.InvalidWorld, world.parse(ALLOCATOR, samples.KEYWORD));
    try std.testing.expectError(error.InvalidWorld, world.parse(ALLOCATOR, samples.UNFINISHED));
}

test "Pulse refuses duplicate services and missing or cyclic dependencies before launch" {
    try std.testing.expectError(error.DuplicateService, world.parse(ALLOCATOR, samples.DUPLICATE));
    try std.testing.expectError(error.MissingDependency, world.parse(ALLOCATOR, samples.MISSING));
    try std.testing.expectError(error.DependencyCycle, world.parse(ALLOCATOR, samples.CYCLE));
}

test "Pulse accepts multiline raw strings, comments, omission and line continuations" {
    var result = try world.parse(ALLOCATOR, samples.MULTILINE);
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 1), result.Jobs.len);
    try std.testing.expect(result.Jobs[0].Enabled);
    try std.testing.expectEqual(@as(u64, 1), result.Jobs[0].Restarts);
    try std.testing.expectEqualStrings(samples.MULTILINE_VALUE, result.Jobs[0].Parameters);
    try std.testing.expectError(error.InvalidWorld, world.parse(ALLOCATOR, samples.ADJACENT));
}

test "Pulse recognizes World Unicode whitespace, line boundaries and the optional BOM" {
    var result = try world.parse(ALLOCATOR, samples.UNICODE_SPACE);
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 1), result.Jobs.len);
    try std.testing.expectEqualStrings(samples.PROVIDER, result.Jobs[0].Name);
}

test "Pulse releases every partially parsed World allocation on refusal" {
    try std.testing.checkAllAllocationFailures(ALLOCATOR, validDocument, .{});
}

fn validDocument(allocator: std.mem.Allocator) !void {
    var result = try world.parse(allocator, samples.VALID);
    defer result.deinit();
}
