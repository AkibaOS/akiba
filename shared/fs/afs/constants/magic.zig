//! AFS Magic Numbers and Signatures

/// "AKIBAFS!" signature
pub const signature: u64 = 0x2153464142494B41;

/// AFS version
pub const version: u16 = 0x0001;

/// "JNRL" journal signature
pub const journal_signature: u32 = 0x4A4E524C;

/// AFS partition type GUID: 414B4942-4146-5300-0000-000000000001
pub const partition_type_guid = [16]u8{
    0x42, 0x49, 0x4B, 0x41,
    0x46, 0x41,
    0x00, 0x53,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
};
