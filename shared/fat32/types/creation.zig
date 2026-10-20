//! FAT32 Creation Parameters

const constants = @import("shared").fat32.constants;
const strings = @import("shared").fat32.strings.identity;

pub const CreateParams = struct {
    TotalSectors: u32,
    HiddenSectors: u32 = 0,
    BytesPerSector: u16 = constants.sizes.SECTOR_SIZE_MIN,
    SectorsPerCluster: u8 = constants.defaults.DEFAULT_SECTORS_PER_CLUSTER,
    ReservedSectors: u16 = constants.defaults.DEFAULT_RESERVED_SECTORS,
    FatCount: u8 = constants.defaults.DEFAULT_FAT_COUNT,
    VolumeId: u32 = constants.defaults.DEFAULT_VOLUME_ID,
    VolumeLabel: [11]u8 = strings.DEFAULT_VOLUME_LABEL,
};
