//! Active Completion Wait Registration

const Thread = @import("mirai").thread.types.thread.Thread;

pub const Observer = struct {
    Thread: ?*Thread = null,
    OwnerID: u64 = 0,
    TargetID: u64 = 0,
};
