//! Kernel Stack Allocator State Type

const node = @import("mirai").memory.types.stack.node;

pub const State = struct {
    NextSlot: u64 = 0,
    FreeList: ?*node.FreeNode = null,
    FreeCount: u64 = 0,
    TotalCount: u64 = 0,
    HighWatermark: u64 = 0,
    BootStackBase: u64 = 0,
    BootStackTop: u64 = 0,
};
