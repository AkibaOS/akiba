//! FAT32 Boot Sector (BPB)

const constants = @import("../constants/constants.zig");

pub const BootSector = extern struct {
    jump_boot: [3]u8,
    oem_name: [8]u8,
    bytes_per_sector: u16 align(1),
    sectors_per_cluster: u8,
    reserved_sectors: u16 align(1),
    fat_count: u8,
    root_entry_count: u16 align(1), // Must be 0 for FAT32
    total_sectors_16: u16 align(1), // Must be 0 for FAT32
    media_type: u8,
    fat_size_16: u16 align(1), // Must be 0 for FAT32
    sectors_per_track: u16 align(1),
    head_count: u16 align(1),
    hidden_sectors: u32 align(1),
    total_sectors_32: u32 align(1),
    // FAT32 extended BPB
    fat_size_32: u32 align(1),
    ext_flags: u16 align(1),
    fs_version: u16 align(1),
    root_cluster: u32 align(1),
    fsinfo_sector: u16 align(1),
    backup_boot_sector: u16 align(1),
    reserved: [12]u8,
    drive_number: u8,
    reserved1: u8,
    boot_sig: u8,
    volume_id: u32 align(1),
    volume_label: [11]u8,
    fs_type: [8]u8,
    boot_code: [420]u8,
    signature: u16 align(1),

    pub fn is_valid(self: *const BootSector) bool {
        if (self.signature != constants.boot_signature) {
            return false;
        }
        if (self.bytes_per_sector < constants.sector_size_min or
            self.bytes_per_sector > constants.sector_size_max)
        {
            return false;
        }
        if (self.sectors_per_cluster == 0) {
            return false;
        }
        if (self.fat_count == 0) {
            return false;
        }
        if (self.fat_size_32 == 0) {
            return false;
        }
        return true;
    }

    pub fn get_fat_start_sector(self: *const BootSector) u32 {
        return self.reserved_sectors;
    }

    pub fn get_data_start_sector(self: *const BootSector) u32 {
        return self.reserved_sectors + (@as(u32, self.fat_count) * self.fat_size_32);
    }

    pub fn get_total_clusters(self: *const BootSector) u32 {
        const data_sectors = self.total_sectors_32 - self.get_data_start_sector();
        return data_sectors / self.sectors_per_cluster;
    }

    pub fn cluster_to_sector(self: *const BootSector, cluster: u32) u32 {
        return self.get_data_start_sector() + ((cluster - 2) * self.sectors_per_cluster);
    }

    pub fn get_bytes_per_cluster(self: *const BootSector) u32 {
        return @as(u32, self.bytes_per_sector) * self.sectors_per_cluster;
    }
};

pub const FsInfo = extern struct {
    signature_1: u32 align(1),
    reserved_1: [480]u8,
    signature_2: u32 align(1),
    free_cluster_count: u32 align(1),
    next_free_cluster: u32 align(1),
    reserved_2: [12]u8,
    signature_3: u32 align(1),

    pub fn is_valid(self: *const FsInfo) bool {
        return self.signature_1 == constants.fsinfo_sig1 and
            self.signature_2 == constants.fsinfo_sig2 and
            self.signature_3 == constants.fsinfo_sig3;
    }
};
