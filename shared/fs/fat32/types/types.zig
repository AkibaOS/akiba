//! FAT32 Types

pub const boot = @import("boot.zig");
pub const entry = @import("entry.zig");

// Boot sector types
pub const BootSector = boot.BootSector;
pub const FsInfo = boot.FsInfo;

// Entry types (Akiba terminology)
pub const StackEntry = entry.StackEntry;
pub const LongIdentityEntry = entry.LongIdentityEntry;
pub const TimeFormat = entry.TimeFormat;
pub const DateFormat = entry.DateFormat;

// FAT32 spec aliases
pub const DirEntry = entry.DirEntry;
pub const LongNameEntry = entry.LongNameEntry;
