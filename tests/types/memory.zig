//! Memory Regression Fixtures

pub const AllocationCase = struct {
    Request: usize,
    Capacity: usize,
};

pub const MappingRejection = struct {
    Address: u64,
    PhysicalOffset: u64 = 0,
    Protection: u8,
    Failure: anyerror,
};

pub const SparseBacking = struct {
    Pages: [3]u64,
    Mapped: usize = 0,
};
