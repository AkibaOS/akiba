//! OS types

pub const MemInfo = struct {
    total: u64,
    used: u64,
    free: u64,
};

pub const DiskInfo = struct {
    total: u64,
    used: u64,
};
