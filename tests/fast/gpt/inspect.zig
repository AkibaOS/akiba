//! Native GPT Integrity And Identity Regressions

const std = @import("std");

const layout = @import("tests").fast.constants.gpt.layout;
const shared = @import("shared");

const Disk = @import("tests").fast.types.gpt.disk.Disk;
const Volume = shared.boot.types.volume.Volume;
const header = shared.gpt.read.header;
const identity = shared.gpt.read.identity;

pub fn exactVolume() !void {
    var disk = fixture();
    @memset(disk.Table[layout.TABLE_BYTES..], 0xa7);
    @memcpy(disk.Table[2 * layout.ENTRY_BYTES + 16 ..][0..16], &layout.PARTITION_GUID);
    seal(&disk);
    const plan = try header.inspect(&disk.Primary, layout.DISK_LAST_LBA);
    try std.testing.expectEqual(@as(u64, layout.TABLE_LBA), plan.TableLBA);
    try std.testing.expectEqual(@as(u64, layout.TABLE_BYTES), plan.TableBytes);
    try std.testing.expectEqual(@as(u64, 1), plan.TableSectors);
    try std.testing.expect(try identity.match(volume(), &disk.Primary, layout.DISK_LAST_LBA, &disk.Table));
}

pub fn unrelatedVolume() !void {
    var disk = fixture();
    var handoff = volume();
    handoff.DiskGUID[0] ^= 1;
    try std.testing.expect(!try identity.match(handoff, &disk.Primary, layout.DISK_LAST_LBA, &.{}));
    try std.testing.expect(!try identity.match(volume(), &disk.Primary, layout.DISK_LAST_LBA + 1, &.{}));
    handoff = volume();
    handoff.PartitionGUID[0] ^= 1;
    try std.testing.expect(!try identity.match(handoff, &disk.Primary, layout.DISK_LAST_LBA, &disk.Table));
    handoff = volume();
    handoff.LastLBA -= 1;
    try std.testing.expect(!try identity.match(handoff, &disk.Primary, layout.DISK_LAST_LBA, &disk.Table));
    disk.Table[0] ^= 1;
    seal(&disk);
    try std.testing.expect(!try identity.match(volume(), &disk.Primary, layout.DISK_LAST_LBA, &disk.Table));
}

pub fn corruptedData() !void {
    var disk = fixture();
    disk.Primary[56] ^= 1;
    try std.testing.expectError(error.HeaderChecksum, header.inspect(&disk.Primary, layout.DISK_LAST_LBA));
    disk = fixture();
    disk.Table[layout.TABLE_BYTES - 1] ^= 1;
    try std.testing.expectError(error.TableChecksum, identity.match(volume(), &disk.Primary, layout.DISK_LAST_LBA, &disk.Table));
    try std.testing.expectError(error.InvalidTable, identity.match(volume(), &disk.Primary, layout.DISK_LAST_LBA, disk.Table[0 .. layout.TABLE_BYTES - 1]));
}

pub fn invalidLayout() !void {
    var disk = fixture();
    std.mem.writeInt(u32, disk.Primary[12..16], 91, .little);
    seal(&disk);
    try std.testing.expectError(error.InvalidHeader, header.inspect(&disk.Primary, layout.DISK_LAST_LBA));
    disk = fixture();
    std.mem.writeInt(u32, disk.Primary[80..84], std.math.maxInt(u32), .little);
    seal(&disk);
    try std.testing.expectError(error.InvalidTable, header.inspect(&disk.Primary, layout.DISK_LAST_LBA));
    disk = fixture();
    std.mem.writeInt(u32, disk.Primary[84..88], 129, .little);
    seal(&disk);
    try std.testing.expectError(error.InvalidTable, header.inspect(&disk.Primary, layout.DISK_LAST_LBA));
    disk = fixture();
    std.mem.writeInt(u64, disk.Primary[72..80], layout.FIRST_USABLE, .little);
    seal(&disk);
    try std.testing.expectError(error.InvalidTable, header.inspect(&disk.Primary, layout.DISK_LAST_LBA));
    disk = fixture();
    std.mem.writeInt(u64, disk.Primary[48..56], layout.DISK_LAST_LBA - 1, .little);
    seal(&disk);
    try std.testing.expectError(error.InvalidTable, header.inspect(&disk.Primary, layout.DISK_LAST_LBA));
}

pub fn ambiguousIdentity() !void {
    var disk = fixture();
    @memcpy(disk.Table[layout.ENTRY_BYTES..][0..48], disk.Table[0..48]);
    std.mem.writeInt(u64, disk.Table[layout.ENTRY_BYTES + 40 ..][0..8], layout.VOLUME_LAST + 1, .little);
    seal(&disk);
    try std.testing.expectError(error.AmbiguousPartition, identity.match(volume(), &disk.Primary, layout.DISK_LAST_LBA, &disk.Table));
}

fn volume() Volume {
    return .{
        .DiskGUID = layout.DISK_GUID,
        .PartitionGUID = layout.PARTITION_GUID,
        .FirstLBA = layout.VOLUME_FIRST,
        .LastLBA = layout.VOLUME_LAST,
        .DiskLastLBA = layout.DISK_LAST_LBA,
        .BlockBytes = layout.BLOCK_BYTES,
    };
}

fn fixture() Disk {
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
    seal(&disk);
    return disk;
}

fn seal(disk: *Disk) void {
    std.mem.writeInt(u32, disk.Primary[88..92], std.hash.Crc32.hash(disk.Table[0..layout.TABLE_BYTES]), .little);
    @memset(disk.Primary[16..20], 0);
    std.mem.writeInt(u32, disk.Primary[16..20], std.hash.Crc32.hash(disk.Primary[0..layout.HEADER_BYTES]), .little);
}
