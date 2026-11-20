//! Packed Physical Range Storage

const common = @import("common");

const sizes = common.constants.memory.sizes;

pub const Role = enum {
    Free,
    Allocated,
    Reserved,
    Retiring,
    Hole,
};

pub const Range = struct {
    Start: u64,
    End: u64,
};

pub const Record = extern struct {
    StartPage: u64,
    PageCount: u64,
};

pub const Header = extern struct {
    Next: ?*Frame,
    Lower: ?*Frame,
    Higher: ?*Frame,
    FirstPage: u64,
    EndPage: u64,
    UsedBytes: usize,
};

pub const Frame = extern struct {
    Header: Header,
    Data: [sizes.PAGE_SIZE - @sizeOf(Header)]u8,
};

pub const Index = struct {
    Root: ?*Frame = null,
    PhysicalPages: u64 = 0,
};

pub const View = struct {
    Range: Range,
    Map: []u8,
};

pub const Walker = struct {
    Frame: ?*Frame,
    Offset: usize = 0,
};
