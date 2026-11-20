//! Independent GPT Byte Fixtures

const std = @import("std");

const layout = @import("tests").fast.constants.gpt.layout;

const Disk = @import("tests").fast.types.gpt.disk.Disk;
const Volume = @import("shared").boot.types.volume.Volume;

pub fn volume() Volume {
    return .{
        .DiskGUID = layout.DISK_GUID,
        .PartitionGUID = layout.PARTITION_GUID,
        .FirstLBA = layout.VOLUME_FIRST,
        .LastLBA = layout.VOLUME_LAST,
        .DiskLastLBA = layout.DISK_LAST_LBA,
        .BlockBytes = layout.BLOCK_BYTES,
    };
}

pub fn make() Disk {
    var disk: Disk = .{};
    @memcpy(disk.Primary[0..8], &[_]u8{ 'E', 'F', 'I', ' ', 'P', 'A', 'R', 'T' });
    std.mem.writeInt(u32, disk.Primary[8..12], 0x10000, .little);
    std.mem.writeInt(u32, disk.Primary[12..16], layout.HEADER_BYTES, .little);
    std.mem.writeInt(u64, disk.Primary[24..32], 1, .little);
    std.mem.writeInt(u64, disk.Primary[32..40], layout.DISK_LAST_LBA, .little);
    std.mem.writeInt(u64, disk.Primary[40..48], layout.FIRST_USABLE, .little);
    std.mem.writeInt(u64, disk.Primary[48..56], layout.LAST_USABLE, .little);
    @memcpy(disk.Primary[56..72], &layout.DISK_GUID);
    std.mem.writeInt(u64, disk.Primary[72..80], layout.TABLE_LBA, .little);
    std.mem.writeInt(u32, disk.Primary[80..84], layout.ENTRY_COUNT, .little);
    std.mem.writeInt(u32, disk.Primary[84..88], layout.ENTRY_BYTES, .little);
    @memcpy(disk.Table[0..16], &layout.AFS_TYPE);
    @memcpy(disk.Table[16..32], &layout.PARTITION_GUID);
    std.mem.writeInt(u64, disk.Table[32..40], layout.VOLUME_FIRST, .little);
    std.mem.writeInt(u64, disk.Table[40..48], layout.VOLUME_LAST, .little);
    seal(&disk, layout.TABLE_BYTES);
    return disk;
}

pub fn seal(disk: *Disk, table_bytes: usize) void {
    std.mem.writeInt(u32, disk.Primary[88..92], std.hash.Crc32.hash(disk.Table[0..table_bytes]), .little);
    @memset(disk.Primary[16..20], 0);
    std.mem.writeInt(u32, disk.Primary[16..20], std.hash.Crc32.hash(disk.Primary[0..layout.HEADER_BYTES]), .little);
}
