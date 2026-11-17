//! Protective MBR Writing

const std = @import("std");

const constants = @import("mkafsdisk").constants;
const errors = @import("mkafsdisk").errors;

const disk = constants.disk;
const gpt = constants.gpt;

pub fn writeProtectiveMbr(file: std.fs.File, total_sectors: u64) !void {
    if (total_sectors <= 1) return errors.planning.PlanningError.InvalidGeometry;
    var mbr: [disk.SECTOR_SIZE]u8 = [_]u8{0} ** disk.SECTOR_SIZE;

    mbr[gpt.MBR_PARTITION_OFFSET + gpt.MBR_ENTRY_TYPE_OFFSET] = gpt.MBR_PROTECTIVE_TYPE;
    std.mem.writeInt(u32, mbr[gpt.MBR_PARTITION_OFFSET + gpt.MBR_ENTRY_FIRST_LBA_OFFSET ..][0..@sizeOf(u32)], 1, .little);
    std.mem.writeInt(u32, mbr[gpt.MBR_PARTITION_OFFSET + gpt.MBR_ENTRY_SECTOR_COUNT_OFFSET ..][0..@sizeOf(u32)], @intCast(@min(total_sectors - 1, std.math.maxInt(u32))), .little);

    mbr[gpt.MBR_SIGNATURE_OFFSET] = gpt.MBR_SIGNATURE_LOW;
    mbr[gpt.MBR_SIGNATURE_OFFSET + 1] = gpt.MBR_SIGNATURE_HIGH;

    try file.seekTo(0);
    try file.writeAll(&mbr);
}
