//! Overflow Handler (Arithmetic Exceptions)

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const Exception = types.Exception;
const Action = constants.Action;

pub fn handle(exception: *Exception) Action {
    if (exception.context.is_kernel_mode()) {
        serial.printf("Kernel arithmetic exception at %x\n", .{exception.context.rip});
        return .collapse;
    }
    return .terminate;
}
