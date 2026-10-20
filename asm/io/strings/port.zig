//! Port I/O Instructions

pub const READ_BYTE = "inb %[port], %[result]";
pub const WRITE_BYTE = "outb %[value], %[port]";
pub const READ_WORD = "inw %[port], %[result]";
pub const WRITE_WORD = "outw %[value], %[port]";
pub const READ_LONG = "inl %[port], %[result]";
pub const WRITE_LONG = "outl %[value], %[port]";
