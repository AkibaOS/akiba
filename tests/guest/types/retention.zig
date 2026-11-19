//! Kata Retention Regression Fixtures

const inputs = @import("tests").guest.constants.retention;
const kata = @import("mirai").kata;
const sensei = @import("mirai").sensei;

const Outcome = kata.types.outcome.Outcome;
const Queue = sensei.types.queue.Queue;

pub const WaitResult = struct {
    Invalid: bool = false,
    Born: bool = false,
    Self: bool = false,
    Reclaimed: ?Outcome = null,
    Final: ?Outcome = null,
};

pub const WaitFixture = struct {
    BornID: u64,
    ReclaimedID: u64,
    TargetID: u64,
    Parked: Queue = .{},
    Results: [inputs.OBSERVER_COUNT]WaitResult = [_]WaitResult{.{}} ** inputs.OBSERVER_COUNT,
};

pub const WaitArgument = struct {
    Fixture: *WaitFixture,
    Index: usize,
};
