//! Weaver System Library Selection Checks

const std = @import("std");

const dynamic = @import("tests").fast.shared.elf.dynamic;
const elf = @import("shared").elf;
const fixture = @import("tests").fast.shared.elf.fixture;
const inputs = @import("tests").constants.elf;
const text = @import("tests").strings.elf;
const weaver = @import("weaver");

const ALLOCATOR = std.testing.allocator;
const SYSTEM = [_][]const u8{ "system", "libraries" };
const INSTALLED = [_][]const u8{"libraries"};
const ALIAS = "alias.lib";
const OTHER_CASE = "Probe.lib";
const STORAGE_WORD = inputs.PAGE_BYTES + inputs.DYNAMIC_TABLE;
const BRIDGE = "bridge.lib";
const LEAF = "leaf.lib";
const GRAPH_STRINGS = "\x00probe.lib\x00bridge.lib\x00leaf.lib\x00step\x00";
const PROBE_INDEX = 1;
const BRIDGE_INDEX = 11;
const LEAF_INDEX = 22;
const STEP_INDEX = 31;

const Unit = struct {
    Parent: []const []const u8,
    Identity: []const u8,
    Bytes: []const u8,
    Reads: ?*usize = null,
};

const Catalog = struct {
    Units: []const Unit,

    fn read(context: *const anyopaque, allocator: std.mem.Allocator, parent: []const []const u8, identity: []const u8) error{ OutOfMemory, LibraryReadFailed }!?[]u8 {
        const catalog: *const Catalog = @ptrCast(@alignCast(context));
        for (catalog.Units) |unit| {
            if (!std.mem.eql(u8, unit.Identity, identity) or parent.len != unit.Parent.len) continue;
            for (parent, unit.Parent) |requested, actual| {
                if (!std.mem.eql(u8, requested, actual)) break;
            } else {
                if (unit.Reads) |count| count.* += 1;
                return try allocator.dupe(u8, unit.Bytes);
            }
        }
        return null;
    }
};

test "Weaver selects the exact system unit and retains an owned byte snapshot" {
    var stored = dynamic.loadImage();
    const catalog: Catalog = .{ .Units = &.{
        .{ .Parent = &INSTALLED, .Identity = text.DYNAMIC_LIBRARY, .Bytes = &.{} },
        .{ .Parent = &SYSTEM, .Identity = text.DYNAMIC_LIBRARY, .Bytes = &stored },
    } };
    var library = try weaver.library.open.open(ALLOCATOR, .{ .Context = &catalog, .ReadFromOrigin = Catalog.read }, text.DYNAMIC_LIBRARY);
    defer library.deinit();
    @memset(&stored, 0);
    try std.testing.expectEqualSlices(u8, &.{ 0x7f, 'E', 'L', 'F' }, library.Bytes[0..4]);
    try std.testing.expectEqualStrings(text.DYNAMIC_LIBRARY, try library.Metadata.string(library.Metadata.Entries[1].Value));
}

test "Weaver never falls back to installed libraries or case-folds a unit identity" {
    const stored = dynamic.loadImage();
    const catalog: Catalog = .{ .Units = &.{
        .{ .Parent = &INSTALLED, .Identity = text.DYNAMIC_LIBRARY, .Bytes = &stored },
        .{ .Parent = &SYSTEM, .Identity = OTHER_CASE, .Bytes = &stored },
    } };
    try std.testing.expectError(error.LibraryNotFound, weaver.library.open.open(ALLOCATOR, .{ .Context = &catalog, .ReadFromOrigin = Catalog.read }, text.DYNAMIC_LIBRARY));
}

test "Weaver rejects path-like and non-library dependence names before selection" {
    const catalog: Catalog = .{ .Units = &.{} };
    const source: weaver.library.types.source.Source = .{ .Context = &catalog, .ReadFromOrigin = Catalog.read };
    for ([_][]const u8{ "../probe.lib", "origin/system/libraries/probe.lib", "dir\\probe.lib", "/probe.lib", "probe\x00.lib", ".lib", "probe.so" }) |identity| {
        try std.testing.expectError(error.InvalidLibraryName, weaver.library.open.open(ALLOCATOR, source, identity));
    }
    const maximum = ([_]u8{'x'} ** 252) ++ ".lib";
    const oversized = "x" ++ maximum;
    try std.testing.expectError(error.LibraryNotFound, weaver.library.open.open(ALLOCATOR, source, maximum));
    try std.testing.expectError(error.InvalidLibraryName, weaver.library.open.open(ALLOCATOR, source, oversized));
}

test "Weaver refuses a wrong missing or unreadable ELF identity without leaking the snapshot" {
    const stored = dynamic.loadImage();
    var missing = stored;
    fixture.write64(&missing, STORAGE_WORD + inputs.DYNAMIC_WORD_BYTES, 1);
    const wrong: Catalog = .{ .Units = &.{.{ .Parent = &SYSTEM, .Identity = ALIAS, .Bytes = &stored }} };
    const no_soname: Catalog = .{ .Units = &.{.{ .Parent = &SYSTEM, .Identity = text.DYNAMIC_LIBRARY, .Bytes = &missing }} };
    const truncated: Catalog = .{ .Units = &.{.{ .Parent = &SYSTEM, .Identity = text.DYNAMIC_LIBRARY, .Bytes = stored[0..1] }} };
    const open = weaver.library.open.open;
    try std.testing.expectError(error.LibraryNameMismatch, open(ALLOCATOR, .{ .Context = &wrong, .ReadFromOrigin = Catalog.read }, ALIAS));
    try std.testing.expectError(error.LibraryNameMismatch, open(ALLOCATOR, .{ .Context = &no_soname, .ReadFromOrigin = Catalog.read }, text.DYNAMIC_LIBRARY));
    try std.testing.expectError(error.InvalidHeader, open(ALLOCATOR, .{ .Context = &truncated, .ReadFromOrigin = Catalog.read }, text.DYNAMIC_LIBRARY));
}

test "Weaver propagates refusal to allocate the system library snapshot" {
    const stored = dynamic.loadImage();
    const catalog: Catalog = .{ .Units = &.{.{ .Parent = &SYSTEM, .Identity = text.DYNAMIC_LIBRARY, .Bytes = &stored }} };
    var failing = std.testing.FailingAllocator.init(ALLOCATOR, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, weaver.library.open.open(failing.allocator(), .{ .Context = &catalog, .ReadFromOrigin = Catalog.read }, text.DYNAMIC_LIBRARY));
}

test "Weaver follows transitive needs and reads each shared or cyclic identity once" {
    try verifyGraph(ALLOCATOR);
}

test "Weaver discards a partial graph when a transitive system library is missing" {
    const executable = encodeGraph(PROBE_INDEX, null, null);
    const probe = encodeGraph(BRIDGE_INDEX, null, PROBE_INDEX);
    const bridge = encodeGraph(LEAF_INDEX, null, BRIDGE_INDEX);
    const leaf = encodeGraph(0, null, LEAF_INDEX);
    const catalog: Catalog = .{ .Units = &.{
        .{ .Parent = &SYSTEM, .Identity = text.DYNAMIC_LIBRARY, .Bytes = &probe },
        .{ .Parent = &SYSTEM, .Identity = BRIDGE, .Bytes = &bridge },
        .{ .Parent = &INSTALLED, .Identity = LEAF, .Bytes = &leaf },
    } };
    const metadata = try elf.read.dynamic.read(&executable);
    try std.testing.expectError(error.LibraryNotFound, weaver.library.collect.collect(ALLOCATOR, .{ .Context = &catalog, .ReadFromOrigin = Catalog.read }, metadata));
}

test "Weaver returns all dependency graph allocations at every injected allocation refusal" {
    try std.testing.checkAllAllocationFailures(ALLOCATOR, verifyGraph, .{});
}

fn verifyGraph(allocator: std.mem.Allocator) !void {
    const executable = encodeGraph(PROBE_INDEX, LEAF_INDEX, null);
    const probe = encodeGraph(BRIDGE_INDEX, null, PROBE_INDEX);
    const bridge = encodeGraph(LEAF_INDEX, null, BRIDGE_INDEX);
    const leaf = encodeGraph(PROBE_INDEX, null, LEAF_INDEX);
    var reads: [3]usize = @splat(0);
    const catalog: Catalog = .{ .Units = &.{
        .{ .Parent = &SYSTEM, .Identity = text.DYNAMIC_LIBRARY, .Bytes = &probe, .Reads = &reads[0] },
        .{ .Parent = &SYSTEM, .Identity = BRIDGE, .Bytes = &bridge, .Reads = &reads[1] },
        .{ .Parent = &SYSTEM, .Identity = LEAF, .Bytes = &leaf, .Reads = &reads[2] },
    } };
    const metadata = try elf.read.dynamic.read(&executable);
    var graph = try weaver.library.collect.collect(allocator, .{ .Context = &catalog, .ReadFromOrigin = Catalog.read }, metadata);
    defer graph.deinit();
    try std.testing.expectEqual(@as(usize, 3), graph.Libraries.len);
    try std.testing.expectEqualSlices(usize, &.{ 1, 1, 1 }, &reads);
    try std.testing.expectEqualSlices(u8, &probe, graph.get(text.DYNAMIC_LIBRARY).?.Bytes);
    try std.testing.expectEqualSlices(u8, &bridge, graph.get(BRIDGE).?.Bytes);
    try std.testing.expectEqualSlices(u8, &leaf, graph.get(LEAF).?.Bytes);
    try std.testing.expect(graph.get(ALIAS) == null);
}

fn encodeGraph(need: u64, second: ?u64, identity: ?u64) [inputs.DATA_BYTES]u8 {
    var bytes = dynamic.loadImage();
    @memcpy(bytes[inputs.DYNAMIC_LAYOUT_FILE..][0..GRAPH_STRINGS.len], GRAPH_STRINGS);
    fixture.write32(&bytes, inputs.PAGE_BYTES + inputs.DYNAMIC_SYMBOLS + inputs.DYNAMIC_SYMBOL_BYTES, STEP_INDEX);
    fixture.write64(&bytes, STORAGE_WORD + 3 * inputs.DYNAMIC_WORD_BYTES + @sizeOf(u64), GRAPH_STRINGS.len);
    if (need == 0) fixture.write64(&bytes, STORAGE_WORD, 21);
    fixture.write64(&bytes, STORAGE_WORD + @sizeOf(u64), need);
    const slot = STORAGE_WORD + inputs.DYNAMIC_WORD_BYTES;
    if (identity) |value| {
        fixture.write64(&bytes, slot + @sizeOf(u64), value);
    } else if (second) |value| {
        fixture.write64(&bytes, slot, 1);
        fixture.write64(&bytes, slot + @sizeOf(u64), value);
    } else {
        fixture.write64(&bytes, slot, 21);
    }
    return bytes;
}
