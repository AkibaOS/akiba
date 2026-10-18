//! Pending Owned Kernel Root Types

const constants = @import("mirai").kagami.constants.bootstrap;
const kagami = @import("mirai").kagami.types.kagami;
const policy = @import("mirai").kagami.types.policy;

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
    TableFrames: [constants.MAX_TABLE_FRAMES]u64 = [_]u64{0} ** constants.MAX_TABLE_FRAMES,
    StackFrames: [constants.MAX_STACK_FRAMES]u64 = [_]u64{0} ** constants.MAX_STACK_FRAMES,
    TableCount: usize = 0,
    StackCount: usize = 0,
    PreviousCR3: u64 = 0,
    PreviousSearchStart: u64 = 0,
    GigabytePages: bool = false,
};
