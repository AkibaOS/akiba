//! Stable Kernel Heap Payload Frame Ownership

const allocation = @import("mirai").memory.types.heap.allocation;
const tree = @import("common").datatypes.tree;

pub const Frame = struct {
    Owner: *allocation.Allocation,
    VA: u64,
    PA: u64 = 0,
    Mapped: bool = false,
    PhysicalIndex: tree.types.node.Node = .{},
    Next: ?*Frame = null,
};
