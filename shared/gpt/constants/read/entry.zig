//! GPT Partition Entry Fields And AFS Type

pub const MINIMUM_BYTES: u32 = 128;
pub const STRIDE_ALIGNMENT: u32 = 8;
pub const TYPE_OFFSET = 0;
pub const IDENTITY_OFFSET = 16;
pub const FIRST_OFFSET = 32;
pub const LAST_OFFSET = 40;
pub const PREFIX_BYTES = LAST_OFFSET + @sizeOf(u64);
pub const AFS_TYPE_GUID = [16]u8{ 0x42, 0x49, 0x4b, 0x41, 0x46, 0x41, 0, 0x53, 0, 0, 0, 0, 0, 0, 0, 1 };
