//! FAT32 Identity Strings

pub const DEFAULT_OEM_NAME: [8]u8 = .{ 'M', 'S', 'W', 'I', 'N', '4', '.', '1' };
pub const DEFAULT_VOLUME_LABEL: [11]u8 = .{ 'F', 'A', 'T', '3', '2', ' ', 'D', 'I', 'S', 'K', ' ' };
pub const FS_TYPE_FAT32: [8]u8 = .{ 'F', 'A', 'T', '3', '2', ' ', ' ', ' ' };
pub const EMPTY = "";
pub const DOT = ".";
pub const PARENT = "..";
