//! Native GPT Integrity And Identity Regressions

const std = @import("std");

const fixture = @import("tests").fast.gpt.fixture;
const layout = @import("tests").fast.constants.gpt.layout;
const shared = @import("shared");

const header = shared.gpt.read.header;
const identity = shared.gpt.read.identity;

pub fn exactVolume() !void {
    var disk = fixture.make();
    @memset(disk.Table[layout.TABLE_BYTES..], 0xa7);
    @memcpy(disk.Table[2 * layout.ENTRY_BYTES + 16 ..][0..16], &layout.PARTITION_GUID);
    fixture.seal(&disk, layout.TABLE_BYTES);
    const plan = try header.inspect(&disk.Primary, layout.DISK_LAST_LBA);
    try std.testing.expectEqual(@as(u64, layout.TABLE_LBA), plan.TableLBA);
    try std.testing.expectEqual(@as(u64, layout.TABLE_BYTES), plan.TableBytes);
    try std.testing.expectEqual(@as(u64, 1), plan.TableSectors);
    try std.testing.expect(try identity.match(fixture.volume(), &disk.Primary, layout.DISK_LAST_LBA, &disk.Table));
}

pub fn unrelatedVolume() !void {
    var disk = fixture.make();
    var handoff = fixture.volume();
    handoff.DiskGUID[0] ^= 1;
    try std.testing.expect(!try identity.match(handoff, &disk.Primary, layout.DISK_LAST_LBA, &.{}));
    try std.testing.expect(!try identity.match(fixture.volume(), &disk.Primary, layout.DISK_LAST_LBA + 1, &.{}));
    handoff = fixture.volume();
    handoff.PartitionGUID[0] ^= 1;
    try std.testing.expect(!try identity.match(handoff, &disk.Primary, layout.DISK_LAST_LBA, &disk.Table));
    handoff = fixture.volume();
    handoff.LastLBA -= 1;
    try std.testing.expect(!try identity.match(handoff, &disk.Primary, layout.DISK_LAST_LBA, &disk.Table));
    disk.Table[0] ^= 1;
    fixture.seal(&disk, layout.TABLE_BYTES);
    try std.testing.expect(!try identity.match(fixture.volume(), &disk.Primary, layout.DISK_LAST_LBA, &disk.Table));
}

pub fn corruptedData() !void {
    var disk = fixture.make();
    disk.Primary[56] ^= 1;
    try std.testing.expectError(error.HeaderChecksum, header.inspect(&disk.Primary, layout.DISK_LAST_LBA));
    disk = fixture.make();
    disk.Table[layout.TABLE_BYTES - 1] ^= 1;
    try std.testing.expectError(error.TableChecksum, identity.match(fixture.volume(), &disk.Primary, layout.DISK_LAST_LBA, &disk.Table));
    try std.testing.expectError(error.InvalidTable, identity.match(fixture.volume(), &disk.Primary, layout.DISK_LAST_LBA, disk.Table[0 .. layout.TABLE_BYTES - 1]));
}

pub fn invalidLayout() !void {
    var disk = fixture.make();
    std.mem.writeInt(u32, disk.Primary[12..16], 91, .little);
    fixture.seal(&disk, layout.TABLE_BYTES);
    try std.testing.expectError(error.InvalidHeader, header.inspect(&disk.Primary, layout.DISK_LAST_LBA));
    disk = fixture.make();
    std.mem.writeInt(u32, disk.Primary[80..84], std.math.maxInt(u32), .little);
    fixture.seal(&disk, layout.TABLE_BYTES);
    try std.testing.expectError(error.InvalidTable, header.inspect(&disk.Primary, layout.DISK_LAST_LBA));
    disk = fixture.make();
    std.mem.writeInt(u32, disk.Primary[84..88], 129, .little);
    fixture.seal(&disk, layout.TABLE_BYTES);
    try std.testing.expectError(error.InvalidTable, header.inspect(&disk.Primary, layout.DISK_LAST_LBA));
    disk = fixture.make();
    std.mem.writeInt(u64, disk.Primary[72..80], layout.FIRST_USABLE, .little);
    fixture.seal(&disk, layout.TABLE_BYTES);
    try std.testing.expectError(error.InvalidTable, header.inspect(&disk.Primary, layout.DISK_LAST_LBA));
    disk = fixture.make();
    std.mem.writeInt(u64, disk.Primary[48..56], layout.DISK_LAST_LBA - 1, .little);
    fixture.seal(&disk, layout.TABLE_BYTES);
    try std.testing.expectError(error.InvalidTable, header.inspect(&disk.Primary, layout.DISK_LAST_LBA));
}

pub fn ambiguousIdentity() !void {
    var disk = fixture.make();
    @memcpy(disk.Table[layout.ENTRY_BYTES..][0..48], disk.Table[0..48]);
    std.mem.writeInt(u64, disk.Table[layout.ENTRY_BYTES + 40 ..][0..8], layout.VOLUME_LAST + 1, .little);
    fixture.seal(&disk, layout.TABLE_BYTES);
    try std.testing.expectError(error.AmbiguousPartition, identity.match(fixture.volume(), &disk.Primary, layout.DISK_LAST_LBA, &disk.Table));
}
