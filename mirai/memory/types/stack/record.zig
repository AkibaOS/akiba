//! Stable Kernel Stack Ownership Record

const limits = @import("mirai").memory.constants.stack.limits;
const range = @import("mirai").memory.types.range;
const stack = @import("mirai").memory.types.stack;
const tree = @import("common").datatypes.tree;

pub const Record = struct {
    Extent: *range.extent.Extent,
    Stack: stack.kernel.KernelStack,
    Pages: [limits.STACK_PAGES]u64 = [_]u64{0} ** limits.STACK_PAGES,
    PageCount: usize = 0,
    Index: tree.types.node.Node = .{},
    Next: ?*Record = null,
    Pinned: bool = false,
    Phase: stack.phase.Phase = .Reserved,
};
