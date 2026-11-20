//! Pending Owned Kernel Root Types

const layout = @import("common").constants.memory.layout;
const kagami = @import("mirai").kagami.types.kagami;
const policy = @import("mirai").kagami.types.policy.cache;

pub const Phase = enum {
    Empty,
    Preparing,
    Prepared,
    Active,
};

pub const PreparedRoot = struct {
    Phase: Phase = .Empty,
    Kagami: kagami.Kagami = .{},
    Policy: policy.Policy = .{},
    StackFrames: [layout.KERNEL_STACK_PAGES]u64 = @splat(0),
    TableCount: usize = 0,
    StackCount: usize = 0,
    PreviousCR3: u64 = 0,
    PreviousSearchStart: u64 = 0,
    GigabytePages: bool = false,
};
