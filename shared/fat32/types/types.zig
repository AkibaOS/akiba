//! FAT32 Types

pub const boot = @import("boot.zig");
pub const entry = @import("entry.zig");

pub const BootSector = boot.BootSector;
pub const FsInfo = boot.FsInfo;

pub const StackEntry = entry.StackEntry;
pub const LongIdentityEntry = entry.LongIdentityEntry;
pub const TimeFormat = entry.TimeFormat;
pub const DateFormat = entry.DateFormat;

pub const DirEntry = entry.DirEntry;
pub const LongNameEntry = entry.LongNameEntry;
