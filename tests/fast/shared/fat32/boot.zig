//! FAT32 Boot Metadata Checks

const std = @import("std");

const constants = @import("tests").fast.constants.storage;
const creation = @import("shared").fat32.types.creation;
const operations = @import("shared").fat32.write.boot;

pub fn bootConstruction() !void {
    const sector = operations.createBootSector(.{
        .TotalSectors = 1024,
        .HiddenSectors = 2048,
        .SectorsPerCluster = 8,
        .VolumeId = 0x44332211,
        .VolumeLabel = "HOST TEST  ".*,
    });
    try std.testing.expect(sector.isValid());
    try std.testing.expectEqual(@as(usize, constants.FAT_SECTOR_BYTES), @sizeOf(@TypeOf(sector)));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xeb, 0x58, 0x90 }, &sector.JumpBoot);
    try std.testing.expectEqualSlices(u8, "MSWIN4.1", &sector.OemName);
    try std.testing.expectEqual(@as(u16, 512), sector.BytesPerSector);
    try std.testing.expectEqual(@as(u8, 8), sector.SectorsPerCluster);
    try std.testing.expectEqual(@as(u16, 32), sector.ReservedSectors);
    try std.testing.expectEqual(@as(u8, 2), sector.FatCount);
    try std.testing.expectEqual(@as(u32, 1), sector.FatSize32);
    try std.testing.expectEqual(@as(u32, 2048), sector.HiddenSectors);
    try std.testing.expectEqual(@as(u32, 1024), sector.TotalSectors32);
    try std.testing.expectEqual(@as(u32, 2), sector.RootCluster);
    try std.testing.expectEqual(@as(u16, 1), sector.FsInfoSector);
    try std.testing.expectEqual(@as(u16, 6), sector.BackupBootSector);
    try std.testing.expectEqual(@as(u8, 0xf8), sector.MediaType);
    try std.testing.expectEqual(@as(u8, 0x80), sector.DriveNumber);
    try std.testing.expectEqual(@as(u8, 0x29), sector.BootSignature);
    try std.testing.expectEqualSlices(u8, "HOST TEST  ", &sector.VolumeLabel);
    try std.testing.expectEqualSlices(u8, "FAT32   ", &sector.FsType);
    try std.testing.expectEqual(@as(u16, 0), sector.RootEntryCount);
    try std.testing.expectEqual(@as(u16, 0), sector.TotalSectors16);
    try std.testing.expectEqual(@as(u16, 0), sector.FatSize16);
    try std.testing.expectEqual(@as(u16, 0), sector.ExtFlags);
    try std.testing.expectEqual(@as(u16, 0), sector.FsVersion);
    try std.testing.expectEqual(@as(u8, 0), sector.Reserved1);
    try std.testing.expectEqualSlices(u8, &([_]u8{0} ** 12), &sector.Reserved);
    try std.testing.expectEqualSlices(u8, &([_]u8{0} ** 420), &sector.BootCode);
    const bytes = std.mem.asBytes(&sector);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x02, 8, 32, 0, 2, 0, 0 }, bytes[11..19]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x11, 0x22, 0x33, 0x44 }, bytes[constants.FAT_VOLUME_OFFSET..][0..@sizeOf(u32)]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x55, 0xaa }, bytes[constants.FAT_SIGNATURE_OFFSET..]);
}

pub fn geometryAndFatSizing() !void {
    var params = creation.CreateParams{ .TotalSectors = 1024, .SectorsPerCluster = 8 };
    try std.testing.expectEqual(@as(u32, 1), operations.calculateFatSize(params));
    params.TotalSectors = 1040;
    try std.testing.expectEqual(@as(u32, 1), operations.calculateFatSize(params));
    params.TotalSectors = 1048;
    try std.testing.expectEqual(@as(u32, 2), operations.calculateFatSize(params));
    params.TotalSectors = 1024;
    const sector = operations.createBootSector(params);
    try std.testing.expectEqual(@as(u32, 32), sector.getFatStartSector());
    try std.testing.expectEqual(@as(u32, 34), sector.getDataStartSector());
    try std.testing.expectEqual(@as(u32, 123), sector.getTotalClusters());
    try std.testing.expectEqual(@as(u32, 34), sector.clusterToSector(2));
    try std.testing.expectEqual(@as(u32, 42), sector.clusterToSector(3));
    try std.testing.expectEqual(@as(u32, 90), sector.clusterToSector(9));
    try std.testing.expectEqual(@as(u32, 4096), sector.getBytesPerCluster());
}

pub fn bootValidation() !void {
    var sector = operations.createBootSector(.{ .TotalSectors = 1024, .SectorsPerCluster = 8 });
    sector.Signature ^= 1;
    try std.testing.expect(!sector.isValid());
    sector.Signature ^= 1;
    sector.BytesPerSector = 511;
    try std.testing.expect(!sector.isValid());
    sector.BytesPerSector = 4097;
    try std.testing.expect(!sector.isValid());
    sector.BytesPerSector = 4096;
    try std.testing.expect(sector.isValid());
    sector.BytesPerSector = 513;
    try std.testing.expect(sector.isValid());
    sector.BytesPerSector = 512;
    sector.SectorsPerCluster = 0;
    try std.testing.expect(!sector.isValid());
    sector.SectorsPerCluster = 3;
    try std.testing.expect(sector.isValid());
    sector.FatCount = 0;
    try std.testing.expect(!sector.isValid());
    sector.FatCount = 2;
    sector.FatSize32 = 0;
    try std.testing.expect(!sector.isValid());
    sector.FatSize32 = 1;
    try std.testing.expect(sector.isValid());
}

pub fn fsInfoConstructionAndValidation() !void {
    var info = operations.createFsInfo(0x12345678, 0x11223344);
    try std.testing.expect(info.isValid());
    try std.testing.expectEqual(@as(usize, constants.FAT_SECTOR_BYTES), @sizeOf(@TypeOf(info)));
    try std.testing.expectEqual(@as(u32, 0x12345678), info.FreeClusterCount);
    try std.testing.expectEqual(@as(u32, 0x11223344), info.NextFreeCluster);
    try std.testing.expectEqualSlices(u8, &([_]u8{0} ** 480), &info.Reserved1);
    try std.testing.expectEqualSlices(u8, &([_]u8{0} ** 12), &info.Reserved2);
    const bytes = std.mem.asBytes(&info);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x52, 0x52, 0x61, 0x41 }, bytes[0..@sizeOf(u32)]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x72, 0x72, 0x41, 0x61 }, bytes[constants.FSINFO_SECOND_SIGNATURE_OFFSET..][0..@sizeOf(u32)]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x78, 0x56, 0x34, 0x12, 0x44, 0x33, 0x22, 0x11 }, bytes[constants.FSINFO_HINTS_OFFSET..][0 .. 2 * @sizeOf(u32)]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0x55, 0xaa }, bytes[constants.FSINFO_TRAILER_OFFSET..]);
    info.Signature1 ^= 1;
    try std.testing.expect(!info.isValid());
    info.Signature1 ^= 1;
    info.Signature2 ^= 1;
    try std.testing.expect(!info.isValid());
    info.Signature2 ^= 1;
    info.Signature3 ^= 1;
    try std.testing.expect(!info.isValid());
    info.Signature3 ^= 1;
    try std.testing.expect(info.isValid());
    const unknown = operations.createFsInfo(std.math.maxInt(u32), std.math.maxInt(u32));
    try std.testing.expect(unknown.isValid());
    try std.testing.expectEqual(@as(u32, 0xffffffff), unknown.FreeClusterCount);
    try std.testing.expectEqual(@as(u32, 0xffffffff), unknown.NextFreeCluster);
}
