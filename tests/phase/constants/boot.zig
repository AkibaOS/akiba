//! Diagnostic EFI Boot Selection Frames

pub const READY = [_]u8{ 0xa7, 0xb1, 'A', 'K', 'B', 'R' };
pub const OFFER = [_]u8{ 'A', 'K', 'B', 'O' };
pub const ACKNOWLEDGEMENT = [_]u8{ 'A', 'K', 'B', 'A' };
pub const ROLE_OFFSET = OFFER.len + @sizeOf(u64);
pub const FRAME_BYTES = ROLE_OFFSET + @sizeOf(u8);
