//! Independently Encoded Firmware Device Path Samples

pub const PCI = [_]u8{ 1, 1, 6, 0, 0, 6 };
pub const SATA = [_]u8{ 3, 18, 10, 0, 0, 0, 0xff, 0xff, 0, 0 };
pub const VENDOR = [_]u8{ 3, 10, 20, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
pub const END = [_]u8{ 0x7f, 0xff, 4, 0 };
pub const INSTANCE = [_]u8{ 0x7f, 1, 4, 0 };
pub const INVALID_LENGTH = [_]u8{ 1, 1, 0, 0 };
pub const SHORT_SATA = [_]u8{ 3, 18, 8, 0, 0, 0, 0, 0 };
pub const REMAINDER = [_]u8{0xcc};
pub const SATA_TAG = [_]u8{ 1, 0, 0, 0 };
