//! Independent Native Scanout Pattern At The Right Edge

pub const TOP: u32 = 9;
pub const WIDTH: u32 = 5;
pub const HEIGHT: u32 = 5;
pub const INNER: u32 = 3;
pub const RGB_BYTES: usize = 3;
pub const BACKGROUND = [RGB_BYTES]u8{ 0x11, 0x22, 0x44 };
pub const INVALID = [RGB_BYTES]u8{ 0xff, 0xff, 0xff };
pub const PATTERN = [HEIGHT][WIDTH][RGB_BYTES]u8{
    .{ BACKGROUND, BACKGROUND, BACKGROUND, BACKGROUND, BACKGROUND },
    .{ BACKGROUND, .{ 0x81, 0x0d, 0x27 }, .{ 0x34, 0xb2, 0x4c }, .{ 0x16, 0x21, 0xe5 }, BACKGROUND },
    .{ BACKGROUND, .{ 0xd5, 0x70, 0x19 }, .{ 0x38, 0x09, 0x58 }, .{ 0xa4, 0x6b, 0xc3 }, BACKGROUND },
    .{ BACKGROUND, .{ 0x12, 0xf1, 0x6e }, .{ 0xc1, 0xa0, 0x32 }, .{ 0x49, 0x6a, 0x8b }, BACKGROUND },
    .{ BACKGROUND, BACKGROUND, BACKGROUND, BACKGROUND, BACKGROUND },
};
