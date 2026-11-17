//! Stable Virtual Extent Partition Record

const region = @import("mirai").memory.types.range.region;
const tree = @import("common").datatypes.tree;

pub const Extent = struct {
    Owner: *region.Region,
    Base: u64,
    Size: u64,
    Free: bool,
    AddressIndex: tree.types.node.Node = .{},
    SizeIndex: tree.types.node.Node = .{},
    Before: ?*Extent = null,
    After: ?*Extent = null,
};
