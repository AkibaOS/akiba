//! GPT Writing

const std = @import("std");

const afs = @import("shared").afs;

const constants = @import("../constants/constants.zig");
const strings = @import("../strings/strings.zig");

const disk = constants.disk;
const gpt = constants.gpt;
const names = strings.names;

pub fn calculateCRC32(data: []const u8) u32 {
    var crc: u32 = gpt.CRC32_INITIAL;
    for (data) |byte| {
        var value = (crc ^ byte) & 0xFF;
        var iteration: u8 = 0;
        while (iteration < @bitSizeOf(u8)) : (iteration += 1) {
            if (value & 1 != 0) {
                value = (value >> 1) ^ gpt.CRC32_POLYNOMIAL;
            } else {
                value >>= 1;
            }
        }
        crc = (crc >> @bitSizeOf(u8)) ^ value;
    }
    return ~crc;
}

fn writePartitionEntry(
    entries: []u8,
    slot: usize,
    type_guid: *const [16]u8,
    unique_guid: *const [16]u8,
    first_lba: u64,
    last_lba: u64,
    name: []const u8,
) void {
    const base = slot * gpt.PARTITION_ENTRY_SIZE;
    @memcpy(entries[base + gpt.ENTRY_OFFSET_TYPE_GUID ..][0..16], type_guid);
    @memcpy(entries[base + gpt.ENTRY_OFFSET_UNIQUE_GUID ..][0..16], unique_guid);
    std.mem.writeInt(u64, entries[base + gpt.ENTRY_OFFSET_FIRST_LBA ..][0..@sizeOf(u64)], first_lba, .little);
    std.mem.writeInt(u64, entries[base + gpt.ENTRY_OFFSET_LAST_LBA ..][0..@sizeOf(u64)], last_lba, .little);
    for (name, 0..) |char, index| {
        entries[base + gpt.ENTRY_OFFSET_NAME + index * @sizeOf(u16)] = char;
    }
}

pub fn writeGpt(
    file: std.fs.File,
    esp_start: u32,
    esp_end: u32,
    afs_start: u32,
    afs_end: u32,
    total_sectors: u32,
) !void {
    var partition_entries: [gpt.ENTRIES_BYTES]u8 = [_]u8{0} ** gpt.ENTRIES_BYTES;

    writePartitionEntry(&partition_entries, 0, &gpt.ESP_TYPE_GUID, &gpt.ESP_UNIQUE_GUID, esp_start, esp_end, names.ESP_PARTITION_NAME);
    writePartitionEntry(&partition_entries, 1, &afs.constants.magic.PARTITION_TYPE_GUID, &gpt.AFS_UNIQUE_GUID, afs_start, afs_end, names.AFS_PARTITION_NAME);

    const entries_crc = calculateCRC32(&partition_entries);

    var header: [disk.SECTOR_SIZE]u8 = [_]u8{0} ** disk.SECTOR_SIZE;
    @memcpy(header[gpt.HEADER_OFFSET_SIGNATURE..][0..8], names.GPT_SIGNATURE);
    std.mem.writeInt(u32, header[gpt.HEADER_OFFSET_REVISION..][0..@sizeOf(u32)], gpt.HEADER_REVISION, .little);
    std.mem.writeInt(u32, header[gpt.HEADER_OFFSET_HEADER_SIZE..][0..@sizeOf(u32)], gpt.HEADER_SIZE, .little);
    std.mem.writeInt(u64, header[gpt.HEADER_OFFSET_CURRENT_LBA..][0..@sizeOf(u64)], gpt.HEADER_LBA, .little);
    std.mem.writeInt(u64, header[gpt.HEADER_OFFSET_BACKUP_LBA..][0..@sizeOf(u64)], @as(u64, total_sectors) - 1, .little);
    std.mem.writeInt(u64, header[gpt.HEADER_OFFSET_FIRST_USABLE..][0..@sizeOf(u64)], disk.GPT_RESERVED_SECTORS, .little);
    std.mem.writeInt(u64, header[gpt.HEADER_OFFSET_LAST_USABLE..][0..@sizeOf(u64)], @as(u64, total_sectors) - disk.GPT_RESERVED_SECTORS, .little);
    @memcpy(header[gpt.HEADER_OFFSET_DISK_GUID..][0..16], &gpt.DISK_GUID);
    std.mem.writeInt(u64, header[gpt.HEADER_OFFSET_ENTRIES_LBA..][0..@sizeOf(u64)], gpt.ENTRIES_START_LBA, .little);
    std.mem.writeInt(u32, header[gpt.HEADER_OFFSET_ENTRY_COUNT..][0..@sizeOf(u32)], gpt.PARTITION_ENTRY_COUNT, .little);
    std.mem.writeInt(u32, header[gpt.HEADER_OFFSET_ENTRY_SIZE..][0..@sizeOf(u32)], gpt.PARTITION_ENTRY_SIZE, .little);
    std.mem.writeInt(u32, header[gpt.HEADER_OFFSET_ENTRIES_CRC..][0..@sizeOf(u32)], entries_crc, .little);

    const header_crc = calculateCRC32(header[0..gpt.HEADER_SIZE]);
    std.mem.writeInt(u32, header[gpt.HEADER_OFFSET_HEADER_CRC..][0..@sizeOf(u32)], header_crc, .little);

    try file.seekTo(disk.SECTOR_SIZE);
    try file.writeAll(&header);
    try file.seekTo(gpt.ENTRIES_START_LBA * disk.SECTOR_SIZE);
    try file.writeAll(&partition_entries);

    const backup_entries_lba = total_sectors - disk.GPT_BACKUP_ENTRIES_SECTORS;
    try file.seekTo(@as(u64, backup_entries_lba) * disk.SECTOR_SIZE);
    try file.writeAll(&partition_entries);

    var backup_header = header;
    std.mem.writeInt(u64, backup_header[gpt.HEADER_OFFSET_CURRENT_LBA..][0..@sizeOf(u64)], @as(u64, total_sectors) - 1, .little);
    std.mem.writeInt(u64, backup_header[gpt.HEADER_OFFSET_BACKUP_LBA..][0..@sizeOf(u64)], gpt.HEADER_LBA, .little);
    std.mem.writeInt(u64, backup_header[gpt.HEADER_OFFSET_ENTRIES_LBA..][0..@sizeOf(u64)], backup_entries_lba, .little);
    std.mem.writeInt(u32, backup_header[gpt.HEADER_OFFSET_HEADER_CRC..][0..@sizeOf(u32)], 0, .little);
    const backup_crc = calculateCRC32(backup_header[0..gpt.HEADER_SIZE]);
    std.mem.writeInt(u32, backup_header[gpt.HEADER_OFFSET_HEADER_CRC..][0..@sizeOf(u32)], backup_crc, .little);

    try file.seekTo(@as(u64, total_sectors - 1) * disk.SECTOR_SIZE);
    try file.writeAll(&backup_header);
}
