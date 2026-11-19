//! Single Temporary Disk Image Integration

const std = @import("std");

const checks = @import("tests").fast.toolchain.image;
const constants = @import("tests").constants.image;
const mkafsdisk = @import("mkafsdisk");
const strings = @import("tests").strings.image;

pub fn unitProgress() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try checks.fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try checks.fixture.createSource(temporary.dir, true);
    try checks.fixture.addMutableUnit(temporary.dir);
    var next: u32 = 0;
    _ = try mkafsdisk.image.create.createDiskImageReported(std.testing.allocator, paths.Source, paths.Output, constants.IMAGE_MEGABYTES, .{ .Context = &next, .UpdateFn = recordUnit });
    try std.testing.expectEqual(@as(u32, 3), next);
    const image = try temporary.dir.openFile(strings.IMAGE_NAME, .{});
    defer image.close();
    try std.testing.expectEqual(constants.IMAGE_BYTES, try image.getEndPos());
}

fn recordUnit(context: ?*anyopaque, done: u32, total: u32) !void {
    const next: *u32 = @ptrCast(@alignCast(context orelse return error.UnitProgressContextMissing));
    try std.testing.expectEqual(@as(u32, 2), total);
    try std.testing.expectEqual(next.*, done);
    next.* += 1;
}

pub fn publishedStats() !void {
    const create = mkafsdisk.image.create;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try checks.fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try checks.fixture.createSource(temporary.dir, true);
    try checks.fixture.addMutableUnit(temporary.dir);
    const report = try create.createDiskImageReported(std.testing.allocator, paths.Source, paths.Output, constants.IMAGE_MEGABYTES, null);
    const image = try temporary.dir.openFile(strings.IMAGE_NAME, .{});
    defer image.close();
    try std.testing.expectEqual(try image.getEndPos(), report.SizeBytes);
    try std.testing.expectEqual(constants.ESP_FIRST_LBA, report.EspFirstSector);
    try std.testing.expectEqual(constants.ESP_LAST_LBA, report.EspLastSector);
    try std.testing.expectEqual(constants.AFS_FIRST_LBA, report.AfsFirstSector);
    try std.testing.expectEqual(constants.AFS_LAST_LBA, report.AfsLastSector);
    try std.testing.expectEqual(@as(u64, constants.BOOTLOADER_BYTES.len), report.BootloaderBytes);
    const Header = @import("shared").afs.types.volume.VolumeHeader;
    var header: Header = undefined;
    try checks.io.readExact(image, report.AfsFirstSector * constants.SECTOR_BYTES, std.mem.asBytes(&header));
    try std.testing.expect(header.isValid());
    try std.testing.expectEqual(header.UnitCount, report.Units);
    try std.testing.expectEqual(header.StackCount, report.Stacks);
    try std.testing.expectEqual(header.CellSize, report.CellBytes);
    try std.testing.expectEqual(header.TotalCells, report.TotalCells);
    try std.testing.expectEqual(header.FreeCells, report.FreeCells);
    try std.testing.expectEqual(report, @TypeOf(report).decode(&report.encode()));
}

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
