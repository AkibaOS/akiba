//! Weaver System Library Selection Checks

const std = @import("std");

const dynamic = @import("tests").fast.shared.elf.dynamic;
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

const Unit = struct {
    Parent: []const []const u8,
    Identity: []const u8,
    Bytes: []const u8,
};

const Catalog = struct {
    Units: []const Unit,

    fn read(context: *const anyopaque, allocator: std.mem.Allocator, parent: []const []const u8, identity: []const u8) error{ OutOfMemory, LibraryReadFailed }!?[]u8 {
        const catalog: *const Catalog = @ptrCast(@alignCast(context));
        for (catalog.Units) |unit| {
            if (!std.mem.eql(u8, unit.Identity, identity) or parent.len != unit.Parent.len) continue;
            for (parent, unit.Parent) |requested, actual| {
                if (!std.mem.eql(u8, requested, actual)) break;
            } else return try allocator.dupe(u8, unit.Bytes);
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
