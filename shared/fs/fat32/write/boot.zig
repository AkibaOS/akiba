//! FAT32 Boot Sector Creation

const std = @import("std");
const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const BootSector = types.BootSector;
const FsInfo = types.FsInfo;

/// Parameters for creating a FAT32 filesystem
pub const CreateParams = struct {
    total_sectors: u32,
    hidden_sectors: u32 = 0,
    bytes_per_sector: u16 = 512,
    sectors_per_cluster: u8 = 1,
    reserved_sectors: u16 = 32,
    fat_count: u8 = 2,
    volume_id: u32 = 0x12345678,
    volume_label: [11]u8 = .{ 'N', 'O', ' ', 'N', 'A', 'M', 'E', ' ', ' ', ' ', ' ' },
};

/// Calculate FAT size in sectors
pub fn calculate_fat_size(params: CreateParams) u32 {
    const data_sectors = params.total_sectors - params.reserved_sectors;
    const cluster_count = data_sectors / params.sectors_per_cluster;
    // Each FAT entry is 4 bytes
    const fat_bytes = (cluster_count + 2) * 4;
    return (fat_bytes + params.bytes_per_sector - 1) / params.bytes_per_sector;
}

/// Create a boot sector structure
pub fn create_boot_sector(params: CreateParams) BootSector {
    const fat_size = calculate_fat_size(params);

    const boot = BootSector{
        .jump_boot = .{ 0xEB, 0x58, 0x90 },
        .oem_name = constants.default_oem_name,
        .bytes_per_sector = params.bytes_per_sector,
        .sectors_per_cluster = params.sectors_per_cluster,
        .reserved_sectors = params.reserved_sectors,
        .fat_count = params.fat_count,
        .root_entry_count = 0,
        .total_sectors_16 = 0,
        .media_type = constants.default_media_type,
        .fat_size_16 = 0,
        .sectors_per_track = 63,
        .head_count = 255,
        .hidden_sectors = params.hidden_sectors,
        .total_sectors_32 = params.total_sectors,
        .fat_size_32 = fat_size,
        .ext_flags = 0,
        .fs_version = 0,
        .root_cluster = 2,
        .fsinfo_sector = 1,
        .backup_boot_sector = 6,
        .reserved = [_]u8{0} ** 12,
        .drive_number = constants.default_drive_number,
        .reserved1 = 0,
        .boot_sig = constants.default_boot_sig,
        .volume_id = params.volume_id,
        .volume_label = params.volume_label,
        .fs_type = constants.fs_type_fat32,
        .boot_code = [_]u8{0} ** 420,
        .signature = constants.boot_signature,
    };

    return boot;
}

/// Create FSInfo structure
pub fn create_fsinfo(free_clusters: u32, next_free: u32) FsInfo {
    return FsInfo{
        .signature_1 = constants.fsinfo_sig1,
        .reserved_1 = [_]u8{0} ** 480,
        .signature_2 = constants.fsinfo_sig2,
        .free_cluster_count = free_clusters,
        .next_free_cluster = next_free,
        .reserved_2 = [_]u8{0} ** 12,
        .signature_3 = constants.fsinfo_sig3,
    };
}

/// Initialize FAT table with required entries
pub fn init_fat_table(fat: []u8) void {
    // Clear
    @memset(fat, 0);

    // Entry 0: Media type
    std.mem.writeInt(u32, fat[0..4], 0x0FFFFFF8, .little);
    // Entry 1: End of chain marker
    std.mem.writeInt(u32, fat[4..8], 0x0FFFFFFF, .little);
    // Entry 2: Origin stack EOC
    std.mem.writeInt(u32, fat[8..12], 0x0FFFFFFF, .little);
}

/// Allocate a cluster in the FAT
pub fn allocate_cluster(fat: []u8, cluster: u32) void {
    const offset = cluster * 4;
    if (offset + 4 <= fat.len) {
        std.mem.writeInt(u32, fat[offset..][0..4], constants.cluster_eoc, .little);
    }
}

/// Link two clusters in the FAT
pub fn link_clusters(fat: []u8, from: u32, to: u32) void {
    const offset = from * 4;
    if (offset + 4 <= fat.len) {
        std.mem.writeInt(u32, fat[offset..][0..4], to, .little);
    }
}
