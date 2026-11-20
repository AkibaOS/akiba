//! IDT Instructions

pub const LOAD_INTERRUPT_DESCRIPTOR_TABLE = "lidt (%[descriptor])";
pub const STORE_INTERRUPT_DESCRIPTOR_TABLE = "sidt (%[descriptor])";
