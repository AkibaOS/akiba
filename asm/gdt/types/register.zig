//! GDT Register Descriptor

pub const GDTR = packed struct {
    Limit: u16,
    Base: u64,
};
