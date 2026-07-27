//! Missing Handler (Device Not Available)

const cpu = @import("asm").cpu;

const types = @import("../types/types.zig");

const Action = types.behavior.Action;
const Exception = types.exception.Exception;

pub fn handle(exception: *Exception) Action {
    _ = exception;
    cpu.state.clearTaskSwitched();
    return .Resume;
}
