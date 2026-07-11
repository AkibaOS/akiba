//! Hikari FAT32 Adapter

const efi = @import("../../efi/efi.zig");
const shared_fat32 = @import("shared").fat32;

// Re-export shared types
pub const constants = shared_fat32.constants;
pub const types = shared_fat32.types;

pub const BootSector = shared_fat32.BootSector;
pub const FsInfo = shared_fat32.FsInfo;
pub const StackEntry = shared_fat32.StackEntry;
pub const LongIdentityEntry = shared_fat32.LongIdentityEntry;
pub const TimeFormat = shared_fat32.TimeFormat;
pub const DateFormat = shared_fat32.DateFormat;

// Reader adapter
pub const reader = @import("reader_adapter.zig");
pub const Reader = reader.Reader;
pub const ReadError = reader.ReadError;
