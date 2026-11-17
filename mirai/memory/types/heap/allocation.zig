//! Kernel Heap Allocation Ownership

const frame = @import("mirai").memory.types.heap.frame;
const range = @import("mirai").memory.types.range;
const tree = @import("common").datatypes.tree;

pub const Allocation = struct {
    Extent: *range.extent.Extent,
    RequestedSize: usize,
    Alignment: usize,
    Frames: ?*frame.Frame = null,
    FrameCount: usize = 0,
    Index: tree.types.node.Node = .{},
};
