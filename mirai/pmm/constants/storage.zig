//! Sparse Physical Range Packing Geometry

const types = @import("mirai").pmm.types.storage;

pub const ROLE_BITS = @bitSizeOf(types.Role);
pub const PAGES_PER_BYTE = @bitSizeOf(u8) / ROLE_BITS;
pub const ROLE_MASK: u8 = (1 << ROLE_BITS) - 1;
pub const LOW_ROLE_BITS: u8 = 0x55;
pub const RECORD_ALIGNMENT: usize = @alignOf(types.Record);
pub const RECORD_HEADER_BYTES = @sizeOf(types.Record);
pub const MIN_RECORD_BYTES = RECORD_HEADER_BYTES + RECORD_ALIGNMENT;
pub const FRAME_HEADER_BYTES = @sizeOf(types.Header);
pub const FRAME_DATA_BYTES = @sizeOf(types.Frame) - FRAME_HEADER_BYTES;
