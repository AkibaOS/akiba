//! FAT ESP Metadata And Bootloader Image Integration Checks

const std = @import("std");

const constants = @import("tests").constants.image;
const fat32 = @import("shared").fat32;
const io = @import("tests").fast.toolchain.image.io;
const strings = @import("tests").strings.image;

const BootSector = fat32.types.boot.BootSector;
const FsInfo = fat32.types.boot.FsInfo;
const StackEntry = fat32.types.entry.StackEntry;

pub fn bootMetadata(file: std.fs.File) !BootSector {
    var primary: [constants.SECTOR_BYTES]u8 = undefined;
    var backup: [constants.SECTOR_BYTES]u8 = undefined;
    try io.readExact(file, constants.ESP_FIRST_LBA * constants.SECTOR_BYTES, &primary);
    var boot: BootSector = undefined;
    @memcpy(std.mem.asBytes(&boot), primary[0..@sizeOf(BootSector)]);
    try std.testing.expect(boot.isValid());
    try std.testing.expectEqual(@as(u16, 512), boot.BytesPerSector);
    try std.testing.expectEqual(@as(u8, 1), boot.SectorsPerCluster);
    try std.testing.expectEqual(@as(u16, 32), boot.ReservedSectors);
    try std.testing.expectEqual(@as(u8, 2), boot.FatCount);
    try std.testing.expectEqual(@as(u32, 2048), boot.HiddenSectors);
    try std.testing.expectEqual(constants.ESP_SECTORS, boot.TotalSectors32);
    try std.testing.expectEqual(constants.FAT_SECTORS, boot.FatSize32);
    try std.testing.expectEqual(@as(u32, 2), boot.RootCluster);
    try std.testing.expectEqual(@as(u16, 1), boot.FsInfoSector);
    try std.testing.expectEqual(@as(u16, 6), boot.BackupBootSector);
    try std.testing.expectEqual(@as(u32, 68528), boot.getTotalClusters());
    try std.testing.expect(boot.getTotalClusters() >= 65525);
    try io.readExact(file, (constants.ESP_FIRST_LBA + boot.BackupBootSector) * constants.SECTOR_BYTES, &backup);
    try std.testing.expectEqualSlices(u8, &primary, &backup);
    var information: FsInfo = undefined;
    try io.readExact(file, (constants.ESP_FIRST_LBA + boot.FsInfoSector) * constants.SECTOR_BYTES, std.mem.asBytes(&information));
    try std.testing.expect(information.isValid());
    try std.testing.expectEqual(std.math.maxInt(u32), information.FreeClusterCount);
    try std.testing.expectEqual(std.math.maxInt(u32), information.NextFreeCluster);
    return boot;
}

pub fn bootloaderChainAndPadding(file: std.fs.File, boot: *const BootSector) !void {
    const table = try std.testing.allocator.alloc(u8, constants.FAT_BYTES);
    defer std.testing.allocator.free(table);
    const first_fat = constants.ESP_FIRST_LBA + boot.getFatStartSector();
    try io.readExact(file, first_fat * constants.SECTOR_BYTES, table);
    var sector: [constants.SECTOR_BYTES]u8 = undefined;
    for (0..constants.FAT_SECTORS) |index| {
        const mirror_lba = first_fat + boot.FatSize32 + index;
        try io.readExact(file, mirror_lba * constants.SECTOR_BYTES, &sector);
        try std.testing.expectEqualSlices(u8, table[index * constants.SECTOR_BYTES ..][0..constants.SECTOR_BYTES], &sector);
    }
    const efi = try findEntry(file, boot, boot.RootCluster, strings.EFI_NAME);
    try std.testing.expect(efi.isStack());
    const directory = try findEntry(file, boot, efi.getFirstCluster(), strings.BOOT_NAME);
    try std.testing.expect(directory.isStack());
    const loader = try findEntry(file, boot, directory.getFirstCluster(), strings.BOOTLOADER_NAME);
    try std.testing.expect(!loader.isStack());
    try std.testing.expectEqual(@as(u32, constants.BOOTLOADER_BYTES.len), loader.UnitSize);
    try std.testing.expect((try nextCluster(table, boot.RootCluster)) == null);
    try std.testing.expect((try nextCluster(table, efi.getFirstCluster())) == null);
    try std.testing.expect((try nextCluster(table, directory.getFirstCluster())) == null);
    const current = try findEntry(file, boot, directory.getFirstCluster(), strings.CURRENT_NAME);
    const parent = try findEntry(file, boot, directory.getFirstCluster(), strings.PARENT_NAME);
    try std.testing.expectEqual(directory.getFirstCluster(), current.getFirstCluster());
    try std.testing.expectEqual(efi.getFirstCluster(), parent.getFirstCluster());
    var cluster = loader.getFirstCluster();
    var copied: usize = 0;
    for (0..2) |index| {
        try std.testing.expect(fat32.read.cluster.isValidCluster(cluster));
        try std.testing.expect(cluster != boot.RootCluster and cluster != efi.getFirstCluster() and cluster != directory.getFirstCluster());
        const lba = constants.ESP_FIRST_LBA + boot.clusterToSector(cluster);
        try std.testing.expect(lba <= constants.ESP_LAST_LBA);
        try io.readExact(file, lba * constants.SECTOR_BYTES, &sector);
        const count = @min(constants.BOOTLOADER_BYTES.len - copied, sector.len);
        try std.testing.expectEqualSlices(u8, constants.BOOTLOADER_BYTES[copied..][0..count], sector[0..count]);
        copied += count;
        const next = try nextCluster(table, cluster);
        if (index == 0) {
            try std.testing.expect(next != null and next.? != cluster);
            cluster = next.?;
        } else {
            try std.testing.expect(next == null);
            try io.expectZeros(sector[count..]);
        }
    }
    try std.testing.expectEqual(constants.BOOTLOADER_BYTES.len, copied);
}

fn findEntry(file: std.fs.File, boot: *const BootSector, cluster: u32, identity: []const u8) !StackEntry {
    var sector: [constants.SECTOR_BYTES]u8 = undefined;
    try io.readExact(file, (constants.ESP_FIRST_LBA + boot.clusterToSector(cluster)) * constants.SECTOR_BYTES, &sector);
    var offset: usize = 0;
    while (offset < sector.len) : (offset += @sizeOf(StackEntry)) {
        const entry: *align(1) const StackEntry = @ptrCast(sector[offset..].ptr);
        if (entry.isEnd()) break;
        if (!entry.isFree() and !entry.isLongIdentity() and fat32.read.stack.entryMatchesIdentity(entry, identity)) return entry.*;
    }
    try std.testing.expect(false);
    unreachable;
}

fn nextCluster(table: []const u8, cluster: u32) !?u32 {
    const position = fat32.read.cluster.getFatPosition(cluster, constants.SECTOR_BYTES);
    const offset = @as(usize, position.Sector) * constants.SECTOR_BYTES + position.Offset;
    try std.testing.expect(offset + @sizeOf(u32) <= table.len);
    return fat32.read.cluster.parseFatEntry(std.mem.readInt(u32, table[offset..][0..4], .little));
}
