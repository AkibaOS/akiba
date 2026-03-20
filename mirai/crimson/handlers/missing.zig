//! Missing Handler (Device Not Available)

const asm_cpu = @import("../../asm/cpu/cpu.zig");
const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const Exception = types.Exception;
const Action = constants.Action;

pub fn handle(exception: *Exception) Action {
    _ = exception;
    asm_cpu.clear_task_switched();
    return .@"resume";
}
