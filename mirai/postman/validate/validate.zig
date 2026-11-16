//! Postman Execution Validation

const kata = @import("mirai").kata;
const limits = @import("mirai").postman.constants.limits;
const sensei = @import("mirai").sensei;
const state = @import("mirai").postman.state;
const thread = @import("mirai").thread;

const PostError = @import("mirai").postman.errors.transport.PostError;
const Thread = thread.types.thread.Thread;

pub fn initialized() PostError!void {
    if (!state.getState().Initialized or !sensei.state.getState().Initialized) return PostError.NotInitialized;
}

pub fn live(target: *const Thread) bool {
    if (!thread.state.owns(target)) return false;
    if (!target.Managed or target.Permanent or target.Mode != .Persona or target.Status == .Stopped) return false;
    return kata.state.owns(target.Owner) and !target.Owner.Permanent and
        target.Owner.State != .Born and target.Owner.State != .Dead;
}

pub fn current(target: *Thread) PostError!void {
    try initialized();
    if (!live(target) or target != thread.state.getCurrent() or target.Status != .Running) {
        return PostError.InvalidThread;
    }
}

pub fn payload(bytes: []const u8) PostError!void {
    if (bytes.len > limits.MAX_PAYLOAD_BYTES) return PostError.TooLarge;
}
