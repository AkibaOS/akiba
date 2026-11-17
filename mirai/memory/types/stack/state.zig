//! Kernel Stack Allocator State Type

const record = @import("mirai").memory.types.stack.record;

pub const State = struct {
    FreeList: ?*record.Record = null,
    FreeCount: u64 = 0,
    TotalCount: u64 = 0,
    HighWatermark: u64 = 0,
    BootStackBase: u64 = 0,
    BootStackTop: u64 = 0,
};
