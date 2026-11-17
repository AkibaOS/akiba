//! Address Pinned Virtual Extent Region

const extent = @import("mirai").memory.types.range.extent;
const pool = @import("mirai").memory.types.pool.store;
const tree = @import("common").datatypes.tree;

const Records = pool.create(extent.Extent);
const Tree = tree.types.index.Tree;

pub const Region = struct {
    Base: u64 = 0,
    End: u64 = 0,
    ReservedBytes: u64 = 0,
    AllocatedCount: usize = 0,
    Head: ?*extent.Extent = null,
    AddressIndex: Tree = .{},
    FreeSizes: Tree = .{},
    Records: Records = .{},
    Location: usize = 0,
    Initialized: bool = false,
};
