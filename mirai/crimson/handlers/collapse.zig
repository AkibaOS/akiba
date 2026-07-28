//! Collapse Handler (Double Fault, Machine Check)

const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;
const types = @import("mirai").crimson.types;

const messages = strings.messages;

const Action = types.behavior.Action;
const Exception = types.exception.Exception;

pub fn handle(exception: *Exception) Action {
    serial.write.printf(messages.FATAL_UNRECOVERABLE, .{ exception.Vector, exception.Context.RIP });
    return .Collapse;
}
