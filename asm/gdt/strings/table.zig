//! GDT Table Instructions

pub const LOAD_GLOBAL_DESCRIPTOR_TABLE = "lgdt (%[descriptor])";
pub const STORE_GLOBAL_DESCRIPTOR_TABLE = "sgdt (%[descriptor])";
