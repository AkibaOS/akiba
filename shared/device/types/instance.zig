//! Address Free Device Inventory Data

pub const Kind = enum(u64) { Keyboard, Framebuffer };

pub const Instance = extern struct {
    ID: u64,
    Kind: Kind,
    Location: u64,
};

pub const Key = struct {
    Kind: Kind,
    Location: u64,
};
