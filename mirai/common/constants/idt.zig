//! IDT constants

pub const NUM_ENTRIES: usize = 256;
pub const NUM_EXCEPTIONS: u8 = 32;

pub const GATE_INTERRUPT: u8 = 0x8E;
pub const GATE_TRAP: u8 = 0x8F;

pub const VECTOR_TIMER: u8 = 32;
pub const VECTOR_KEYBOARD: u8 = 33;
