//! Kernel Device Instance And Assignment Records

pub const Kind = enum(u64) { Keyboard, Framebuffer };

pub const Instance = struct {
    ID: u64,
    Kind: Kind,
    Location: u64,
};

pub const Assignment = struct {
    Owner: u64,
    Handle: u64,
    Committed: bool = false,
};

pub const Record = struct {
    Device: Instance,
    Assignment: ?Assignment = null,
};
