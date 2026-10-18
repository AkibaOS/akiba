//! Scheduler State Storage

const types = @import("mirai").sensei.types;

var scheduler: types.state.State = .{};

pub fn getState() *types.state.State {
    return &scheduler;
}

pub fn isInitialized() bool {
    return scheduler.Initialized;
}
