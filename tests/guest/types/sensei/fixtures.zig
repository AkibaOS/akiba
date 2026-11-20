//! Scheduler Regression Fixtures

const inputs = @import("tests").guest.constants.sensei.queues;
const sensei = @import("mirai").sensei;

const Queue = sensei.types.queue.links.Queue;

pub const WaitState = struct {
    Waiters: Queue = .{},
    Immediate: Queue = .{},
    Open: bool = false,
    ImmediateReturned: [inputs.WAITER_COUNT]bool = [_]bool{false} ** inputs.WAITER_COUNT,
    Finished: [inputs.WAITER_COUNT]bool = [_]bool{false} ** inputs.WAITER_COUNT,
    YieldReturned: [inputs.WAITER_COUNT]bool = [_]bool{false} ** inputs.WAITER_COUNT,
    YieldHadPeer: [inputs.WAITER_COUNT]bool = [_]bool{false} ** inputs.WAITER_COUNT,
    Checks: [inputs.WAITER_COUNT]usize = [_]usize{0} ** inputs.WAITER_COUNT,
    ImmediateChecks: [inputs.WAITER_COUNT]usize = [_]usize{0} ** inputs.WAITER_COUNT,
};

pub const PopulationState = struct {
    TargetID: u64 = 0,
    TargetWaiters: Queue = .{},
    Open: bool = false,
    TargetParked: bool = false,
    Entered: usize = 0,
    Finished: usize = 0,
    Received: bool = true,
};

pub const WaitArgument = struct {
    State: *WaitState,
    Index: usize,
};
