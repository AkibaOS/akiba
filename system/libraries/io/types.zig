//! I/O types and constants

pub const Error = error{
    NotFound,
    PermissionDenied,
    InvalidDescriptor,
    ReadFailed,
    WriteFailed,
    InvalidLocation,
    SendFailed,
    GetLocationFailed,
};

pub const Descriptor = u32;

pub const source: Descriptor = 0;
pub const stream: Descriptor = 1;
pub const trace: Descriptor = 2;

pub const VIEW_ONLY: u32 = 0x01;
pub const MARK_ONLY: u32 = 0x02;
pub const BOTH: u32 = 0x03;
pub const CREATE: u32 = 0x0100;

pub const StackEntry = extern struct {
    identity: [64]u8,
    identity_len: u8,
    is_stack: bool,
    owner_name_len: u8,
    permission_type: u8,
    size: u32,
    modified_time: u64,
    owner_name: [64]u8,
};

pub const Letter = struct {
    pub const NONE: u8 = 0;
    pub const NAVIGATE: u8 = 1;
};
