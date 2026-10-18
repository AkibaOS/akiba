//! Kernel Stack Allocator State Type

const limits = @import("mirai").memory.constants.stack.limits;
const node = @import("mirai").memory.types.stack.node;

pub const State = struct {
    AllocatedSlots: [limits.SLOT_BITMAP_BYTES]u8 = [_]u8{0} ** limits.SLOT_BITMAP_BYTES,
    RetainedSlots: [limits.SLOT_BITMAP_BYTES]u8 = [_]u8{0} ** limits.SLOT_BITMAP_BYTES,
    NextSlot: u64 = 0,
    FreeList: ?*node.FreeNode = null,
    FreeCount: u64 = 0,
    TotalCount: u64 = 0,
    HighWatermark: u64 = 0,
    BootStackBase: u64 = 0,
    BootStackTop: u64 = 0,
};
