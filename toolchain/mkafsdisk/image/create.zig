//! Disk Image Creation

const std = @import("std");

const afs = @import("mkafsdisk").afs;
const constants = @import("mkafsdisk").constants;
const esp = @import("mkafsdisk").image.esp;
const gpt = @import("mkafsdisk").image.gpt;
const mbr = @import("mkafsdisk").image.mbr;
const strings = @import("mkafsdisk").strings;

const disk = constants.disk;
const messages = strings.messages;

pub fn createDiskImage(
    allocator: std.mem.Allocator,
    source_location: []const u8,
    output_path: []const u8,
    size_megabytes: u32,
) !void {
    const total_bytes: u64 = @as(u64, size_megabytes) * 1024 * 1024;
    const total_sectors: u32 = @intCast(total_bytes / disk.SECTOR_SIZE);

    const esp_start_sector: u32 = disk.ESP_START_SECTOR;
    const esp_end_sector: u32 = esp_start_sector + disk.ESP_SIZE_SECTORS - 1;
    const afs_start_sector: u32 = esp_end_sector + 1;
    const afs_end_sector: u32 = total_sectors - disk.GPT_RESERVED_SECTORS;

    std.debug.print(messages.ESP_RANGE, .{ esp_start_sector, esp_end_sector });
    std.debug.print(messages.AFS_RANGE, .{ afs_start_sector, afs_end_sector });

    const file = try std.fs.cwd().createFile(output_path, .{ .read = true });
    defer file.close();

    try file.setEndPos(total_bytes);

    try mbr.writeProtectiveMbr(file, total_sectors);
    try gpt.writeGpt(file, esp_start_sector, esp_end_sector, afs_start_sector, afs_end_sector, total_sectors);
    try esp.createEsp(allocator, file, source_location, esp_start_sector, disk.ESP_SIZE_SECTORS);

    const partition_start_byte: u64 = @as(u64, afs_start_sector) * disk.SECTOR_SIZE;
    const partition_size_bytes: u64 = @as(u64, afs_end_sector - afs_start_sector + 1) * disk.SECTOR_SIZE;

    var writer = afs.writer.Writer.initialize(
        file,
        partition_start_byte,
        partition_size_bytes,
        allocator,
    );

    try writer.createFilesystem(source_location);
}
