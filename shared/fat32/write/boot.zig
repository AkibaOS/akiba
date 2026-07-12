//! FAT32 Boot Sector Creation

const std = @import("std");

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const BootSector = types.boot.BootSector;
const FsInfo = types.boot.FsInfo;

pub const CreateParams = struct {
    TotalSectors: u32,
    HiddenSectors: u32 = 0,
    BytesPerSector: u16 = constants.sizes.SECTOR_SIZE_MIN,
    SectorsPerCluster: u8 = constants.defaults.DEFAULT_SECTORS_PER_CLUSTER,
    ReservedSectors: u16 = constants.defaults.DEFAULT_RESERVED_SECTORS,
    FatCount: u8 = constants.defaults.DEFAULT_FAT_COUNT,
    VolumeId: u32 = constants.defaults.DEFAULT_VOLUME_ID,
    VolumeLabel: [11]u8 = constants.defaults.DEFAULT_VOLUME_LABEL,
};

pub fn calculateFatSize(params: CreateParams) u32 {
    const data_sectors = params.TotalSectors - params.ReservedSectors;
    const cluster_count = data_sectors / params.SectorsPerCluster;
    const fat_bytes = (cluster_count + constants.clusters.CLUSTER_DATA_START) * @sizeOf(u32);
    return (fat_bytes + params.BytesPerSector - 1) / params.BytesPerSector;
}

pub fn createBootSector(params: CreateParams) BootSector {
    const fat_size = calculateFatSize(params);

    return BootSector{
        .JumpBoot = constants.defaults.DEFAULT_JUMP_BOOT,
        .OemName = constants.defaults.DEFAULT_OEM_NAME,
        .BytesPerSector = params.BytesPerSector,
        .SectorsPerCluster = params.SectorsPerCluster,
        .ReservedSectors = params.ReservedSectors,
        .FatCount = params.FatCount,
        .RootEntryCount = 0,
        .TotalSectors16 = 0,
        .MediaType = constants.defaults.DEFAULT_MEDIA_TYPE,
        .FatSize16 = 0,
        .SectorsPerTrack = constants.defaults.DEFAULT_SECTORS_PER_TRACK,
        .HeadCount = constants.defaults.DEFAULT_HEAD_COUNT,
        .HiddenSectors = params.HiddenSectors,
        .TotalSectors32 = params.TotalSectors,
        .FatSize32 = fat_size,
        .ExtFlags = 0,
        .FsVersion = 0,
        .RootCluster = constants.clusters.CLUSTER_DATA_START,
        .FsInfoSector = constants.defaults.DEFAULT_FSINFO_SECTOR,
        .BackupBootSector = constants.defaults.DEFAULT_BACKUP_BOOT_SECTOR,
        .Reserved = [_]u8{0} ** 12,
        .DriveNumber = constants.defaults.DEFAULT_DRIVE_NUMBER,
        .Reserved1 = 0,
        .BootSignature = constants.defaults.DEFAULT_EXTENDED_BOOT_SIGNATURE,
        .VolumeId = params.VolumeId,
        .VolumeLabel = params.VolumeLabel,
        .FsType = constants.magic.FS_TYPE_FAT32,
        .BootCode = [_]u8{0} ** 420,
        .Signature = constants.magic.BOOT_SIGNATURE,
    };
}

pub fn createFsInfo(free_clusters: u32, next_free: u32) FsInfo {
    return FsInfo{
        .Signature1 = constants.magic.FSINFO_SIGNATURE_1,
        .Reserved1 = [_]u8{0} ** 480,
        .Signature2 = constants.magic.FSINFO_SIGNATURE_2,
        .FreeClusterCount = free_clusters,
        .NextFreeCluster = next_free,
        .Reserved2 = [_]u8{0} ** 12,
        .Signature3 = constants.magic.FSINFO_SIGNATURE_3,
    };
}

pub fn initFatTable(fat: []u8) void {
    @memset(fat, 0);

    std.mem.writeInt(u32, fat[0..][0..@sizeOf(u32)], constants.clusters.CLUSTER_EOC_START, .little);
    std.mem.writeInt(u32, fat[@sizeOf(u32)..][0..@sizeOf(u32)], constants.clusters.CLUSTER_EOC, .little);
    std.mem.writeInt(u32, fat[2 * @sizeOf(u32) ..][0..@sizeOf(u32)], constants.clusters.CLUSTER_EOC, .little);
}

pub fn allocateCluster(fat: []u8, cluster: u32) void {
    const offset = cluster * @sizeOf(u32);
    if (offset + @sizeOf(u32) <= fat.len) {
        std.mem.writeInt(u32, fat[offset..][0..@sizeOf(u32)], constants.clusters.CLUSTER_EOC, .little);
    }
}

pub fn linkClusters(fat: []u8, from: u32, to: u32) void {
    const offset = from * @sizeOf(u32);
    if (offset + @sizeOf(u32) <= fat.len) {
        std.mem.writeInt(u32, fat[offset..][0..@sizeOf(u32)], to, .little);
    }
}
