//! Single CPU Scheduler State

const policy = @import("mirai").sensei.constants.policy;
const Queue = @import("mirai").sensei.types.queue.Queue;
const Record = @import("mirai").sensei.types.record.Record;

pub const State = struct {
    Records: [policy.MAX_RECORDS]Record = [_]Record{.{}} ** policy.MAX_RECORDS,
    Ready: Queue = .{},
    Idle: ?*Record = null,
    RegisteredCount: u16 = 0,
    IRQDepth: u32 = 0,
    PreemptionDepth: u32 = 0,
    RemainingTicks: u32 = policy.QUANTUM_TICKS,
    Ticks: u64 = 0,
    Switches: u64 = 0,
    Requests: u64 = 0,
    Deferred: u64 = 0,
    Pending: bool = false,
    Initialized: bool = false,
};
