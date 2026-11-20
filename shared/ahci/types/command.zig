//! Supported Read Only ATA Commands

pub const Operation = union(enum) {
    Identify,
    Read: u64,
};
