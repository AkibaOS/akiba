//! Protective MBR Writing

const std = @import("std");

const constants = @import("mkafsdisk").constants;

const disk = constants.disk;
const gpt = constants.gpt;

pub fn writeProtectiveMbr(file: std.fs.File, total_sectors: u32) !void {
    var mbr: [disk.SECTOR_SIZE]u8 = [_]u8{0} ** disk.SECTOR_SIZE;

    mbr[gpt.MBR_PARTITION_OFFSET + gpt.MBR_ENTRY_TYPE_OFFSET] = gpt.MBR_PROTECTIVE_TYPE;
    std.mem.writeInt(u32, mbr[gpt.MBR_PARTITION_OFFSET + gpt.MBR_ENTRY_FIRST_LBA_OFFSET ..][0..@sizeOf(u32)], 1, .little);
    std.mem.writeInt(u32, mbr[gpt.MBR_PARTITION_OFFSET + gpt.MBR_ENTRY_SECTOR_COUNT_OFFSET ..][0..@sizeOf(u32)], total_sectors - 1, .little);

    mbr[gpt.MBR_SIGNATURE_OFFSET] = gpt.MBR_SIGNATURE_LOW;
    mbr[gpt.MBR_SIGNATURE_OFFSET + 1] = gpt.MBR_SIGNATURE_HIGH;

    try file.seekTo(0);
    try file.writeAll(&mbr);
}
