//! Segment Zero PCI Address And Read Only Configuration Cursor

pub const Address = packed struct(u16) {
    Function: u3,
    Device: u5,
    Bus: u8,
};

pub const Cursor = struct {
    Next: u32 = 0,
};

pub const Source = struct {
    Context: ?*anyopaque = null,
    Read: *const fn (?*anyopaque, Address, u8) u32,
};
