//! Active Disk Construction Failure Publication Regressions

const std = @import("std");

const capacity = @import("tests").fast.toolchain.image.constants.capacity;
const constants = @import("tests").fast.toolchain.image.constants.emission;
const fixture = @import("tests").fast.toolchain.image.fixture;
const names = @import("tests").strings.image;
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

fn buildFailure(paths: *const types.Paths, size_mib: u32) ?anyerror {
    tool.image.create.createDiskImage(std.testing.allocator, paths.Source, paths.Output, size_mib) catch |failure| return failure;
    return null;
}
