//! Single Temporary Disk Image Integration

const std = @import("std");

const checks = @import("tests").fast.toolchain.image;
const constants = @import("tests").constants.image;
const mkafsdisk = @import("mkafsdisk");
const strings = @import("tests").strings.image;

pub fn createAndReadback() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.makePath(strings.BOOT_DIRECTORY);
    try temporary.dir.makePath(strings.DOCS_DIRECTORY);
    try temporary.dir.writeFile(.{ .sub_path = strings.BOOTLOADER_PATH, .data = &constants.BOOTLOADER_BYTES });
    try temporary.dir.writeFile(.{ .sub_path = strings.TINY_PATH, .data = strings.TINY_CONTENT });
    try temporary.dir.writeFile(.{ .sub_path = strings.CROSS_PATH, .data = &constants.CROSS_BYTES });
    try temporary.dir.writeFile(.{ .sub_path = strings.EMPTY_PATH, .data = strings.EMPTY_CONTENT });
    try temporary.dir.writeFile(.{ .sub_path = strings.NOTE_PATH, .data = strings.NOTE_CONTENT });
    try temporary.dir.writeFile(.{ .sub_path = strings.HIDDEN_PATH, .data = strings.HIDDEN_CONTENT });
    const directory = try temporary.dir.realpathAlloc(std.testing.allocator, strings.CURRENT_DIRECTORY);
    defer std.testing.allocator.free(directory);
    const source = try std.fs.path.join(std.testing.allocator, &.{ directory, strings.SOURCE_DIRECTORY });
    defer std.testing.allocator.free(source);
    const output = try std.fs.path.join(std.testing.allocator, &.{ directory, strings.IMAGE_NAME });
    defer std.testing.allocator.free(output);
    try mkafsdisk.image.create.createDiskImage(std.testing.allocator, source, output, constants.IMAGE_MEGABYTES);
    const file = try temporary.dir.openFile(strings.IMAGE_NAME, .{});
    defer file.close();
    try std.testing.expectEqual(constants.IMAGE_BYTES, try file.getEndPos());
    try checks.mbr.protectivePartition(file);
    try checks.gpt.reciprocalHeaders(file);
    try checks.gpt.mirroredPartitionTables(file);
    const boot = try checks.esp.bootMetadata(file);
    try checks.esp.bootloaderChainAndPadding(file, &boot);
    var filesystem = try checks.afs.metadataAndAllocation(file);
    try checks.afs.catalogLookupAndReadback(&filesystem);
}
