//! Hikari EFI Unit Types

const base = @import("hikari").efi.types.base;
const time = @import("hikari").efi.types.time;

pub const UnitInfo = extern struct {
    Size: u64,
    UnitSize: u64,
    PhysicalSize: u64,
    CreateTime: time.Time,
    LastAccessTime: time.Time,
    ModificationTime: time.Time,
    Attribute: u64,
    UnitName: [256]base.Char16,
};

pub const UnitSystemInfo = extern struct {
    Size: u64,
    ReadOnly: bool,
    VolumeSize: u64,
    FreeSpace: u64,
    BlockSize: u32,
    VolumeLabel: [256]base.Char16,
};
