//! Session Action Frame Layout

pub const HEADER = [_]u8{ 'A', 'K', 'M', 'A' };
pub const EPOCH_OFFSET = HEADER.len;
pub const ACTION_OFFSET = EPOCH_OFFSET + @sizeOf(u64);
pub const FRAME_BYTES = ACTION_OFFSET + @sizeOf(u8);
