//! Scheduler State Storage

const types = @import("mirai").sensei.types;

var scheduler: types.state.scheduler.State = .{};

pub fn getState() *types.state.scheduler.State {
    return &scheduler;
}

pub fn isInitialized() bool {
    return scheduler.Initialized;
}
