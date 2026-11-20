//! Weaver System Library Selection Checks

const std = @import("std");

const afs = @import("tests").fast.weaver.afs;
const dynamic = @import("tests").fast.elf.dynamic;
const elf = @import("shared").elf;
const fixture = @import("tests").fixtures.bytes.elf;
const fixturetext = @import("tests").fixtures.strings.elf.identities;
const inputs = @import("tests").fixtures.constants.elf.layout;
const pages = @import("tests").fast.weaver.pages;
const request = @import("tests").fast.weaver.request;
const startup = @import("tests").fast.weaver.startup;
const weaver = @import("weaver");

const ALLOCATOR = std.testing.allocator;
const SYSTEM = [_][]const u8{ "system", "libraries" };
const INSTALLED = [_][]const u8{"libraries"};

test "Weaver resolves a native library through a real writer produced AFS catalog" {
    try afs.installed(@embedFile("dynamicimage"), @embedFile("dynamiclibrary"));
}
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
        .{ .Parent = &INSTALLED, .Identity = fixturetext.DYNAMIC_LIBRARY, .Bytes = &.{} },
        .{ .Parent = &SYSTEM, .Identity = fixturetext.DYNAMIC_LIBRARY, .Bytes = &stored },
    } };
    var library = try weaver.library.load.open.open(ALLOCATOR, .{ .Context = &catalog, .ReadFromOrigin = Catalog.read }, fixturetext.DYNAMIC_LIBRARY);
    defer library.deinit();
    @memset(&stored, 0);
    try std.testing.expectEqualSlices(u8, &.{ 0x7f, 'E', 'L', 'F' }, library.Bytes[0..4]);
    try std.testing.expectEqualStrings(fixturetext.DYNAMIC_LIBRARY, try library.Metadata.string(library.Metadata.Entries[1].Value));
}

test "Weaver never falls back to installed libraries or case-folds a unit identity" {
    const stored = dynamic.loadImage();
    const catalog: Catalog = .{ .Units = &.{
        .{ .Parent = &INSTALLED, .Identity = fixturetext.DYNAMIC_LIBRARY, .Bytes = &stored },
        .{ .Parent = &SYSTEM, .Identity = OTHER_CASE, .Bytes = &stored },
    } };
    try std.testing.expectError(error.LibraryNotFound, weaver.library.load.open.open(ALLOCATOR, .{ .Context = &catalog, .ReadFromOrigin = Catalog.read }, fixturetext.DYNAMIC_LIBRARY));
}

test "Weaver rejects path-like and non-library dependence names before selection" {
    const catalog: Catalog = .{ .Units = &.{} };
    const source: weaver.library.types.source.Source = .{ .Context = &catalog, .ReadFromOrigin = Catalog.read };
    for ([_][]const u8{ "../probe.lib", "origin/system/libraries/probe.lib", "dir\\probe.lib", "/probe.lib", "probe\x00.lib", ".lib", "probe.so" }) |identity| {
        try std.testing.expectError(error.InvalidLibraryName, weaver.library.load.open.open(ALLOCATOR, source, identity));
    }
    const maximum = ([_]u8{'x'} ** 252) ++ ".lib";
    const oversized = "x" ++ maximum;
    try std.testing.expectError(error.LibraryNotFound, weaver.library.load.open.open(ALLOCATOR, source, maximum));
    try std.testing.expectError(error.InvalidLibraryName, weaver.library.load.open.open(ALLOCATOR, source, oversized));
}

test "Weaver refuses a wrong missing or unreadable ELF identity without leaking the snapshot" {
    const stored = dynamic.loadImage();
    var missing = stored;
    fixture.write64(&missing, STORAGE_WORD + inputs.DYNAMIC_WORD_BYTES, 1);
    const wrong: Catalog = .{ .Units = &.{.{ .Parent = &SYSTEM, .Identity = ALIAS, .Bytes = &stored }} };
    const no_soname: Catalog = .{ .Units = &.{.{ .Parent = &SYSTEM, .Identity = fixturetext.DYNAMIC_LIBRARY, .Bytes = &missing }} };
    const truncated: Catalog = .{ .Units = &.{.{ .Parent = &SYSTEM, .Identity = fixturetext.DYNAMIC_LIBRARY, .Bytes = stored[0..1] }} };
    const open = weaver.library.load.open.open;
    try std.testing.expectError(error.LibraryNameMismatch, open(ALLOCATOR, .{ .Context = &wrong, .ReadFromOrigin = Catalog.read }, ALIAS));
    try std.testing.expectError(error.LibraryNameMismatch, open(ALLOCATOR, .{ .Context = &no_soname, .ReadFromOrigin = Catalog.read }, fixturetext.DYNAMIC_LIBRARY));
    try std.testing.expectError(error.InvalidHeader, open(ALLOCATOR, .{ .Context = &truncated, .ReadFromOrigin = Catalog.read }, fixturetext.DYNAMIC_LIBRARY));
}

test "Weaver propagates refusal to allocate the system library snapshot" {
    const stored = dynamic.loadImage();
    const catalog: Catalog = .{ .Units = &.{.{ .Parent = &SYSTEM, .Identity = fixturetext.DYNAMIC_LIBRARY, .Bytes = &stored }} };
    var failing = std.testing.FailingAllocator.init(ALLOCATOR, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, weaver.library.load.open.open(failing.allocator(), .{ .Context = &catalog, .ReadFromOrigin = Catalog.read }, fixturetext.DYNAMIC_LIBRARY));
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
        .{ .Parent = &SYSTEM, .Identity = fixturetext.DYNAMIC_LIBRARY, .Bytes = &probe },
        .{ .Parent = &SYSTEM, .Identity = BRIDGE, .Bytes = &bridge },
        .{ .Parent = &INSTALLED, .Identity = LEAF, .Bytes = &leaf },
    } };
    try std.testing.expectError(error.LibraryNotFound, weaver.library.load.collect.collect(ALLOCATOR, .{ .Context = &catalog, .ReadFromOrigin = Catalog.read }, &executable));
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
        .{ .Parent = &SYSTEM, .Identity = fixturetext.DYNAMIC_LIBRARY, .Bytes = &probe, .Reads = &reads[0] },
        .{ .Parent = &SYSTEM, .Identity = BRIDGE, .Bytes = &bridge, .Reads = &reads[1] },
        .{ .Parent = &SYSTEM, .Identity = LEAF, .Bytes = &leaf, .Reads = &reads[2] },
    } };
    var graph = try weaver.library.load.collect.collect(allocator, .{ .Context = &catalog, .ReadFromOrigin = Catalog.read }, &executable);
    defer graph.deinit();
    try std.testing.expectEqual(@as(usize, 3), graph.Libraries.len);
    try std.testing.expectEqualSlices(usize, &.{ 1, 1, 1 }, &reads);
    try std.testing.expectEqualSlices(u8, &probe, graph.get(fixturetext.DYNAMIC_LIBRARY).?.Bytes);
    try std.testing.expectEqualSlices(u8, &bridge, graph.get(BRIDGE).?.Bytes);
    try std.testing.expectEqualSlices(u8, &leaf, graph.get(LEAF).?.Bytes);
    try std.testing.expect(graph.get(ALIAS) == null);
}

test "Weaver places the exact executable snapshot and its libraries without page collisions" {
    try verifyPlacement(ALLOCATOR);
}

test "Weaver rejects cross-image page collisions even when the images' bytes do not overlap" {
    var graph = try layoutGraph(ALLOCATOR);
    defer graph.deinit();
    const policy: elf.types.image.Policy = .{ .MinimumAddress = inputs.PAGE_BYTES, .MaximumAddress = inputs.USER_END, .MaximumPages = inputs.MAXIMUM_PAGES };
    const biases: weaver.image.types.layout.Biases = .{ .Executable = 0x200000, .Libraries = &.{ 0x201000, 0x600000 } };
    try std.testing.expectError(error.AddressOverlap, weaver.image.place.place(ALLOCATOR, &graph, biases, policy, &.{}));
}

test "Weaver checks launch reservations and the aggregate image budget" {
    var graph = try layoutGraph(ALLOCATOR);
    defer graph.deinit();
    const policy: elf.types.image.Policy = .{ .MinimumAddress = inputs.PAGE_BYTES, .MaximumAddress = inputs.USER_END, .MaximumPages = inputs.MAXIMUM_PAGES };
    const biases: weaver.image.types.layout.Biases = .{ .Executable = 0x200000, .Libraries = &.{ 0x400000, 0x600000 } };
    const place = weaver.image.place.place;
    try std.testing.expectError(error.AddressOverlap, place(ALLOCATOR, &graph, biases, policy, &.{.{ .Start = 0x205000, .End = 0x206000 }}));
    try std.testing.expectError(error.InvalidReservation, place(ALLOCATOR, &graph, biases, policy, &.{.{ .Start = 0x207008, .End = 0x208000 }}));
    try std.testing.expectError(error.InvalidPlacement, place(ALLOCATOR, &graph, .{ .Executable = 0x200000, .Libraries = &.{0x400000} }, policy, &.{}));
    var limited = policy;
    limited.MaximumPages = 5;
    try std.testing.expectError(error.ImageTooLarge, place(ALLOCATOR, &graph, biases, limited, &.{}));
}

test "Weaver releases partial image placements at every injected allocator refusal" {
    try std.testing.checkAllAllocationFailures(ALLOCATOR, verifyPlacement, .{});
}

fn layoutGraph(allocator: std.mem.Allocator) !weaver.library.types.graph.Graph {
    var executable = encodeGraph(PROBE_INDEX, null, null);
    const probe = encodeGraph(BRIDGE_INDEX, null, PROBE_INDEX);
    const bridge = encodeGraph(0, null, BRIDGE_INDEX);
    const catalog: Catalog = .{ .Units = &.{
        .{ .Parent = &SYSTEM, .Identity = fixturetext.DYNAMIC_LIBRARY, .Bytes = &probe },
        .{ .Parent = &SYSTEM, .Identity = BRIDGE, .Bytes = &bridge },
    } };
    const graph = try weaver.library.load.collect.collect(allocator, .{ .Context = &catalog, .ReadFromOrigin = Catalog.read }, &executable);
    @memset(&executable, 0);
    return graph;
}

fn verifyPlacement(allocator: std.mem.Allocator) !void {
    var graph = try layoutGraph(allocator);
    defer graph.deinit();
    const policy: elf.types.image.Policy = .{ .MinimumAddress = inputs.PAGE_BYTES, .MaximumAddress = inputs.USER_END, .MaximumPages = inputs.MAXIMUM_PAGES };
    const biases: weaver.image.types.layout.Biases = .{ .Executable = 0x200000, .Libraries = &.{ 0x400000, 0x600000 } };
    var placement = try weaver.image.place.place(allocator, &graph, biases, policy, &.{.{ .Start = 0x207000, .End = 0x208000 }});
    defer placement.deinit();
    try std.testing.expectEqual(@as(u64, 0x206001), placement.Executable.Image.Entry);
    try std.testing.expectEqual(@as(u64, 6), placement.Pages);
    try std.testing.expectEqual(@as(usize, 2), placement.Libraries.len);
    try std.testing.expectEqual(@as(u64, 0x405100), placement.Libraries[0].Image.Segments[0].VirtualAddress);
    try std.testing.expectEqual(@as(u64, 0x605100), placement.Libraries[1].Image.Segments[0].VirtualAddress);
    try std.testing.expectEqual(@as(u64, 0), placement.Libraries[0].Image.Entry);
}

test "Weaver commits a fully staged ELF and multi-page startup record through one ticket" {
    try request.commits();
}

test "Weaver does not begin provisioning if libraries or reservations fail planning" {
    try request.rejectsBeforeBegin();
}

test "Weaver aborts exactly once on a rejected staged load and reports a rejected abort" {
    try request.aborts();
}

test "Weaver reuses only unchanged sealed library pages and explicitly evicts them" {
    try request.reusesPages();
}

test "Weaver discards cache handles from an aborted launch" {
    try request.discardsPending();
}

test "Launch startup bytes and page extent preserve the private record" {
    try startup.preservesWire();
}

test "Launch startup rejects unknown versions missing identities and overflowing extents" {
    try startup.rejectsOutOfBounds();
}

test "Weaver materializes linked file bytes and split relocations before final page permissions" {
    try pages.verify(false);
}

test "Weaver skips image gaps and keeps separate file fragments in one scratch page" {
    try pages.verify(true);
}

test "Weaver plans checked function data and same-image bindings" {
    for ([_]LinkCase{ .Function, .Data, .Defined }) |scenario| try verifyLink(ALLOCATOR, scenario);
}

test "Weaver refuses missing transitive and conflicting directly declared symbols" {
    for ([_]LinkCase{ .Missing, .Transitive, .Ambiguous }) |scenario| try verifyLink(ALLOCATOR, scenario);
}

test "Weaver checks resolved symbol kind and extent and refuses weak or versioned imports" {
    for ([_]LinkCase{ .WrongKind, .InvalidExtent, .WrongSegment, .Weak, .Versioned }) |scenario| try verifyLink(ALLOCATOR, scenario);
}

test "Weaver releases all relocation planning allocations after injected refusal" {
    try std.testing.checkAllAllocationFailures(ALLOCATOR, verifyLink, .{LinkCase.Function});
}

const LinkCase = enum { Function, Data, Defined, Missing, Transitive, Ambiguous, WrongKind, InvalidExtent, WrongSegment, Weak, Versioned };
const LINK_SYMBOL = inputs.PAGE_BYTES + inputs.DYNAMIC_SYMBOLS + inputs.DYNAMIC_SYMBOL_BYTES;
const LINK_GENERAL = inputs.PAGE_BYTES + inputs.DYNAMIC_RELA;
const LINK_PROCEDURE = inputs.PAGE_BYTES + inputs.DYNAMIC_PLT;

fn verifyLink(allocator: std.mem.Allocator, scenario: LinkCase) !void {
    const direct: u64 = if (scenario == .Defined) 0 else PROBE_INDEX;
    const second: ?u64 = if (scenario == .Ambiguous) BRIDGE_INDEX else if (scenario == .Function) PROBE_INDEX else null;
    var executable = encodeGraph(direct, second, null);
    var probe = encodeGraph(if (scenario == .Transitive) BRIDGE_INDEX else 0, null, PROBE_INDEX);
    var bridge = encodeGraph(0, null, BRIDGE_INDEX);
    prepareRelative(&probe);
    prepareRelative(&bridge);
    prepareRelative(&executable);
    fixture.write64(&executable, STORAGE_WORD + 11 * inputs.DYNAMIC_WORD_BYTES + @sizeOf(u64), inputs.DYNAMIC_RELA_BYTES);
    fixture.write64(&executable, LINK_PROCEDURE, 0x53f8);
    putDefinition(&probe, 0x12, 6, 0x6000, 32);
    putDefinition(&bridge, 0x12, 6, 0x6000, 32);
    const failure: ?anyerror = switch (scenario) {
        .Function => null,
        .Data => data: {
            prepareRelative(&executable);
            fixture.write64(&executable, LINK_GENERAL + 8, 0x100000006);
            fixture.write64(&executable, LINK_GENERAL + 16, 0);
            putDefinition(&executable, 0x11, 0, 0, 8);
            putDefinition(&probe, 0x11, 4, 0x5ff8, 8);
            break :data null;
        },
        .Defined => defined: {
            putDefinition(&executable, 0x12, 6, 0x6000, 32);
            break :defined null;
        },
        .Missing, .Transitive => missing: {
            putDefinition(&probe, 0x12, 0, 0, 0);
            break :missing error.UnresolvedSymbol;
        },
        .Ambiguous => error.AmbiguousSymbol,
        .WrongKind => wrong: {
            putDefinition(&probe, 0x11, 4, 0x5400, 8);
            break :wrong error.SymbolKindMismatch;
        },
        .InvalidExtent => extent: {
            putDefinition(&probe, 0x12, 6, 0x6000, 33);
            break :extent error.InvalidDefinition;
        },
        .WrongSegment => segment: {
            putDefinition(&probe, 0x12, 4, 0x5400, 8);
            break :segment error.InvalidDefinition;
        },
        .Weak => weak: {
            putDefinition(&executable, 0x22, 0, 0, 0);
            break :weak error.UnsupportedSymbol;
        },
        .Versioned => versioned: {
            fixture.write64(&executable, STORAGE_WORD + inputs.DYNAMIC_WORD_BYTES, 0x6ffffff0);
            break :versioned error.UnsupportedLinkMetadata;
        },
    };
    const catalog: Catalog = .{ .Units = &.{
        .{ .Parent = &SYSTEM, .Identity = fixturetext.DYNAMIC_LIBRARY, .Bytes = &probe },
        .{ .Parent = &SYSTEM, .Identity = BRIDGE, .Bytes = &bridge },
    } };
    var graph = try weaver.library.load.collect.collect(allocator, .{ .Context = &catalog, .ReadFromOrigin = Catalog.read }, &executable);
    defer graph.deinit();
    const policy: elf.types.image.Policy = .{ .MinimumAddress = inputs.PAGE_BYTES, .MaximumAddress = inputs.USER_END, .MaximumPages = inputs.MAXIMUM_PAGES };
    const biases = [_]u64{ 0x400000, 0x600000 };
    var placement = try weaver.image.place.place(allocator, &graph, .{ .Executable = 0x200000, .Libraries = biases[0..graph.Libraries.len] }, policy, &.{});
    defer placement.deinit();
    const linked = weaver.link.plan.plan(allocator, &placement);
    if (failure) |expected| {
        try std.testing.expectError(expected, linked);
        return;
    }
    var plan = try linked;
    defer plan.deinit();
    const writes = plan.Executable.Writes;
    if (scenario == .Data) {
        try std.testing.expectEqual(@as(usize, 1), writes.len);
        try std.testing.expectEqual(@as(u64, 0x2053f0), writes[0].Address);
        try std.testing.expectEqual(@as(u64, 0x405ff8), writes[0].Value);
    } else {
        try std.testing.expectEqual(@as(usize, 2), writes.len);
        try std.testing.expectEqual(@as(u64, 0x205400), writes[0].Value);
        try std.testing.expectEqual(@as(u64, 0x2053f8), writes[1].Address);
        try std.testing.expectEqual(@as(u64, if (scenario == .Defined) 0x206000 else 0x406000), writes[1].Value);
    }
    try std.testing.expectEqual(graph.Libraries.len, plan.Libraries.len);
    if (scenario != .Defined) {
        try std.testing.expectEqual(@as(usize, 1), plan.Libraries[0].Writes.len);
        try std.testing.expectEqual(@as(u64, 0x405400), plan.Libraries[0].Writes[0].Value);
    }
}

fn prepareRelative(bytes: []u8) void {
    fixture.write64(bytes, STORAGE_WORD + 11 * inputs.DYNAMIC_WORD_BYTES + @sizeOf(u64), 0);
    fixture.write64(bytes, LINK_GENERAL, 0x53f0);
    fixture.write64(bytes, LINK_GENERAL + 16, 0x5400);
}

fn putDefinition(bytes: []u8, info: u8, section: u16, value: u64, size: u64) void {
    bytes[LINK_SYMBOL + 4] = info;
    fixture.write16(bytes, LINK_SYMBOL + 6, section);
    fixture.write64(bytes, LINK_SYMBOL + 8, value);
    fixture.write64(bytes, LINK_SYMBOL + 16, size);
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
        fixture.write64(&bytes, slot + @sizeOf(u64), 0);
    }
    return bytes;
}
