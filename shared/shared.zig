//! Shared Libraries

pub const fs = @import("fs/fs.zig");

// Convenience re-exports
pub const afs = fs.afs;
pub const fat32 = fs.fat32;
