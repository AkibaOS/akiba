//! Disk Image Creation

const std = @import("std");

const tool = @import("mkafsdisk");

const Observer = tool.types.progress.Observer;
const Writer = tool.types.writer.Writer;
const disk = tool.constants.disk;
const names = tool.strings.names;

pub fn createDiskImage(allocator: std.mem.Allocator, source_location: []const u8, output_path: []const u8, size_megabytes: u32) !void {
    return create(allocator, source_location, output_path, size_megabytes, tool.image.io.native(), null);
}

pub fn createDiskImageObserved(allocator: std.mem.Allocator, source_location: []const u8, output_path: []const u8, size_megabytes: u32, observer: Observer) !void {
    return create(allocator, source_location, output_path, size_megabytes, tool.image.io.native(), observer);
}

pub fn createDiskImageUsingIO(allocator: std.mem.Allocator, source_location: []const u8, output_path: []const u8, size_megabytes: u32, operations: tool.types.io.Operations) !void {
    return create(allocator, source_location, output_path, size_megabytes, operations, null);
}

fn create(allocator: std.mem.Allocator, source_location: []const u8, output_path: []const u8, size_megabytes: u32, operations: tool.types.io.Operations, observer: ?Observer) !void {
    const geometry = try tool.image.geometry.disk(size_megabytes);
    try tool.image.location.validateOutput(allocator, source_location, output_path);
    var filesystem = try tool.catalog.prepare.prepare(allocator, source_location, geometry.PartitionSizeBytes);
    defer filesystem.deinit();
    const source = filesystem.Manifest.Entries[0].Path;
    try requireBootloader(allocator, source);
    const esp_start = std.math.cast(u32, geometry.EspStartLBA) orelse return tool.errors.planning.PlanningError.Overflow;
    var output = try tool.image.output.create(output_path, geometry.TotalBytes);
    defer output.deinit();
    output.IO = operations;
    const file = output.file();
    try tool.image.mbr.writeProtectiveMbr(file, geometry.TotalSectors);
    try tool.image.gpt.writeGpt(file, geometry.EspStartLBA, geometry.EspEndLBA, geometry.AfsStartLBA, geometry.AfsEndLBA, geometry.TotalSectors);
    try tool.image.esp.createEspUsingIO(allocator, file, source, esp_start, disk.ESP_SIZE_SECTORS, operations);
    var writer = Writer.initialize(file, geometry.PartitionStartByte, geometry.PartitionSizeBytes, allocator);
    writer.IO = operations;
    writer.Progress = observer;
    try writer.writeFilesystem(&filesystem);
    try output.finish();
}

fn requireBootloader(allocator: std.mem.Allocator, source: []const u8) !void {
    const path = try std.fs.path.join(allocator, &.{ source, names.STACK_EFI, names.STACK_BOOT, names.UNIT_BOOTLOADER });
    defer allocator.free(path);
    const file = try std.fs.cwd().openFile(path, .{});
    file.close();
}
