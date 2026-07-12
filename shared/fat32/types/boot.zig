//! FAT32 Boot Sector (BPB)

const constants = @import("../constants/constants.zig");

pub const BootSector = extern struct {
    JumpBoot: [3]u8,
    OemName: [8]u8,
    BytesPerSector: u16 align(1),
    SectorsPerCluster: u8,
    ReservedSectors: u16 align(1),
    FatCount: u8,
    RootEntryCount: u16 align(1),
    TotalSectors16: u16 align(1),
    MediaType: u8,
    FatSize16: u16 align(1),
    SectorsPerTrack: u16 align(1),
    HeadCount: u16 align(1),
    HiddenSectors: u32 align(1),
    TotalSectors32: u32 align(1),
    FatSize32: u32 align(1),
    ExtFlags: u16 align(1),
    FsVersion: u16 align(1),
    RootCluster: u32 align(1),
    FsInfoSector: u16 align(1),
    BackupBootSector: u16 align(1),
    Reserved: [12]u8,
    DriveNumber: u8,
    Reserved1: u8,
    BootSignature: u8,
    VolumeId: u32 align(1),
    VolumeLabel: [11]u8,
    FsType: [8]u8,
    BootCode: [420]u8,
    Signature: u16 align(1),

    pub fn isValid(self: *const BootSector) bool {
        if (self.Signature != constants.magic.BOOT_SIGNATURE) {
            return false;
        }
        if (self.BytesPerSector < constants.sizes.SECTOR_SIZE_MIN or
            self.BytesPerSector > constants.sizes.SECTOR_SIZE_MAX)
        {
            return false;
        }
        if (self.SectorsPerCluster == 0) {
            return false;
        }
        if (self.FatCount == 0) {
            return false;
        }
        if (self.FatSize32 == 0) {
            return false;
        }
        return true;
    }

    pub fn getFatStartSector(self: *const BootSector) u32 {
        return self.ReservedSectors;
    }

    pub fn getDataStartSector(self: *const BootSector) u32 {
        return self.ReservedSectors + (@as(u32, self.FatCount) * self.FatSize32);
    }

    pub fn getTotalClusters(self: *const BootSector) u32 {
        const data_sectors = self.TotalSectors32 - self.getDataStartSector();
        return data_sectors / self.SectorsPerCluster;
    }

    pub fn clusterToSector(self: *const BootSector, cluster: u32) u32 {
        return self.getDataStartSector() + ((cluster - constants.clusters.CLUSTER_DATA_START) * self.SectorsPerCluster);
    }

    pub fn getBytesPerCluster(self: *const BootSector) u32 {
        return @as(u32, self.BytesPerSector) * self.SectorsPerCluster;
    }
};

pub const FsInfo = extern struct {
    Signature1: u32 align(1),
    Reserved1: [480]u8,
    Signature2: u32 align(1),
    FreeClusterCount: u32 align(1),
    NextFreeCluster: u32 align(1),
    Reserved2: [12]u8,
    Signature3: u32 align(1),

    pub fn isValid(self: *const FsInfo) bool {
        return self.Signature1 == constants.magic.FSINFO_SIGNATURE_1 and
            self.Signature2 == constants.magic.FSINFO_SIGNATURE_2 and
            self.Signature3 == constants.magic.FSINFO_SIGNATURE_3;
    }
};
