//! IDT type definitions

pub const Entry = packed struct {
    offset_low: u16,
    selector: u16,
    ist: u8,
    type_attr: u8,
    offset_mid: u16,
    offset_high: u32,
    reserved: u32,
};

pub const Pointer = packed struct {
    limit: u16,
    base: u64,
};
