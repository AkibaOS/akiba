//! Overflow Handler (Arithmetic Exceptions)

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const messages = @import("../strings/strings.zig").messages;
const Exception = types.Exception;
const Action = constants.Action;

pub fn handle(exception: *Exception) Action {
    if (exception.context.is_kernel_mode()) {
        serial.printf(messages.KERNEL_ARITHMETIC, .{exception.context.rip});
        return .collapse;
    }
    return .terminate;
}
