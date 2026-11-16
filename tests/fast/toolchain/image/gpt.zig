//! GPT Header And Partition Image Integration Checks

const std = @import("std");

const constants = @import("tests").constants.image;
const io = @import("tests").fast.toolchain.image.io;
const strings = @import("tests").strings.image;

pub fn reciprocalHeaders(file: std.fs.File) !void {
    var primary: [constants.SECTOR_BYTES]u8 = undefined;
    var backup: [constants.SECTOR_BYTES]u8 = undefined;
    try io.readExact(file, constants.SECTOR_BYTES, &primary);
    try io.readExact(file, constants.BACKUP_HEADER_LBA * constants.SECTOR_BYTES, &backup);
    try expectHeader(&primary, 1, constants.BACKUP_HEADER_LBA, constants.PRIMARY_TABLE_LBA);
    try expectHeader(&backup, constants.BACKUP_HEADER_LBA, 1, constants.BACKUP_TABLE_LBA);
    try std.testing.expectEqualSlices(u8, primary[constants.HEADER_DISK_GUID..][0..constants.GUID_BYTES], backup[constants.HEADER_DISK_GUID..][0..constants.GUID_BYTES]);
    try std.testing.expectEqualSlices(u8, primary[constants.HEADER_FIRST_USABLE..constants.HEADER_DISK_GUID], backup[constants.HEADER_FIRST_USABLE..constants.HEADER_DISK_GUID]);
    try std.testing.expectEqualSlices(u8, primary[constants.HEADER_COUNT..constants.GPT_HEADER_BYTES], backup[constants.HEADER_COUNT..constants.GPT_HEADER_BYTES]);
    try std.testing.expect(constants.PRIMARY_TABLE_LBA * constants.SECTOR_BYTES + constants.GPT_TABLE_BYTES <= constants.FIRST_USABLE_LBA * constants.SECTOR_BYTES);
    try std.testing.expect(constants.AFS_LAST_LBA < constants.BACKUP_TABLE_LBA);
    try std.testing.expectEqual(constants.BACKUP_HEADER_LBA * constants.SECTOR_BYTES, constants.BACKUP_TABLE_LBA * constants.SECTOR_BYTES + constants.GPT_TABLE_BYTES);
}

pub fn mirroredPartitionTables(file: std.fs.File) !void {
    var primary: [constants.GPT_TABLE_BYTES]u8 = undefined;
    var backup: [constants.GPT_TABLE_BYTES]u8 = undefined;
    try io.readExact(file, constants.PRIMARY_TABLE_LBA * constants.SECTOR_BYTES, &primary);
    try io.readExact(file, constants.BACKUP_TABLE_LBA * constants.SECTOR_BYTES, &backup);
    try std.testing.expectEqualSlices(u8, &primary, &backup);
    const checksum = std.hash.Crc32.hash(&primary);
    var header: [constants.SECTOR_BYTES]u8 = undefined;
    try io.readExact(file, constants.SECTOR_BYTES, &header);
    try std.testing.expectEqual(checksum, std.mem.readInt(u32, header[constants.HEADER_TABLE_CRC..][0..4], .little));
    try io.readExact(file, constants.BACKUP_HEADER_LBA * constants.SECTOR_BYTES, &header);
    try std.testing.expectEqual(std.hash.Crc32.hash(&backup), std.mem.readInt(u32, header[constants.HEADER_TABLE_CRC..][0..4], .little));
    const esp = primary[0..constants.GPT_ENTRY_BYTES];
    const afs = primary[constants.GPT_ENTRY_BYTES..][0..constants.GPT_ENTRY_BYTES];
    try expectPartition(esp, &constants.ESP_TYPE_GUID, constants.ESP_FIRST_LBA, constants.ESP_LAST_LBA, strings.ESP_PARTITION_NAME);
    try expectPartition(afs, &constants.AFS_TYPE_GUID, constants.AFS_FIRST_LBA, constants.AFS_LAST_LBA, strings.AFS_PARTITION_NAME);
    try std.testing.expectEqual(constants.AFS_FIRST_LBA, constants.ESP_LAST_LBA + 1);
    try std.testing.expect(constants.ESP_FIRST_LBA >= constants.FIRST_USABLE_LBA);
    try std.testing.expectEqual(constants.AFS_LAST_LBA, std.mem.readInt(u64, header[constants.HEADER_LAST_USABLE..][0..8], .little));
    try std.testing.expect(!std.mem.eql(u8, esp[constants.ENTRY_UNIQUE_GUID..][0..constants.GUID_BYTES], afs[constants.ENTRY_UNIQUE_GUID..][0..constants.GUID_BYTES]));
    try io.expectZeros(primary[2 * constants.GPT_ENTRY_BYTES ..]);
}

fn expectHeader(sector: *const [constants.SECTOR_BYTES]u8, current: u64, alternate: u64, entries: u64) !void {
    try std.testing.expectEqualStrings(strings.GPT_SIGNATURE, sector[0..8]);
    try std.testing.expectEqual(@as(u32, 0x00010000), std.mem.readInt(u32, sector[constants.HEADER_REVISION..][0..4], .little));
    try std.testing.expectEqual(@as(u32, constants.GPT_HEADER_BYTES), std.mem.readInt(u32, sector[constants.HEADER_SIZE..][0..4], .little));
    try std.testing.expectEqual(current, std.mem.readInt(u64, sector[constants.HEADER_CURRENT..][0..8], .little));
    try std.testing.expectEqual(alternate, std.mem.readInt(u64, sector[constants.HEADER_BACKUP..][0..8], .little));
    try std.testing.expectEqual(constants.FIRST_USABLE_LBA, std.mem.readInt(u64, sector[constants.HEADER_FIRST_USABLE..][0..8], .little));
    try std.testing.expectEqual(constants.AFS_LAST_LBA, std.mem.readInt(u64, sector[constants.HEADER_LAST_USABLE..][0..8], .little));
    try std.testing.expectEqual(entries, std.mem.readInt(u64, sector[constants.HEADER_ENTRIES..][0..8], .little));
    try std.testing.expectEqual(constants.GPT_ENTRY_COUNT, std.mem.readInt(u32, sector[constants.HEADER_COUNT..][0..4], .little));
    try std.testing.expectEqual(@as(u32, constants.GPT_ENTRY_BYTES), std.mem.readInt(u32, sector[constants.HEADER_ENTRY_SIZE..][0..4], .little));
    try io.expectZeros(sector[constants.HEADER_RESERVED..][0..4]);
    try io.expectZeros(sector[constants.GPT_HEADER_BYTES..]);
    try std.testing.expect(!std.mem.eql(u8, sector[constants.HEADER_DISK_GUID..][0..constants.GUID_BYTES], &([_]u8{0} ** constants.GUID_BYTES)));
    const stored = std.mem.readInt(u32, sector[constants.HEADER_CRC..][0..4], .little);
    var checked = sector.*;
    @memset(checked[constants.HEADER_CRC..][0..4], 0);
    try std.testing.expectEqual(stored, std.hash.Crc32.hash(checked[0..constants.GPT_HEADER_BYTES]));
}

fn expectPartition(entry: []const u8, type_guid: []const u8, first: u64, last: u64, name: []const u8) !void {
    try std.testing.expectEqualSlices(u8, type_guid, entry[0..constants.GUID_BYTES]);
    try std.testing.expect(!std.mem.eql(u8, entry[constants.ENTRY_UNIQUE_GUID..][0..constants.GUID_BYTES], &([_]u8{0} ** constants.GUID_BYTES)));
    try std.testing.expectEqual(first, std.mem.readInt(u64, entry[constants.ENTRY_FIRST..][0..8], .little));
    try std.testing.expectEqual(last, std.mem.readInt(u64, entry[constants.ENTRY_LAST..][0..8], .little));
    try io.expectZeros(entry[constants.ENTRY_ATTRIBUTES..constants.ENTRY_NAME]);
    for (name, 0..) |character, index| {
        try std.testing.expectEqual(@as(u16, character), std.mem.readInt(u16, entry[constants.ENTRY_NAME + index * 2 ..][0..2], .little));
    }
    try io.expectZeros(entry[constants.ENTRY_NAME + name.len * 2 ..]);
}
