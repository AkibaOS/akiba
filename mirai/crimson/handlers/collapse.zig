//! Collapse Handler (Double Fault, Machine Check)

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const messages = @import("../strings/strings.zig").messages;
const Exception = types.Exception;
const Action = constants.Action;

pub fn handle(exception: *Exception) Action {
    serial.printf(messages.fatal_unrecoverable, .{ exception.vector, exception.context.rip });
    return .collapse;
}
