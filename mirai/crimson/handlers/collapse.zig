//! Collapse Handler (Double Fault, Machine Check)

const serial = @import("../../drivers/serial/serial.zig");
const strings = @import("../strings/strings.zig");
const types = @import("../types/types.zig");

const messages = strings.messages;

const Action = types.behavior.Action;
const Exception = types.exception.Exception;

pub fn handle(exception: *Exception) Action {
    serial.write.printf(messages.FATAL_UNRECOVERABLE, .{ exception.Vector, exception.Context.RIP });
    return .Collapse;
}
