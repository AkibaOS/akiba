//! Postman Storage Ownership

const State = @import("mirai").postman.types.state.State;

var transport: State = .{};

pub fn getState() *State {
    return &transport;
}
