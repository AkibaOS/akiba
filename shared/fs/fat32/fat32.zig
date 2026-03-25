//! FAT32 Filesystem

pub const constants = @import("constants/constants.zig");
pub const types = @import("types/types.zig");
pub const read = @import("read/read.zig");
pub const write = @import("write/write.zig");

// Re-export commonly used types (Akiba terminology)
pub const BootSector = types.BootSector;
pub const FsInfo = types.FsInfo;
pub const StackEntry = types.StackEntry;
pub const LongIdentityEntry = types.LongIdentityEntry;
pub const TimeFormat = types.TimeFormat;
pub const DateFormat = types.DateFormat;

// FAT32 spec aliases (for compatibility)
pub const DirEntry = types.DirEntry;
pub const LongNameEntry = types.LongNameEntry;

// Re-export errors
pub const ClusterError = read.ClusterError;
pub const LocationError = read.LocationError;
