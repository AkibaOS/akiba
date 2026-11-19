//! Active Disk Construction Failure Publication Regressions

const std = @import("std");

const capacity = @import("tests").fast.toolchain.image.constants.capacity;
const constants = @import("tests").fast.toolchain.image.constants.emission;
const fixture = @import("tests").fast.toolchain.image.fixture;
const lookup = @import("tests").fast.toolchain.image.lookup;
const names = @import("tests").fast.strings.image;
const strings = @import("tests").fast.toolchain.image.strings.emission;
const tool = @import("mkafsdisk");
const types = @import("tests").fast.toolchain.image.types.emission;

pub fn insufficientSpacePreservesExistingFinalBytes() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try fixture.createSource(temporary.dir, true);
    try fixture.addOversizedUnit(temporary.dir);
    try fixture.writeSentinel(temporary.dir);
    try std.testing.expect(buildFailure(&paths, constants.SMALL_MIB) != null);
    try fixture.expectSentinel(temporary.dir);
    try fixture.expectOwnedEntries(temporary.dir, true, true);
}

pub fn insufficientSpaceDoesNotPublishAnAbsentFinal() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try fixture.createSource(temporary.dir, true);
    try fixture.addOversizedUnit(temporary.dir);
    try std.testing.expect(buildFailure(&paths, constants.SMALL_MIB) != null);
    try std.testing.expectError(error.FileNotFound, temporary.dir.access(names.IMAGE_NAME, .{}));
    try fixture.expectOwnedEntries(temporary.dir, true, false);
}

pub fn missingSourceIsFailureWithoutReplacingFinalBytes() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try fixture.writeSentinel(temporary.dir);
    try std.testing.expect(buildFailure(&paths, capacity.DEFAULT_MIB) != null);
    try fixture.expectSentinel(temporary.dir);
    try fixture.expectOwnedEntries(temporary.dir, false, true);
}

pub fn missingBootloaderIsFailureWithoutReplacingFinalBytes() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try fixture.createSource(temporary.dir, false);
    try fixture.writeSentinel(temporary.dir);
    try std.testing.expect(buildFailure(&paths, capacity.DEFAULT_MIB) != null);
    try fixture.expectSentinel(temporary.dir);
    try fixture.expectOwnedEntries(temporary.dir, true, true);
}

pub fn outputInsideSourceIsRefused() !void {
    try expectSourceOverlapRefused(false);
}

pub fn outputWithinCanonicalSourceAliasIsRefused() !void {
    try expectSourceOverlapRefused(true);
}

fn expectSourceOverlapRefused(alias_source: bool) !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try fixture.createSource(temporary.dir, true);
    var source = try temporary.dir.openDir(names.SOURCE_DIRECTORY, .{});
    defer source.close();
    try fixture.writeSentinel(source);
    const output = try std.fs.path.join(std.testing.allocator, &.{ paths.Source, names.IMAGE_NAME });
    defer std.testing.allocator.free(output);
    const location = if (alias_source)
        try std.fs.path.join(std.testing.allocator, &.{ paths.Source, strings.PARENT_DIRECTORY, names.SOURCE_DIRECTORY })
    else
        try std.testing.allocator.dupe(u8, paths.Source);
    defer std.testing.allocator.free(location);
    try std.testing.expectError(error.OutputInsideSource, tool.image.create.createDiskImage(std.testing.allocator, location, output, capacity.DEFAULT_MIB));
    try fixture.expectSentinel(source);
    try fixture.expectOwnedEntries(temporary.dir, true, false);
}

pub fn sourcePrefixSiblingIsNotMistakenForOverlap() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try fixture.createSource(temporary.dir, true);
    try temporary.dir.makeDir(strings.SIBLING_ROOT);
    var sibling = try temporary.dir.openDir(strings.SIBLING_ROOT, .{});
    defer sibling.close();
    const root = try sibling.realpathAlloc(std.testing.allocator, names.CURRENT_DIRECTORY);
    defer std.testing.allocator.free(root);
    const output = try std.fs.path.join(std.testing.allocator, &.{ root, names.IMAGE_NAME });
    defer std.testing.allocator.free(output);
    try tool.image.create.createDiskImage(std.testing.allocator, paths.Source, output, capacity.DEFAULT_MIB);
    const file = try sibling.openFile(names.IMAGE_NAME, .{});
    defer file.close();
    _ = try lookup.openImage(file);
    try fixture.expectOwnedEntries(sibling, false, true);
}

fn buildFailure(paths: *const types.Paths, size_mib: u32) ?anyerror {
    tool.image.create.createDiskImage(std.testing.allocator, paths.Source, paths.Output, size_mib) catch |failure| return failure;
    return null;
}
