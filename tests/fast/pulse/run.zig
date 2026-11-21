//! Pulse World And Supervision Regressions

const std = @import("std");

const catalog = @import("pulse").devices.catalog;
const drivers = @import("tests").fast.pulse.strings.drivers;
const memory = @import("tests").fast.pulse.memory;
const policy = @import("pulse").supervision.plan.model;
const samples = @import("tests").fast.pulse.strings.world;
const world = @import("pulse").world.parse.document;

const Candidate = @import("pulse").devices.types.catalog.Candidate;

const ALLOCATOR = std.testing.allocator;

test "Persona scratch memory reuses a freed tail without requiring new mapped pages" {
    try memory.reusesFreedTail();
}

test "Pulse reads the World dialect and orders jobs only after full validation" {
    var result = try world.parse(ALLOCATOR, samples.VALID);
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 2), result.Jobs.len);
    try std.testing.expectEqualStrings(samples.PROVIDER, result.Jobs[0].Name);
    try std.testing.expectEqualStrings(samples.BINARY, result.Jobs[0].Binary);
    try std.testing.expectEqualStrings(samples.PROVIDER, result.Jobs[0].Parameters);
    try std.testing.expectEqual(@as(u64, 1), result.Jobs[0].Restarts);
    try std.testing.expect(result.Jobs[0].Enabled);
    try std.testing.expect(!result.Jobs[0].Required and result.Jobs[0].Controller);
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

test "Pulse waits for readiness, stops dependents and applies the configured restart budget" {
    var document = try world.parse(ALLOCATOR, samples.VALID);
    defer document.deinit();
    var state = try policy.init(ALLOCATOR, &document);
    defer policy.deinit(&state);
    try std.testing.expectEqual(.Start, std.meta.activeTag(policy.next(&state)));
    try policy.started(&state, 0, 10);
    try std.testing.expectEqual(.Idle, std.meta.activeTag(policy.next(&state)));
    try policy.ready(&state, 0);
    try std.testing.expectEqual(@as(usize, 1), policy.next(&state).Start);
    try policy.started(&state, 1, 11);
    try policy.ready(&state, 1);
    try std.testing.expect(policy.died(&state, 10));
    try std.testing.expectEqual(@as(usize, 1), policy.next(&state).Stop);
    policy.stopped(&state, 1);
    try std.testing.expectEqual(@as(usize, 0), policy.next(&state).Start);
    try policy.started(&state, 0, 12);
    try policy.ready(&state, 0);
    try std.testing.expectEqual(@as(usize, 1), policy.next(&state).Start);
    try policy.started(&state, 1, 13);
    try policy.ready(&state, 1);
    try std.testing.expect(policy.died(&state, 12));
    policy.stopped(&state, policy.next(&state).Stop);
    try std.testing.expectEqual(.Idle, std.meta.activeTag(policy.next(&state)));
}

test "Pulse inhibits all restarts before stopping services in reverse dependency order" {
    var document = try world.parse(ALLOCATOR, samples.VALID);
    defer document.deinit();
    var state = try policy.init(ALLOCATOR, &document);
    defer policy.deinit(&state);
    try policy.started(&state, 0, 10);
    try policy.ready(&state, 0);
    try policy.started(&state, 1, 11);
    try policy.ready(&state, 1);
    policy.shutdown(&state);
    try std.testing.expectEqual(@as(usize, 1), policy.next(&state).Stop);
    policy.stopped(&state, 1);
    try std.testing.expectEqual(@as(usize, 0), policy.next(&state).Stop);
    policy.stopped(&state, 0);
    try std.testing.expectEqual(.Idle, std.meta.activeTag(policy.next(&state)));
    try std.testing.expect(state.Stopping);
}

test "Pulse selects a compatible driver for the actual instance and rejects an ambiguous catalog" {
    const first = try catalog.parse.manifest(ALLOCATOR, drivers.KEYBOARD);
    const second = try catalog.parse.manifest(ALLOCATOR, drivers.OTHER_PORT);
    const surface = try catalog.parse.manifest(ALLOCATOR, drivers.SURFACE);
    const entries: []const Candidate = &.{
        .{ .Identity = drivers.BUILTIN, .Description = first },
        .{ .Identity = drivers.FOREIGN, .Description = second },
        .{ .Identity = drivers.WRONG, .Description = surface },
    };
    try std.testing.expectEqualStrings(drivers.BUILTIN, try catalog.select.choose(entries, .{ .Kind = .Keyboard, .Location = 1 }, null));
    try std.testing.expectError(error.AmbiguousDriver, catalog.select.choose(entries, .{ .Kind = .Keyboard, .Location = 2 }, null));
    try std.testing.expectEqualStrings(drivers.FOREIGN, try catalog.select.choose(entries, .{ .Kind = .Keyboard, .Location = 2 }, drivers.FOREIGN));
    try std.testing.expectError(error.InvalidSelection, catalog.select.choose(entries, .{ .Kind = .Keyboard, .Location = 1 }, drivers.FOREIGN));
    try std.testing.expectError(error.InvalidSelection, catalog.select.choose(entries, .{ .Kind = .Keyboard, .Location = 1 }, drivers.WRONG));
    try std.testing.expectError(error.NoDriver, catalog.select.choose(entries, .{ .Kind = .Framebuffer, .Location = 1 }, null));
}

test "Pulse rejects missing incompatible and conflicting installed driver descriptions" {
    try std.testing.expectError(error.InvalidManifest, catalog.parse.manifest(ALLOCATOR, drivers.MISSING_VERSION));
    try std.testing.expectError(error.UnsupportedVersion, catalog.parse.manifest(ALLOCATOR, drivers.WRONG_ABI));
    try std.testing.expectError(error.InvalidManifest, catalog.parse.manifest(ALLOCATOR, drivers.DUPLICATE_MATCH));
}

fn validDocument(allocator: std.mem.Allocator) !void {
    var result = try world.parse(allocator, samples.VALID);
    defer result.deinit();
}
